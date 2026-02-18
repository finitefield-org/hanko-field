use std::{
    collections::{BTreeMap, HashMap},
    env,
    sync::Arc,
    time::Duration,
};

use anyhow::{Context, Result, anyhow, bail};
use askama::Template;
use axum::{
    Router,
    extract::{Form, Multipart, Path, Query, State, rejection::FormRejection},
    http::{HeaderValue, StatusCode, header},
    response::{IntoResponse, Redirect, Response},
    routing::{get, patch},
};
use chrono::{DateTime, Local, SecondsFormat, Utc};
use firebase_sdk_rust::firebase_firestore::{
    CreateDocumentOptions, DeleteDocumentOptions, Document, FirebaseFirestoreClient,
    PatchDocumentOptions, RunQueryRequest,
};
use gcp_auth::{CustomServiceAccount, TokenProvider, provider};
use serde::Deserialize;
use serde_json::{Value as JsonValue, json};
use tokio::{net::TcpListener, sync::RwLock};
use tower_http::services::ServeDir;
use uuid::Uuid;

const DATASTORE_SCOPE: &str = "https://www.googleapis.com/auth/datastore";
const STORAGE_SCOPE: &str = "https://www.googleapis.com/auth/devstorage.read_write";
const MAX_PHOTO_UPLOAD_BYTES: usize = 10 * 1024 * 1024;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum RunMode {
    Mock,
    Dev,
    Prod,
}

impl RunMode {
    fn as_str(self) -> &'static str {
        match self {
            Self::Mock => "mock",
            Self::Dev => "dev",
            Self::Prod => "prod",
        }
    }
}

#[derive(Debug, Clone)]
struct AppConfig {
    http_addr: String,
    mode: RunMode,
    locale: String,
    default_locale: String,
    firestore_project_id: Option<String>,
    storage_assets_bucket: Option<String>,
    credentials_file: Option<String>,
}

#[derive(Debug, Clone)]
struct Order {
    id: String,
    order_no: String,
    channel: String,
    locale: String,
    status: String,
    status_updated_at: DateTime<Utc>,
    payment_status: String,
    fulfillment_status: String,
    tracking_no: String,
    carrier: String,
    country_code: String,
    contact_email: String,
    seal_line1: String,
    seal_line2: String,
    material_label_ja: String,
    total_jpy: i64,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    events: Vec<OrderEvent>,
}

#[derive(Debug, Clone)]
struct OrderEvent {
    kind: String,
    actor_type: String,
    actor_id: String,
    before_status: String,
    after_status: String,
    note: String,
    created_at: DateTime<Utc>,
}

#[derive(Debug, Clone)]
struct MaterialPhoto {
    asset_id: String,
    storage_path: String,
    alt_i18n: HashMap<String, String>,
    sort_order: i64,
    is_primary: bool,
    width: i64,
    height: i64,
}

#[derive(Debug, Clone)]
struct Material {
    key: String,
    label_i18n: HashMap<String, String>,
    description_i18n: HashMap<String, String>,
    photos: Vec<MaterialPhoto>,
    price_jpy: i64,
    is_active: bool,
    sort_order: i64,
    version: i64,
    updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone)]
struct AdminSnapshot {
    orders: HashMap<String, Order>,
    order_ids: Vec<String>,
    materials: HashMap<String, Material>,
    material_ids: Vec<String>,
    countries: HashMap<String, String>,
}

impl AdminSnapshot {
    fn refresh_order_ids(&mut self) {
        let mut ids = self.orders.keys().cloned().collect::<Vec<_>>();
        ids.sort_by(|left, right| {
            let left_created = self
                .orders
                .get(left)
                .map(|order| order.created_at)
                .unwrap_or(DateTime::<Utc>::UNIX_EPOCH);
            let right_created = self
                .orders
                .get(right)
                .map(|order| order.created_at)
                .unwrap_or(DateTime::<Utc>::UNIX_EPOCH);
            right_created.cmp(&left_created)
        });
        self.order_ids = ids;
    }

    fn refresh_material_ids(&mut self) {
        let mut keys = self.materials.keys().cloned().collect::<Vec<_>>();
        keys.sort_by(|left, right| {
            let left_material = self.materials.get(left);
            let right_material = self.materials.get(right);
            match (left_material, right_material) {
                (Some(left_material), Some(right_material)) => left_material
                    .sort_order
                    .cmp(&right_material.sort_order)
                    .then_with(|| left_material.key.cmp(&right_material.key)),
                _ => left.cmp(right),
            }
        });
        self.material_ids = keys;
    }
}

#[derive(Clone)]
enum DataSource {
    Mock,
    Firestore(FirestoreAdminSource),
}

impl DataSource {
    fn is_mock(&self) -> bool {
        matches!(self, Self::Mock)
    }

    fn label(&self) -> &str {
        match self {
            Self::Mock => "Mock",
            Self::Firestore(source) => &source.label,
        }
    }

    async fn load_snapshot(&self) -> Result<AdminSnapshot> {
        match self {
            Self::Mock => Ok(new_mock_snapshot()),
            Self::Firestore(source) => source.load_snapshot().await,
        }
    }

    async fn persist_order_mutation(&self, order: &Order, events: &[OrderEvent]) -> Result<()> {
        match self {
            Self::Mock => Ok(()),
            Self::Firestore(source) => source.persist_order_mutation(order, events).await,
        }
    }

    async fn persist_material_mutation(&self, material: &Material) -> Result<()> {
        match self {
            Self::Mock => Ok(()),
            Self::Firestore(source) => source.persist_material_mutation(material).await,
        }
    }

    async fn persist_material_deletion(&self, material_key: &str) -> Result<()> {
        match self {
            Self::Mock => Ok(()),
            Self::Firestore(source) => source.persist_material_deletion(material_key).await,
        }
    }

    async fn upload_material_photo(
        &self,
        material_key: &str,
        file_name: &str,
        content_type: Option<&str>,
        bytes: &[u8],
    ) -> Result<String> {
        match self {
            Self::Mock => Ok(build_storage_path_for_uploaded_photo(
                material_key,
                file_name,
                content_type,
            )),
            Self::Firestore(source) => {
                source
                    .upload_material_photo(material_key, file_name, content_type, bytes)
                    .await
            }
        }
    }
}

#[derive(Clone)]
struct FirestoreAdminSource {
    locale: String,
    default_locale: String,
    label: String,
    parent: String,
    storage_assets_bucket: String,
    token_provider: Arc<dyn TokenProvider>,
}

#[derive(Clone)]
struct AppState {
    server: Arc<ServerState>,
}

struct ServerState {
    source_label: String,
    source: DataSource,
    data: RwLock<AdminSnapshot>,
}

#[derive(Debug, Clone)]
struct OrderFilter {
    status: String,
    country: String,
    email: String,
}

#[derive(Debug, Default, Deserialize)]
struct OrdersPageQuery {
    status: Option<String>,
    country: Option<String>,
    email: Option<String>,
    order_id: Option<String>,
}

#[derive(Debug, Clone)]
struct StatusOptionView {
    value: String,
    label: String,
}

#[derive(Debug, Clone)]
struct CountryOptionView {
    code: String,
    label: String,
}

#[derive(Debug, Clone)]
struct OrderListItemView {
    id: String,
    order_no: String,
    created_at: String,
    status_label: String,
    payment_status_label: String,
    fulfillment_status_label: String,
    country_label: String,
    total_jpy: String,
}

#[derive(Debug, Clone)]
struct OrderEventView {
    kind: String,
    actor_type: String,
    actor_id: String,
    has_actor_id: bool,
    before_status_label: String,
    after_status_label: String,
    has_before_status: bool,
    note: String,
    has_note: bool,
    created_at: String,
}

#[derive(Debug, Clone)]
struct OrderDetailView {
    id: String,
    order_no: String,
    created_at: String,
    updated_at: String,
    status_label: String,
    payment_status_label: String,
    fulfillment_status_label: String,
    tracking_no: String,
    has_tracking_no: bool,
    carrier: String,
    country_code: String,
    country_label: String,
    contact_email: String,
    channel: String,
    locale: String,
    seal_line1: String,
    seal_line2: String,
    has_seal_line2: bool,
    material_label_ja: String,
    total_jpy: String,
    next_statuses: Vec<StatusOptionView>,
    has_next_statuses: bool,
    shipping_transitions: Vec<StatusOptionView>,
    events: Vec<OrderEventView>,
    message: String,
    has_message: bool,
    error: String,
    has_error: bool,
}

#[derive(Debug, Clone)]
struct MaterialListItemView {
    key: String,
    label_ja: String,
    primary_photo_path: String,
    has_photo: bool,
    price_jpy: String,
    is_active: bool,
    version: i64,
    updated_at: String,
}

#[derive(Debug, Clone)]
struct MaterialDetailView {
    key: String,
    label_ja: String,
    label_en: String,
    description_ja: String,
    description_en: String,
    price_jpy: i64,
    is_active: bool,
    sort_order: i64,
    photo_storage_path: String,
    photo_alt_ja: String,
    photo_alt_en: String,
    version: i64,
    updated_at: String,
    message: String,
    has_message: bool,
    error: String,
    has_error: bool,
}

#[derive(Debug, Clone)]
struct MaterialCreateView {
    key: String,
    label_ja: String,
    label_en: String,
    description_ja: String,
    description_en: String,
    price_jpy: String,
    sort_order: String,
    photo_storage_path: String,
    photo_alt_ja: String,
    photo_alt_en: String,
    is_active: bool,
    message: String,
    has_message: bool,
    error: String,
    has_error: bool,
}

#[derive(Debug, Clone)]
struct MaterialCreateInput {
    key: String,
    label_ja: String,
    label_en: String,
    description_ja: String,
    description_en: String,
    price_jpy: i64,
    sort_order: i64,
    photo_storage_path: String,
    photo_alt_ja: String,
    photo_alt_en: String,
    is_active: bool,
}

#[derive(Debug, Clone)]
struct MaterialPatchInput {
    label_ja: String,
    label_en: String,
    description_ja: String,
    description_en: String,
    price_jpy: i64,
    sort_order: i64,
    photo_storage_path: String,
    photo_alt_ja: String,
    photo_alt_en: String,
    is_active: bool,
}

#[derive(Template)]
#[template(path = "orders_page.html")]
struct OrdersPageTemplate {
    filters: OrderFilter,
    status_options: Vec<StatusOptionView>,
    country_options: Vec<CountryOptionView>,
    source_label: String,
    is_mock: bool,
    orders_list_html: String,
    order_detail_html: String,
    has_order_detail: bool,
}

#[derive(Template)]
#[template(path = "materials_page.html")]
struct MaterialsPageTemplate {
    source_label: String,
    is_mock: bool,
    materials_list_html: String,
}

#[derive(Template)]
#[template(path = "material_edit_page.html")]
struct MaterialEditPageTemplate {
    source_label: String,
    is_mock: bool,
    material_key: String,
    material_detail_html: String,
}

#[derive(Template)]
#[template(path = "material_create_page.html")]
struct MaterialCreatePageTemplate {
    source_label: String,
    is_mock: bool,
    material_create_html: String,
}

#[derive(Template)]
#[template(path = "orders_list.html")]
struct OrdersListTemplate {
    orders: Vec<OrderListItemView>,
    has_orders: bool,
}

#[derive(Template)]
#[template(path = "order_detail.html")]
struct OrderDetailTemplate {
    detail: OrderDetailView,
}

#[derive(Template)]
#[template(path = "materials_list.html")]
struct MaterialsListTemplate {
    materials: Vec<MaterialListItemView>,
    has_materials: bool,
}

#[derive(Template)]
#[template(path = "material_detail.html")]
struct MaterialDetailTemplate {
    detail: MaterialDetailView,
}

#[derive(Template)]
#[template(path = "material_create.html")]
struct MaterialCreateTemplate {
    view: MaterialCreateView,
}

#[tokio::main]
async fn main() {
    if let Err(error) = run().await {
        eprintln!("failed to start admin server: {error:#}");
        std::process::exit(1);
    }
}

async fn run() -> Result<()> {
    let cfg = load_config().context("failed to load config")?;
    let server = build_server(&cfg).await?;

    let app = Router::new()
        .route("/", get(handle_root))
        .route("/admin/orders", get(handle_orders_page))
        .route("/admin/orders/list", get(handle_orders_list))
        .route("/admin/orders/{order_id}", get(handle_order_detail))
        .route(
            "/admin/orders/{order_id}/status",
            patch(handle_order_status_patch),
        )
        .route(
            "/admin/orders/{order_id}/shipping",
            patch(handle_order_shipping_patch),
        )
        .route(
            "/admin/materials",
            get(handle_materials_page).post(handle_material_create),
        )
        .route(
            "/admin/materials/photo-upload",
            axum::routing::post(handle_material_photo_upload),
        )
        .route("/admin/materials/list", get(handle_materials_list))
        .route("/admin/materials/new", get(handle_material_create_page))
        .route(
            "/admin/materials/{material_key}/edit",
            get(handle_material_edit_page),
        )
        .route(
            "/admin/materials/{material_key}",
            get(handle_material_detail)
                .patch(handle_material_patch)
                .delete(handle_material_delete),
        )
        .nest_service("/static", ServeDir::new("static"))
        .with_state(AppState {
            server: Arc::clone(&server),
        });

    let bind_addr = normalize_bind_addr(&cfg.http_addr);
    let listener = TcpListener::bind(&bind_addr)
        .await
        .with_context(|| format!("failed to bind {bind_addr}"))?;

    let public_url = format!("http://localhost{}", cfg.http_addr);
    if let Some(project_id) = cfg.firestore_project_id.as_deref() {
        println!(
            "hanko admin listening on {public_url} mode={} source={} project={}",
            cfg.mode.as_str(),
            server.source_label,
            project_id
        );
    } else {
        println!(
            "hanko admin listening on {public_url} mode={} source={}",
            cfg.mode.as_str(),
            server.source_label
        );
    }

    axum::serve(listener, app)
        .with_graceful_shutdown(async {
            let _ = tokio::signal::ctrl_c().await;
        })
        .await
        .context("admin server terminated unexpectedly")
}

fn normalize_bind_addr(http_addr: &str) -> String {
    let trimmed = http_addr.trim();
    if trimmed.starts_with(':') {
        format!("0.0.0.0{trimmed}")
    } else if trimmed.contains(':') {
        trimmed.to_owned()
    } else {
        format!("0.0.0.0:{trimmed}")
    }
}

fn load_config() -> Result<AppConfig> {
    let mut cfg = AppConfig {
        http_addr: env::var("ADMIN_HTTP_ADDR")
            .unwrap_or_default()
            .trim()
            .to_owned(),
        mode: RunMode::Mock,
        locale: env::var("HANKO_ADMIN_LOCALE")
            .unwrap_or_default()
            .trim()
            .to_owned(),
        default_locale: env::var("HANKO_ADMIN_DEFAULT_LOCALE")
            .unwrap_or_default()
            .trim()
            .to_owned(),
        firestore_project_id: None,
        storage_assets_bucket: None,
        credentials_file: None,
    };

    if cfg.http_addr.is_empty() {
        cfg.http_addr = ":3051".to_owned();
    }
    if cfg.locale.is_empty() {
        cfg.locale = "ja".to_owned();
    }
    if cfg.default_locale.is_empty() {
        cfg.default_locale = "ja".to_owned();
    }

    let mut mode_value = env_first(&["HANKO_ADMIN_MODE", "HANKO_ADMIN_ENV"]).to_lowercase();
    if mode_value.is_empty() {
        mode_value = "mock".to_owned();
    }

    match mode_value.as_str() {
        "mock" => {
            cfg.mode = RunMode::Mock;
            return Ok(cfg);
        }
        "dev" => cfg.mode = RunMode::Dev,
        "prod" => cfg.mode = RunMode::Prod,
        _ => bail!("invalid HANKO_ADMIN_MODE {mode_value:?}: use mock, dev, or prod"),
    }

    let (project_id_keys, credential_keys, storage_bucket_keys): (&[&str], &[&str], &[&str]) =
        match cfg.mode {
            RunMode::Dev => (
                &[
                    "HANKO_ADMIN_FIREBASE_PROJECT_ID_DEV",
                    "HANKO_ADMIN_FIREBASE_PROJECT_ID",
                    "FIRESTORE_PROJECT_ID",
                    "FIREBASE_PROJECT_ID",
                    "GOOGLE_CLOUD_PROJECT",
                ],
                &[
                    "HANKO_ADMIN_FIREBASE_CREDENTIALS_FILE_DEV",
                    "HANKO_ADMIN_FIREBASE_CREDENTIALS_FILE",
                    "GOOGLE_APPLICATION_CREDENTIALS",
                ],
                &[
                    "HANKO_ADMIN_STORAGE_ASSETS_BUCKET_DEV",
                    "HANKO_ADMIN_STORAGE_ASSETS_BUCKET",
                    "API_STORAGE_ASSETS_BUCKET",
                ],
            ),
            RunMode::Prod => (
                &[
                    "HANKO_ADMIN_FIREBASE_PROJECT_ID_PROD",
                    "HANKO_ADMIN_FIREBASE_PROJECT_ID",
                    "FIRESTORE_PROJECT_ID",
                    "FIREBASE_PROJECT_ID",
                    "GOOGLE_CLOUD_PROJECT",
                ],
                &[
                    "HANKO_ADMIN_FIREBASE_CREDENTIALS_FILE_PROD",
                    "HANKO_ADMIN_FIREBASE_CREDENTIALS_FILE",
                    "GOOGLE_APPLICATION_CREDENTIALS",
                ],
                &[
                    "HANKO_ADMIN_STORAGE_ASSETS_BUCKET_PROD",
                    "HANKO_ADMIN_STORAGE_ASSETS_BUCKET",
                    "API_STORAGE_ASSETS_BUCKET",
                ],
            ),
            RunMode::Mock => (&[], &[], &[]),
        };

    let project_id = env_first(project_id_keys);
    if project_id.is_empty() {
        bail!(
            "firebase mode ({}) requires project id env var: {}",
            cfg.mode.as_str(),
            project_id_keys.join(", ")
        );
    }
    cfg.firestore_project_id = Some(project_id);

    let credentials_file = env_first(credential_keys);
    if !credentials_file.is_empty() {
        cfg.credentials_file = Some(credentials_file);
    }

    let storage_assets_bucket = env_first(storage_bucket_keys);
    if !storage_assets_bucket.is_empty() {
        cfg.storage_assets_bucket = Some(storage_assets_bucket);
    }

    Ok(cfg)
}

fn env_first(keys: &[&str]) -> String {
    for key in keys {
        if let Ok(value) = env::var(key) {
            let trimmed = value.trim();
            if !trimmed.is_empty() {
                return trimmed.to_owned();
            }
        }
    }
    String::new()
}

async fn build_server(cfg: &AppConfig) -> Result<Arc<ServerState>> {
    let source = match cfg.mode {
        RunMode::Mock => DataSource::Mock,
        RunMode::Dev | RunMode::Prod => {
            let label = if cfg.mode == RunMode::Prod {
                "Firebase Prod"
            } else {
                "Firebase Dev"
            }
            .to_owned();

            let token_provider: Arc<dyn TokenProvider> =
                if let Some(credentials_file) = cfg.credentials_file.as_deref() {
                    Arc::new(
                        CustomServiceAccount::from_file(credentials_file).with_context(|| {
                            format!("failed to read credentials file: {credentials_file}")
                        })?,
                    )
                } else {
                    provider()
                        .await
                        .context("failed to initialize default GCP auth provider")?
                };

            let project_id = cfg
                .firestore_project_id
                .clone()
                .context("firestore project id is empty")?;

            DataSource::Firestore(FirestoreAdminSource {
                parent: format!("projects/{project_id}/databases/(default)/documents"),
                locale: cfg.locale.clone(),
                default_locale: cfg.default_locale.clone(),
                label,
                storage_assets_bucket: cfg.storage_assets_bucket.clone().unwrap_or_default(),
                token_provider,
            })
        }
    };

    let snapshot = if source.is_mock() {
        new_mock_snapshot()
    } else {
        tokio::time::timeout(Duration::from_secs(7), source.load_snapshot())
            .await
            .context("admin data load timed out after 7s")??
    };

    Ok(Arc::new(ServerState {
        source_label: source.label().to_owned(),
        source,
        data: RwLock::new(snapshot),
    }))
}

async fn handle_root() -> Redirect {
    Redirect::to("/admin/orders")
}

async fn handle_orders_page(
    State(state): State<AppState>,
    Query(query): Query<OrdersPageQuery>,
) -> Response {
    if let Err(error) = state.server.refresh_from_source().await {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to load orders: {error}"),
        );
    }

    let filters = OrderFilter {
        status: normalize_query_value(query.status),
        country: normalize_query_value(query.country),
        email: normalize_query_value(query.email),
    };

    let orders = state.server.filter_orders(&filters).await;
    let orders_list_html = match render_orders_list(&orders) {
        Ok(html) => html,
        Err(error) => {
            return plain_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("failed to render orders list: {error}"),
            );
        }
    };

    let mut selected_order_id = normalize_query_value(query.order_id);
    if selected_order_id.is_empty() {
        if let Some(first) = orders.first() {
            selected_order_id = first.id.clone();
        }
    }

    let order_detail = if selected_order_id.is_empty() {
        None
    } else {
        state
            .server
            .get_order_detail(&selected_order_id, "", "")
            .await
    };

    let order_detail_html = if let Some(detail) = order_detail.as_ref() {
        match render_order_detail(detail) {
            Ok(html) => html,
            Err(error) => {
                return plain_error(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("failed to render order detail: {error}"),
                );
            }
        }
    } else {
        String::new()
    };

    let page = OrdersPageTemplate {
        filters,
        status_options: status_options(),
        country_options: state.server.country_options().await,
        source_label: state.server.source_label.clone(),
        is_mock: state.server.source.is_mock(),
        orders_list_html,
        order_detail_html,
        has_order_detail: order_detail.is_some(),
    };

    render_template(&page)
}

async fn handle_orders_list(
    State(state): State<AppState>,
    Query(query): Query<OrdersPageQuery>,
) -> Response {
    if let Err(error) = state.server.refresh_from_source().await {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to load orders: {error}"),
        );
    }

    let filters = OrderFilter {
        status: normalize_query_value(query.status),
        country: normalize_query_value(query.country),
        email: normalize_query_value(query.email),
    };

    let orders = state.server.filter_orders(&filters).await;
    match render_orders_list(&orders) {
        Ok(html) => html_response(StatusCode::OK, html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render orders list: {error}"),
        ),
    }
}

async fn handle_order_detail(
    State(state): State<AppState>,
    Path(order_id): Path<String>,
) -> Response {
    if let Err(error) = state.server.refresh_from_source().await {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to load orders: {error}"),
        );
    }

    let Some(detail) = state.server.get_order_detail(&order_id, "", "").await else {
        return plain_error(StatusCode::NOT_FOUND, "not found".to_owned());
    };

    match render_order_detail(&detail) {
        Ok(html) => html_response(StatusCode::OK, html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render order detail: {error}"),
        ),
    }
}

async fn handle_order_status_patch(
    State(state): State<AppState>,
    Path(order_id): Path<String>,
    form: std::result::Result<Form<HashMap<String, String>>, FormRejection>,
) -> Response {
    let Form(form) = match form {
        Ok(form) => form,
        Err(_) => return plain_error(StatusCode::BAD_REQUEST, "invalid request".to_owned()),
    };

    if let Err(error) = state.server.refresh_from_source().await {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to load orders: {error}"),
        );
    }

    let next_status = form_value(&form, "next_status");
    let actor_id = {
        let value = form_value(&form, "actor_id");
        if value.is_empty() {
            "admin.console".to_owned()
        } else {
            value
        }
    };

    match state
        .server
        .update_order_status(&order_id, &next_status, &actor_id)
        .await
    {
        Ok(()) => {
            let Some(detail) = state
                .server
                .get_order_detail(&order_id, "ステータスを更新しました。", "")
                .await
            else {
                return plain_error(StatusCode::NOT_FOUND, "not found".to_owned());
            };
            match render_order_detail(&detail) {
                Ok(html) => html_response_with_trigger(StatusCode::OK, html, "order-updated"),
                Err(error) => plain_error(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("failed to render order detail: {error}"),
                ),
            }
        }
        Err(error_message) => {
            let Some(detail) = state
                .server
                .get_order_detail(&order_id, "", &error_message)
                .await
            else {
                return plain_error(StatusCode::NOT_FOUND, "not found".to_owned());
            };
            match render_order_detail(&detail) {
                Ok(html) => html_response(StatusCode::BAD_REQUEST, html),
                Err(error) => plain_error(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("failed to render order detail: {error}"),
                ),
            }
        }
    }
}

async fn handle_order_shipping_patch(
    State(state): State<AppState>,
    Path(order_id): Path<String>,
    form: std::result::Result<Form<HashMap<String, String>>, FormRejection>,
) -> Response {
    let Form(form) = match form {
        Ok(form) => form,
        Err(_) => return plain_error(StatusCode::BAD_REQUEST, "invalid request".to_owned()),
    };

    if let Err(error) = state.server.refresh_from_source().await {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to load orders: {error}"),
        );
    }

    let carrier = form_value(&form, "carrier");
    let tracking_no = form_value(&form, "tracking_no");
    let transition = form_value(&form, "shipping_transition");
    let actor_id = {
        let value = form_value(&form, "actor_id");
        if value.is_empty() {
            "admin.console".to_owned()
        } else {
            value
        }
    };

    match state
        .server
        .update_shipping(&order_id, &carrier, &tracking_no, &transition, &actor_id)
        .await
    {
        Ok(()) => {
            let Some(detail) = state
                .server
                .get_order_detail(&order_id, "出荷情報を更新しました。", "")
                .await
            else {
                return plain_error(StatusCode::NOT_FOUND, "not found".to_owned());
            };
            match render_order_detail(&detail) {
                Ok(html) => html_response_with_trigger(StatusCode::OK, html, "order-updated"),
                Err(error) => plain_error(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("failed to render order detail: {error}"),
                ),
            }
        }
        Err(error_message) => {
            let Some(detail) = state
                .server
                .get_order_detail(&order_id, "", &error_message)
                .await
            else {
                return plain_error(StatusCode::NOT_FOUND, "not found".to_owned());
            };
            match render_order_detail(&detail) {
                Ok(html) => html_response(StatusCode::BAD_REQUEST, html),
                Err(error) => plain_error(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("failed to render order detail: {error}"),
                ),
            }
        }
    }
}

async fn handle_materials_page(State(state): State<AppState>) -> Response {
    if let Err(error) = state.server.refresh_from_source().await {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to load materials: {error}"),
        );
    }

    let materials = state.server.list_materials().await;
    let materials_list_html = match render_materials_list(&materials) {
        Ok(html) => html,
        Err(error) => {
            return plain_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("failed to render materials list: {error}"),
            );
        }
    };

    let page = MaterialsPageTemplate {
        source_label: state.server.source_label.clone(),
        is_mock: state.server.source.is_mock(),
        materials_list_html,
    };

    render_template(&page)
}

async fn handle_materials_list(State(state): State<AppState>) -> Response {
    if let Err(error) = state.server.refresh_from_source().await {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to load materials: {error}"),
        );
    }

    let materials = state.server.list_materials().await;
    match render_materials_list(&materials) {
        Ok(html) => html_response(StatusCode::OK, html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render materials list: {error}"),
        ),
    }
}

async fn handle_material_create_page(State(state): State<AppState>) -> Response {
    if let Err(error) = state.server.refresh_from_source().await {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to load materials: {error}"),
        );
    }

    let material_create_html = match render_material_create(&new_material_create_view("", "")) {
        Ok(html) => html,
        Err(error) => {
            return plain_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("failed to render material create: {error}"),
            );
        }
    };

    let page = MaterialCreatePageTemplate {
        source_label: state.server.source_label.clone(),
        is_mock: state.server.source.is_mock(),
        material_create_html,
    };

    render_template(&page)
}

async fn handle_material_edit_page(
    State(state): State<AppState>,
    Path(material_key): Path<String>,
) -> Response {
    if let Err(error) = state.server.refresh_from_source().await {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to load materials: {error}"),
        );
    }

    let Some(detail) = state
        .server
        .get_material_detail(&material_key, "", "")
        .await
    else {
        return plain_error(StatusCode::NOT_FOUND, "not found".to_owned());
    };

    let material_detail_html = match render_material_detail(&detail) {
        Ok(html) => html,
        Err(error) => {
            return plain_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("failed to render material detail: {error}"),
            );
        }
    };

    let page = MaterialEditPageTemplate {
        source_label: state.server.source_label.clone(),
        is_mock: state.server.source.is_mock(),
        material_key,
        material_detail_html,
    };

    render_template(&page)
}

async fn handle_material_detail(
    State(state): State<AppState>,
    Path(material_key): Path<String>,
) -> Response {
    if let Err(error) = state.server.refresh_from_source().await {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to load materials: {error}"),
        );
    }

    let Some(detail) = state
        .server
        .get_material_detail(&material_key, "", "")
        .await
    else {
        return plain_error(StatusCode::NOT_FOUND, "not found".to_owned());
    };

    match render_material_detail(&detail) {
        Ok(html) => html_response(StatusCode::OK, html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render material detail: {error}"),
        ),
    }
}

async fn handle_material_photo_upload(
    State(state): State<AppState>,
    mut multipart: Multipart,
) -> Response {
    if let Err(error) = state.server.refresh_from_source().await {
        return json_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            &format!("failed to load materials: {error}"),
        );
    }

    let mut material_key = String::new();
    let mut file_name = String::new();
    let mut content_type: Option<String> = None;
    let mut bytes = Vec::new();

    loop {
        let next = match multipart.next_field().await {
            Ok(next) => next,
            Err(error) => {
                return json_error(
                    StatusCode::BAD_REQUEST,
                    &format!("invalid multipart: {error}"),
                );
            }
        };

        let Some(field) = next else {
            break;
        };

        let Some(name) = field.name() else {
            continue;
        };

        match name {
            "material_key" => {
                material_key = match field.text().await {
                    Ok(text) => text.trim().to_owned(),
                    Err(error) => {
                        return json_error(
                            StatusCode::BAD_REQUEST,
                            &format!("invalid material key: {error}"),
                        );
                    }
                };
            }
            "photo_file" => {
                if let Some(value) = field.file_name() {
                    file_name = value.to_owned();
                }
                content_type = field.content_type().map(ToOwned::to_owned);

                let payload = match field.bytes().await {
                    Ok(payload) => payload,
                    Err(error) => {
                        return json_error(
                            StatusCode::BAD_REQUEST,
                            &format!("failed to read upload file: {error}"),
                        );
                    }
                };

                bytes = payload.to_vec();
            }
            _ => {}
        }
    }

    if material_key.is_empty() {
        return json_error(
            StatusCode::BAD_REQUEST,
            "材質キーを入力してから画像をアップロードしてください。",
        );
    }

    if bytes.is_empty() {
        return json_error(StatusCode::BAD_REQUEST, "画像ファイルを選択してください。");
    }

    match state
        .server
        .upload_material_photo(&material_key, &file_name, content_type.as_deref(), &bytes)
        .await
    {
        Ok(storage_path) => json_response(
            StatusCode::OK,
            json!({
                "storage_path": storage_path,
            }),
        ),
        Err(error_message) => json_error(StatusCode::BAD_REQUEST, &error_message),
    }
}

async fn handle_material_create(
    State(state): State<AppState>,
    form: std::result::Result<Form<HashMap<String, String>>, FormRejection>,
) -> Response {
    let Form(form) = match form {
        Ok(form) => form,
        Err(_) => return plain_error(StatusCode::BAD_REQUEST, "invalid request".to_owned()),
    };

    if let Err(error) = state.server.refresh_from_source().await {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to load materials: {error}"),
        );
    }

    let price_jpy = match form_value(&form, "price_jpy").parse::<i64>() {
        Ok(value) => value,
        Err(_) => {
            return render_material_create_response(
                StatusCode::BAD_REQUEST,
                &material_create_view_from_form(&form, "", "価格は整数で入力してください。"),
            );
        }
    };

    let sort_order = match form_value(&form, "sort_order").parse::<i64>() {
        Ok(value) => value,
        Err(_) => {
            return render_material_create_response(
                StatusCode::BAD_REQUEST,
                &material_create_view_from_form(&form, "", "表示順は整数で入力してください。"),
            );
        }
    };

    let input = MaterialCreateInput {
        key: form_value(&form, "key"),
        label_ja: form_value(&form, "label_ja"),
        label_en: form_value(&form, "label_en"),
        description_ja: form_value(&form, "description_ja"),
        description_en: form_value(&form, "description_en"),
        price_jpy,
        sort_order,
        photo_storage_path: form_value(&form, "photo_storage_path"),
        photo_alt_ja: form_value(&form, "photo_alt_ja"),
        photo_alt_en: form_value(&form, "photo_alt_en"),
        is_active: form.contains_key("is_active"),
    };
    let created_key = input.key.clone();

    match state.server.create_material(input).await {
        Ok(()) => render_material_create_response_with_trigger(
            StatusCode::CREATED,
            &new_material_create_view(&format!("材質「{created_key}」を作成しました。"), ""),
            "material-updated",
        ),
        Err(error_message) => render_material_create_response(
            StatusCode::BAD_REQUEST,
            &material_create_view_from_form(&form, "", &error_message),
        ),
    }
}

async fn handle_material_delete(
    State(state): State<AppState>,
    Path(material_key): Path<String>,
) -> Response {
    if let Err(error) = state.server.refresh_from_source().await {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to load materials: {error}"),
        );
    }

    match state.server.delete_material(&material_key).await {
        Ok(()) => {
            let materials = state.server.list_materials().await;
            match render_materials_list(&materials) {
                Ok(html) => html_response_with_trigger(StatusCode::OK, html, "material-updated"),
                Err(error) => plain_error(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("failed to render materials list: {error}"),
                ),
            }
        }
        Err(error_message) => plain_error(StatusCode::BAD_REQUEST, error_message),
    }
}

async fn handle_material_patch(
    State(state): State<AppState>,
    Path(material_key): Path<String>,
    form: std::result::Result<Form<HashMap<String, String>>, FormRejection>,
) -> Response {
    let Form(form) = match form {
        Ok(form) => form,
        Err(_) => return plain_error(StatusCode::BAD_REQUEST, "invalid request".to_owned()),
    };

    if let Err(error) = state.server.refresh_from_source().await {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to load materials: {error}"),
        );
    }

    let price_jpy = match form_value(&form, "price_jpy").parse::<i64>() {
        Ok(value) => value,
        Err(_) => {
            let Some(detail) = state
                .server
                .get_material_detail(&material_key, "", "価格は整数で入力してください。")
                .await
            else {
                return plain_error(StatusCode::NOT_FOUND, "not found".to_owned());
            };
            return match render_material_detail(&detail) {
                Ok(html) => html_response(StatusCode::BAD_REQUEST, html),
                Err(error) => plain_error(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("failed to render material detail: {error}"),
                ),
            };
        }
    };

    let sort_order = match form_value(&form, "sort_order").parse::<i64>() {
        Ok(value) => value,
        Err(_) => {
            let Some(detail) = state
                .server
                .get_material_detail(&material_key, "", "表示順は整数で入力してください。")
                .await
            else {
                return plain_error(StatusCode::NOT_FOUND, "not found".to_owned());
            };
            return match render_material_detail(&detail) {
                Ok(html) => html_response(StatusCode::BAD_REQUEST, html),
                Err(error) => plain_error(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("failed to render material detail: {error}"),
                ),
            };
        }
    };

    let input = MaterialPatchInput {
        label_ja: form_value(&form, "label_ja"),
        label_en: form_value(&form, "label_en"),
        description_ja: form_value(&form, "description_ja"),
        description_en: form_value(&form, "description_en"),
        price_jpy,
        sort_order,
        photo_storage_path: form_value(&form, "photo_storage_path"),
        photo_alt_ja: form_value(&form, "photo_alt_ja"),
        photo_alt_en: form_value(&form, "photo_alt_en"),
        is_active: form.contains_key("is_active"),
    };

    match state.server.update_material(&material_key, input).await {
        Ok(()) => {
            let Some(detail) = state
                .server
                .get_material_detail(&material_key, "材質マスタを更新しました。", "")
                .await
            else {
                return plain_error(StatusCode::NOT_FOUND, "not found".to_owned());
            };
            match render_material_detail(&detail) {
                Ok(html) => html_response_with_trigger(StatusCode::OK, html, "material-updated"),
                Err(error) => plain_error(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("failed to render material detail: {error}"),
                ),
            }
        }
        Err(error_message) => {
            let Some(detail) = state
                .server
                .get_material_detail(&material_key, "", &error_message)
                .await
            else {
                return plain_error(StatusCode::NOT_FOUND, "not found".to_owned());
            };
            match render_material_detail(&detail) {
                Ok(html) => html_response(StatusCode::BAD_REQUEST, html),
                Err(error) => plain_error(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("failed to render material detail: {error}"),
                ),
            }
        }
    }
}

impl ServerState {
    async fn refresh_from_source(&self) -> Result<()> {
        if self.source.is_mock() {
            return Ok(());
        }

        let snapshot = tokio::time::timeout(Duration::from_secs(7), self.source.load_snapshot())
            .await
            .context("admin data load timed out after 7s")??;

        let mut data = self.data.write().await;
        *data = snapshot;
        Ok(())
    }

    async fn filter_orders(&self, filters: &OrderFilter) -> Vec<OrderListItemView> {
        let data = self.data.read().await;

        let mut items = Vec::with_capacity(data.order_ids.len());
        for id in &data.order_ids {
            let Some(order) = data.orders.get(id) else {
                continue;
            };

            if !filters.status.is_empty() && order.status != filters.status {
                continue;
            }
            if !filters.country.is_empty()
                && !order.country_code.eq_ignore_ascii_case(&filters.country)
            {
                continue;
            }
            if !filters.email.is_empty()
                && !order
                    .contact_email
                    .to_lowercase()
                    .contains(&filters.email.to_lowercase())
            {
                continue;
            }

            items.push(OrderListItemView {
                id: order.id.clone(),
                order_no: order.order_no.clone(),
                created_at: format_datetime(order.created_at),
                status_label: order_status_label(&order.status).to_owned(),
                payment_status_label: payment_status_label(&order.payment_status).to_owned(),
                fulfillment_status_label: fulfillment_status_label(&order.fulfillment_status)
                    .to_owned(),
                country_label: country_label(&data.countries, &order.country_code),
                total_jpy: format_yen(order.total_jpy),
            });
        }

        items
    }

    async fn get_order_detail(
        &self,
        order_id: &str,
        message: &str,
        render_error: &str,
    ) -> Option<OrderDetailView> {
        let data = self.data.read().await;
        let order = data.orders.get(order_id)?;

        let mut events = order.events.clone();
        events.sort_by(|left, right| right.created_at.cmp(&left.created_at));

        let event_views = events
            .into_iter()
            .map(|event| {
                let has_before_status = !event.before_status.is_empty();
                let has_note = !event.note.is_empty();
                let has_actor_id = !event.actor_id.is_empty();
                OrderEventView {
                    kind: event.kind,
                    actor_type: event.actor_type,
                    actor_id: event.actor_id,
                    has_actor_id,
                    before_status_label: order_status_label(&event.before_status).to_owned(),
                    after_status_label: order_status_label(&event.after_status).to_owned(),
                    has_before_status,
                    note: event.note,
                    has_note,
                    created_at: format_datetime(event.created_at),
                }
            })
            .collect::<Vec<_>>();

        let next_statuses = next_status_options(&order.status);
        let shipping_transitions = shipping_transition_options(&order.status);

        Some(OrderDetailView {
            id: order.id.clone(),
            order_no: order.order_no.clone(),
            created_at: format_datetime(order.created_at),
            updated_at: format_datetime(order.updated_at),
            status_label: order_status_label(&order.status).to_owned(),
            payment_status_label: payment_status_label(&order.payment_status).to_owned(),
            fulfillment_status_label: fulfillment_status_label(&order.fulfillment_status)
                .to_owned(),
            tracking_no: order.tracking_no.clone(),
            has_tracking_no: !order.tracking_no.is_empty(),
            carrier: order.carrier.clone(),
            country_code: order.country_code.clone(),
            country_label: country_label(&data.countries, &order.country_code),
            contact_email: order.contact_email.clone(),
            channel: order.channel.clone(),
            locale: order.locale.clone(),
            seal_line1: order.seal_line1.clone(),
            seal_line2: order.seal_line2.clone(),
            has_seal_line2: !order.seal_line2.is_empty(),
            material_label_ja: order.material_label_ja.clone(),
            total_jpy: format_yen(order.total_jpy),
            has_next_statuses: !next_statuses.is_empty(),
            next_statuses,
            shipping_transitions,
            events: event_views,
            message: message.to_owned(),
            has_message: !message.is_empty(),
            error: render_error.to_owned(),
            has_error: !render_error.is_empty(),
        })
    }

    async fn list_materials(&self) -> Vec<MaterialListItemView> {
        let data = self.data.read().await;
        let mut items = Vec::with_capacity(data.material_ids.len());

        for key in &data.material_ids {
            let Some(material) = data.materials.get(key) else {
                continue;
            };
            let primary_photo = select_primary_material_photo(&material.photos);

            items.push(MaterialListItemView {
                key: material.key.clone(),
                label_ja: material.label_i18n.get("ja").cloned().unwrap_or_default(),
                primary_photo_path: primary_photo
                    .map(|photo| photo.storage_path.clone())
                    .unwrap_or_default(),
                has_photo: primary_photo.is_some(),
                price_jpy: format_yen(material.price_jpy),
                is_active: material.is_active,
                version: material.version,
                updated_at: format_datetime(material.updated_at),
            });
        }

        items
    }

    async fn get_material_detail(
        &self,
        key: &str,
        message: &str,
        render_error: &str,
    ) -> Option<MaterialDetailView> {
        let data = self.data.read().await;
        let material = data.materials.get(key)?;
        let primary_photo = select_primary_material_photo(&material.photos);

        Some(MaterialDetailView {
            key: material.key.clone(),
            label_ja: material.label_i18n.get("ja").cloned().unwrap_or_default(),
            label_en: material.label_i18n.get("en").cloned().unwrap_or_default(),
            description_ja: material
                .description_i18n
                .get("ja")
                .cloned()
                .unwrap_or_default(),
            description_en: material
                .description_i18n
                .get("en")
                .cloned()
                .unwrap_or_default(),
            price_jpy: material.price_jpy,
            is_active: material.is_active,
            sort_order: material.sort_order,
            photo_storage_path: primary_photo
                .map(|photo| photo.storage_path.clone())
                .unwrap_or_default(),
            photo_alt_ja: primary_photo
                .and_then(|photo| photo.alt_i18n.get("ja").cloned())
                .unwrap_or_default(),
            photo_alt_en: primary_photo
                .and_then(|photo| photo.alt_i18n.get("en").cloned())
                .unwrap_or_default(),
            version: material.version,
            updated_at: format_datetime(material.updated_at),
            message: message.to_owned(),
            has_message: !message.is_empty(),
            error: render_error.to_owned(),
            has_error: !render_error.is_empty(),
        })
    }

    async fn country_options(&self) -> Vec<CountryOptionView> {
        let data = self.data.read().await;

        let mut options = data
            .countries
            .iter()
            .map(|(code, label)| CountryOptionView {
                code: code.clone(),
                label: label.clone(),
            })
            .collect::<Vec<_>>();

        options.sort_by(|left, right| left.code.cmp(&right.code));
        options
    }

    async fn update_order_status(
        &self,
        order_id: &str,
        next_status: &str,
        actor_id: &str,
    ) -> std::result::Result<(), String> {
        let next_status = next_status.trim();
        if next_status.is_empty() {
            return Err("更新先のステータスを選択してください。".to_owned());
        }

        let (updated_order, new_events) = {
            let mut data = self.data.write().await;
            let Some(order) = data.orders.get_mut(order_id) else {
                return Err("注文が見つかりません。".to_owned());
            };

            if order.status == next_status {
                return Err("現在と同じステータスには更新できません。".to_owned());
            }

            let allowed = status_transitions(&order.status);
            if !allowed.contains(&next_status) {
                return Err(format!(
                    "{} から {} には遷移できません。",
                    order_status_label(&order.status),
                    order_status_label(next_status)
                ));
            }

            let now = Utc::now();
            let before = order.status.clone();
            order.status = next_status.to_owned();
            order.status_updated_at = now;
            order.updated_at = now;
            apply_derived_statuses(order);

            let event = OrderEvent {
                kind: "status_changed".to_owned(),
                actor_type: "admin".to_owned(),
                actor_id: actor_id.trim().to_owned(),
                before_status: before,
                after_status: next_status.to_owned(),
                note: String::new(),
                created_at: now,
            };
            order.events.push(event.clone());

            (order.clone(), vec![event])
        };

        if let Err(error) = self
            .source
            .persist_order_mutation(&updated_order, &new_events)
            .await
        {
            if let Err(refresh_error) = self.refresh_from_source().await {
                eprintln!(
                    "failed to rollback from firestore after status update error: {refresh_error}"
                );
            }
            return Err(format!("firestore update failed: {error}"));
        }

        Ok(())
    }

    async fn update_shipping(
        &self,
        order_id: &str,
        carrier: &str,
        tracking_no: &str,
        transition: &str,
        actor_id: &str,
    ) -> std::result::Result<(), String> {
        if carrier.trim().is_empty() {
            return Err("配送業者を入力してください。".to_owned());
        }
        if tracking_no.trim().is_empty() {
            return Err("追跡番号を入力してください。".to_owned());
        }

        let (updated_order, new_events) = {
            let mut data = self.data.write().await;
            let Some(order) = data.orders.get_mut(order_id) else {
                return Err("注文が見つかりません。".to_owned());
            };

            let transition = transition.trim();
            if !transition.is_empty() && transition != "none" {
                if order.status == transition {
                    return Err("現在と同じステータスは指定できません。".to_owned());
                }

                let allowed = status_transitions(&order.status);
                if !allowed.contains(&transition) {
                    return Err(format!(
                        "{} から {} には遷移できません。",
                        order_status_label(&order.status),
                        order_status_label(transition)
                    ));
                }
            }

            let now = Utc::now();
            let before_status = order.status.clone();
            let mut events = Vec::new();

            order.carrier = carrier.trim().to_owned();
            order.tracking_no = tracking_no.trim().to_owned();
            order.updated_at = now;

            let shipment_event = OrderEvent {
                kind: "shipment_registered".to_owned(),
                actor_type: "admin".to_owned(),
                actor_id: actor_id.trim().to_owned(),
                before_status: String::new(),
                after_status: String::new(),
                note: format!("{} / {}", order.carrier, order.tracking_no),
                created_at: now,
            };
            order.events.push(shipment_event.clone());
            events.push(shipment_event);

            if !transition.is_empty() && transition != "none" {
                order.status = transition.to_owned();
                order.status_updated_at = now;
                apply_derived_statuses(order);

                let status_event = OrderEvent {
                    kind: "status_changed".to_owned(),
                    actor_type: "admin".to_owned(),
                    actor_id: actor_id.trim().to_owned(),
                    before_status,
                    after_status: transition.to_owned(),
                    note: String::new(),
                    created_at: now,
                };
                order.events.push(status_event.clone());
                events.push(status_event);
            }

            (order.clone(), events)
        };

        if let Err(error) = self
            .source
            .persist_order_mutation(&updated_order, &new_events)
            .await
        {
            if let Err(refresh_error) = self.refresh_from_source().await {
                eprintln!(
                    "failed to rollback from firestore after shipping update error: {refresh_error}"
                );
            }
            return Err(format!("firestore update failed: {error}"));
        }

        Ok(())
    }

    async fn update_material(
        &self,
        key: &str,
        input: MaterialPatchInput,
    ) -> std::result::Result<(), String> {
        let label_ja = input.label_ja.trim().to_owned();
        let label_en = input.label_en.trim().to_owned();
        let description_ja = input.description_ja.trim().to_owned();
        let description_en = input.description_en.trim().to_owned();
        let photo_storage_path = normalize_storage_path(&input.photo_storage_path);
        let photo_alt_ja = input.photo_alt_ja.trim().to_owned();
        let photo_alt_en = input.photo_alt_en.trim().to_owned();
        validate_material_values(
            &label_ja,
            &label_en,
            &description_ja,
            &description_en,
            input.price_jpy,
            input.sort_order,
            &photo_storage_path,
        )?;

        let updated_material = {
            let mut data = self.data.write().await;
            let Some(material) = data.materials.get_mut(key) else {
                return Err("材質が見つかりません。".to_owned());
            };

            let now = Utc::now();
            material.label_i18n.insert("ja".to_owned(), label_ja);
            material.label_i18n.insert("en".to_owned(), label_en);
            material
                .description_i18n
                .insert("ja".to_owned(), description_ja);
            material
                .description_i18n
                .insert("en".to_owned(), description_en);
            material.price_jpy = input.price_jpy;
            material.sort_order = input.sort_order;
            material.is_active = input.is_active;
            material.photos = merge_primary_material_photo(
                &material.photos,
                &material.key,
                &photo_storage_path,
                &photo_alt_ja,
                &photo_alt_en,
            );
            material.version += 1;
            material.updated_at = now;

            let updated = material.clone();
            data.refresh_material_ids();
            updated
        };

        if let Err(error) = self
            .source
            .persist_material_mutation(&updated_material)
            .await
        {
            if let Err(refresh_error) = self.refresh_from_source().await {
                eprintln!(
                    "failed to rollback from firestore after material update error: {refresh_error}"
                );
            }
            return Err(format!("firestore update failed: {error}"));
        }

        Ok(())
    }

    async fn create_material(&self, input: MaterialCreateInput) -> std::result::Result<(), String> {
        let key = input.key.trim().to_owned();
        validate_material_key(&key)?;

        let label_ja = input.label_ja.trim().to_owned();
        let label_en = input.label_en.trim().to_owned();
        let description_ja = input.description_ja.trim().to_owned();
        let description_en = input.description_en.trim().to_owned();
        let photo_storage_path = normalize_storage_path(&input.photo_storage_path);
        let photo_alt_ja = input.photo_alt_ja.trim().to_owned();
        let photo_alt_en = input.photo_alt_en.trim().to_owned();
        validate_material_values(
            &label_ja,
            &label_en,
            &description_ja,
            &description_en,
            input.price_jpy,
            input.sort_order,
            &photo_storage_path,
        )?;

        let material = {
            let mut data = self.data.write().await;
            if data.materials.contains_key(&key) {
                return Err("同じ材質キーは既に存在します。".to_owned());
            }

            let now = Utc::now();
            let material = Material {
                key: key.clone(),
                label_i18n: HashMap::from([
                    ("ja".to_owned(), label_ja),
                    ("en".to_owned(), label_en),
                ]),
                description_i18n: HashMap::from([
                    ("ja".to_owned(), description_ja),
                    ("en".to_owned(), description_en),
                ]),
                photos: build_single_material_photos(
                    &key,
                    &photo_storage_path,
                    &photo_alt_ja,
                    &photo_alt_en,
                ),
                price_jpy: input.price_jpy,
                is_active: input.is_active,
                sort_order: input.sort_order,
                version: 1,
                updated_at: now,
            };

            data.materials.insert(key, material.clone());
            data.refresh_material_ids();
            material
        };

        if let Err(error) = self.source.persist_material_mutation(&material).await {
            if let Err(refresh_error) = self.refresh_from_source().await {
                eprintln!(
                    "failed to rollback from firestore after material create error: {refresh_error}"
                );
            }
            return Err(format!("firestore update failed: {error}"));
        }

        Ok(())
    }

    async fn upload_material_photo(
        &self,
        material_key: &str,
        file_name: &str,
        content_type: Option<&str>,
        bytes: &[u8],
    ) -> std::result::Result<String, String> {
        let normalized_key = material_key.trim().to_owned();
        validate_material_key(&normalized_key)?;

        if bytes.is_empty() {
            return Err("画像ファイルが空です。".to_owned());
        }
        if bytes.len() > MAX_PHOTO_UPLOAD_BYTES {
            return Err("画像サイズは 10MB 以下にしてください。".to_owned());
        }

        let normalized_content_type = normalize_image_content_type(file_name, content_type)
            .ok_or_else(|| {
                "対応していない画像形式です。png / jpg / webp / gif / avif を利用してください。"
                    .to_owned()
            })?;

        self.source
            .upload_material_photo(
                &normalized_key,
                file_name,
                Some(normalized_content_type),
                bytes,
            )
            .await
            .map_err(|error| format!("photo upload failed: {error}"))
    }

    async fn delete_material(&self, key: &str) -> std::result::Result<(), String> {
        let normalized_key = key.trim().to_owned();
        if normalized_key.is_empty() {
            return Err("材質キーが不正です。".to_owned());
        }

        {
            let mut data = self.data.write().await;
            let Some(_) = data.materials.remove(&normalized_key) else {
                return Err("材質が見つかりません。".to_owned());
            };
            data.refresh_material_ids();
        }

        if let Err(error) = self.source.persist_material_deletion(&normalized_key).await {
            if let Err(refresh_error) = self.refresh_from_source().await {
                eprintln!(
                    "failed to rollback from firestore after material delete error: {refresh_error}"
                );
            }
            return Err(format!("firestore delete failed: {error}"));
        }

        Ok(())
    }
}

impl FirestoreAdminSource {
    async fn firestore_client(&self) -> Result<FirebaseFirestoreClient> {
        let access_token = self
            .token_provider
            .token(&[DATASTORE_SCOPE])
            .await
            .context("failed to acquire firestore access token")?;

        Ok(FirebaseFirestoreClient::new(
            access_token.as_str().to_owned(),
        ))
    }

    async fn load_snapshot(&self) -> Result<AdminSnapshot> {
        let client = self.firestore_client().await?;

        let orders = self.load_orders(&client).await?;
        let materials = self.load_materials(&client).await?;
        let mut countries = self.load_countries(&client).await?;

        if countries.is_empty() {
            for order in orders.values() {
                if !order.country_code.is_empty() {
                    countries.insert(order.country_code.clone(), order.country_code.clone());
                }
            }
        }

        let mut snapshot = AdminSnapshot {
            orders,
            order_ids: Vec::new(),
            materials,
            material_ids: Vec::new(),
            countries,
        };
        snapshot.refresh_order_ids();
        snapshot.refresh_material_ids();
        Ok(snapshot)
    }

    async fn load_orders(
        &self,
        client: &FirebaseFirestoreClient,
    ) -> Result<HashMap<String, Order>> {
        let query = RunQueryRequest {
            structured_query: Some(json!({
                "from": [{ "collectionId": "orders" }],
                "orderBy": [{
                    "field": { "fieldPath": "created_at" },
                    "direction": "DESCENDING"
                }]
            })),
            ..RunQueryRequest::default()
        };

        let rows = client
            .run_query(&self.parent, &query)
            .await
            .context("failed to load orders")?;

        let mut orders = HashMap::new();
        for row in rows {
            let Some(document) = row.document else {
                continue;
            };
            let Some(order_id) = document_id(&document) else {
                continue;
            };

            let mut order = self.decode_order(&order_id, &document.fields);
            let order_name = document
                .name
                .clone()
                .unwrap_or_else(|| format!("{}/orders/{order_id}", self.parent));
            let events = self
                .load_order_events(client, &order_name, &order_id)
                .await?;
            order.events = events;
            orders.insert(order_id, order);
        }

        Ok(orders)
    }

    async fn load_order_events(
        &self,
        client: &FirebaseFirestoreClient,
        order_name: &str,
        order_id: &str,
    ) -> Result<Vec<OrderEvent>> {
        let query = RunQueryRequest {
            structured_query: Some(json!({
                "from": [{ "collectionId": "events" }],
                "orderBy": [{
                    "field": { "fieldPath": "created_at" },
                    "direction": "ASCENDING"
                }]
            })),
            ..RunQueryRequest::default()
        };

        let rows = client
            .run_query(order_name, &query)
            .await
            .with_context(|| format!("failed to load order events ({order_id})"))?;

        let mut events = Vec::new();
        for row in rows {
            let Some(document) = row.document else {
                continue;
            };
            let data = &document.fields;

            let kind = read_string_field(data, "type");
            let note = {
                let note = read_string_field(data, "note");
                if !note.is_empty() {
                    note
                } else {
                    let payload = read_map_field(data, "payload");
                    let carrier = read_string_field(&payload, "carrier");
                    let tracking_no = read_string_field(&payload, "tracking_no");
                    if carrier.is_empty() && tracking_no.is_empty() {
                        String::new()
                    } else {
                        format!("{} / {}", carrier, tracking_no)
                    }
                    .trim()
                    .to_owned()
                }
            };

            events.push(OrderEvent {
                kind: if kind.is_empty() {
                    "event".to_owned()
                } else {
                    kind
                },
                actor_type: read_string_field(data, "actor_type"),
                actor_id: read_string_field(data, "actor_id"),
                before_status: read_string_field(data, "before_status"),
                after_status: read_string_field(data, "after_status"),
                note,
                created_at: read_timestamp_field(data, "created_at").unwrap_or_else(Utc::now),
            });
        }

        Ok(events)
    }

    fn decode_order(&self, order_id: &str, data: &BTreeMap<String, JsonValue>) -> Order {
        let payment = read_map_field(data, "payment");
        let fulfillment = read_map_field(data, "fulfillment");
        let shipping = read_map_field(data, "shipping");
        let contact = read_map_field(data, "contact");
        let seal = read_map_field(data, "seal");
        let material_data = read_map_field(data, "material");
        let pricing = read_map_field(data, "pricing");

        let total_jpy = read_int_field(&pricing, "total_jpy")
            .or_else(|| read_int_field(data, "total_jpy"))
            .unwrap_or_default();

        let material_label_ja = {
            let localized = resolve_localized_field(
                &material_data,
                "label_i18n",
                "label",
                &self.locale,
                &self.default_locale,
                &read_string_field(&material_data, "key"),
            );
            if localized.is_empty() {
                read_string_field(data, "material_label_ja")
            } else {
                localized
            }
        };

        let created_at = read_timestamp_field(data, "created_at").unwrap_or_else(Utc::now);
        let updated_at = read_timestamp_field(data, "updated_at").unwrap_or(created_at);
        let status_updated_at =
            read_timestamp_field(data, "status_updated_at").unwrap_or(updated_at);

        let mut order = Order {
            id: order_id.to_owned(),
            order_no: read_string_field(data, "order_no"),
            channel: read_string_field(data, "channel"),
            locale: read_string_field(data, "locale"),
            status: read_string_field(data, "status"),
            status_updated_at,
            payment_status: read_string_field(&payment, "status"),
            fulfillment_status: read_string_field(&fulfillment, "status"),
            tracking_no: read_string_field(&fulfillment, "tracking_no"),
            carrier: read_string_field(&fulfillment, "carrier"),
            country_code: read_string_field(&shipping, "country_code").to_uppercase(),
            contact_email: read_string_field(&contact, "email"),
            seal_line1: read_string_field(&seal, "line1"),
            seal_line2: read_string_field(&seal, "line2"),
            material_label_ja,
            total_jpy,
            created_at,
            updated_at,
            events: Vec::new(),
        };

        if order.order_no.is_empty() {
            order.order_no = order_id.to_owned();
        }
        if order.locale.is_empty() {
            order.locale = self.default_locale.clone();
        }
        if order.status.is_empty() {
            order.status = "pending_payment".to_owned();
        }

        fill_derived_statuses(&mut order);
        order
    }

    async fn load_materials(
        &self,
        client: &FirebaseFirestoreClient,
    ) -> Result<HashMap<String, Material>> {
        let query = RunQueryRequest {
            structured_query: Some(json!({
                "from": [{ "collectionId": "materials" }],
                "orderBy": [{
                    "field": { "fieldPath": "sort_order" },
                    "direction": "ASCENDING"
                }]
            })),
            ..RunQueryRequest::default()
        };

        let rows = client
            .run_query(&self.parent, &query)
            .await
            .context("failed to load materials")?;

        let mut materials = HashMap::new();
        for row in rows {
            let Some(document) = row.document else {
                continue;
            };
            let Some(doc_id) = document_id(&document) else {
                continue;
            };

            let data = &document.fields;
            let price_jpy = read_int_field(data, "price_jpy")
                .or_else(|| read_int_field(data, "price"))
                .unwrap_or_default();
            let sort_order = read_int_field(data, "sort_order").unwrap_or_default();
            let version = read_int_field(data, "version").unwrap_or(1);
            let is_active = read_bool_field(data, "is_active").unwrap_or(true);
            let photos = read_material_photos(data);

            let mut label_i18n = read_string_map_field(data, "label_i18n");
            if label_i18n.is_empty() {
                let legacy = read_string_field(data, "label");
                if !legacy.is_empty() {
                    label_i18n.insert("ja".to_owned(), legacy);
                }
            }

            let mut description_i18n = read_string_map_field(data, "description_i18n");
            if description_i18n.is_empty() {
                let legacy = read_string_field(data, "description");
                if !legacy.is_empty() {
                    description_i18n.insert("ja".to_owned(), legacy);
                }
            }

            let updated_at = read_timestamp_field(data, "updated_at").unwrap_or_else(Utc::now);

            materials.insert(
                doc_id.clone(),
                Material {
                    key: doc_id,
                    label_i18n,
                    description_i18n,
                    photos,
                    price_jpy,
                    is_active,
                    sort_order,
                    version,
                    updated_at,
                },
            );
        }

        Ok(materials)
    }

    async fn load_countries(
        &self,
        client: &FirebaseFirestoreClient,
    ) -> Result<HashMap<String, String>> {
        let query = RunQueryRequest {
            structured_query: Some(json!({
                "from": [{ "collectionId": "countries" }],
                "orderBy": [{
                    "field": { "fieldPath": "sort_order" },
                    "direction": "ASCENDING"
                }]
            })),
            ..RunQueryRequest::default()
        };

        let rows = client
            .run_query(&self.parent, &query)
            .await
            .context("failed to load countries")?;

        let mut countries = HashMap::new();
        for row in rows {
            let Some(document) = row.document else {
                continue;
            };
            let Some(doc_id) = document_id(&document) else {
                continue;
            };

            let label = resolve_localized_field(
                &document.fields,
                "label_i18n",
                "label",
                &self.locale,
                &self.default_locale,
                &doc_id,
            );
            countries.insert(doc_id.to_uppercase(), label);
        }

        Ok(countries)
    }

    async fn upload_material_photo(
        &self,
        material_key: &str,
        file_name: &str,
        content_type: Option<&str>,
        bytes: &[u8],
    ) -> Result<String> {
        let bucket = self.storage_assets_bucket.trim().trim_matches('/');
        if bucket.is_empty() {
            bail!(
                "storage bucket is not configured (set HANKO_ADMIN_STORAGE_ASSETS_BUCKET[_DEV|_PROD] or API_STORAGE_ASSETS_BUCKET)"
            );
        }

        let normalized_content_type = normalize_image_content_type(file_name, content_type)
            .ok_or_else(|| anyhow!("unsupported image type"))?;
        let storage_path = build_storage_path_for_uploaded_photo(
            material_key,
            file_name,
            Some(normalized_content_type),
        );

        let access_token = self
            .token_provider
            .token(&[STORAGE_SCOPE])
            .await
            .context("failed to acquire storage access token")?;

        let response = reqwest::Client::new()
            .post(format!(
                "https://storage.googleapis.com/upload/storage/v1/b/{bucket}/o"
            ))
            .bearer_auth(access_token.as_str())
            .query(&[("uploadType", "media"), ("name", storage_path.as_str())])
            .header(reqwest::header::CONTENT_TYPE, normalized_content_type)
            .body(bytes.to_vec())
            .send()
            .await
            .context("failed to upload photo to cloud storage")?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response
                .text()
                .await
                .unwrap_or_else(|_| "<unable to read response body>".to_owned());
            bail!("storage upload failed status={} body={}", status, body);
        }

        Ok(storage_path)
    }

    async fn persist_order_mutation(&self, order: &Order, events: &[OrderEvent]) -> Result<()> {
        let client = self.firestore_client().await?;

        let order_name = format!("{}/orders/{}", self.parent, order.id);

        let mut fulfillment_fields = btree_from_pairs(vec![
            (
                "status",
                fs_string(order.fulfillment_status.trim().to_owned()),
            ),
            ("carrier", fs_string(order.carrier.trim().to_owned())),
            (
                "tracking_no",
                fs_string(order.tracking_no.trim().to_owned()),
            ),
        ]);

        if order.fulfillment_status == "shipped" {
            fulfillment_fields.insert("shipped_at".to_owned(), fs_timestamp(order.updated_at));
        }
        if order.fulfillment_status == "delivered" {
            fulfillment_fields.insert("delivered_at".to_owned(), fs_timestamp(order.updated_at));
        }

        let document = Document {
            name: Some(order_name.clone()),
            fields: btree_from_pairs(vec![
                ("status", fs_string(order.status.trim().to_owned())),
                ("status_updated_at", fs_timestamp(order.status_updated_at)),
                ("updated_at", fs_timestamp(order.updated_at)),
                (
                    "payment",
                    fs_map(btree_from_pairs(vec![(
                        "status",
                        fs_string(order.payment_status.trim().to_owned()),
                    )])),
                ),
                ("fulfillment", fs_map(fulfillment_fields)),
            ]),
            ..Document::default()
        };

        client
            .patch_document(
                &order_name,
                &document,
                &PatchDocumentOptions {
                    update_mask_field_paths: vec![
                        "status".to_owned(),
                        "status_updated_at".to_owned(),
                        "updated_at".to_owned(),
                        "payment".to_owned(),
                        "fulfillment".to_owned(),
                    ],
                    ..PatchDocumentOptions::default()
                },
            )
            .await
            .context("failed to persist order mutation")?;

        for event in events {
            let event_document = Document {
                fields: encode_order_event(event),
                ..Document::default()
            };

            client
                .create_document(
                    &order_name,
                    "events",
                    &event_document,
                    &CreateDocumentOptions {
                        document_id: Some(format!("evt_{}", Uuid::new_v4().simple())),
                        ..CreateDocumentOptions::default()
                    },
                )
                .await
                .context("failed to persist order event")?;
        }

        Ok(())
    }

    async fn persist_material_mutation(&self, material: &Material) -> Result<()> {
        let client = self.firestore_client().await?;

        let material_name = format!("{}/materials/{}", self.parent, material.key);
        let document = Document {
            name: Some(material_name.clone()),
            fields: btree_from_pairs(vec![
                ("label_i18n", fs_string_map(&material.label_i18n)),
                (
                    "description_i18n",
                    fs_string_map(&material.description_i18n),
                ),
                ("photos", fs_material_photos(&material.photos)),
                ("price_jpy", fs_int(material.price_jpy)),
                ("is_active", fs_bool(material.is_active)),
                ("sort_order", fs_int(material.sort_order)),
                ("version", fs_int(material.version)),
                ("updated_at", fs_timestamp(material.updated_at)),
            ]),
            ..Document::default()
        };

        client
            .patch_document(
                &material_name,
                &document,
                &PatchDocumentOptions {
                    update_mask_field_paths: vec![
                        "label_i18n".to_owned(),
                        "description_i18n".to_owned(),
                        "photos".to_owned(),
                        "price_jpy".to_owned(),
                        "is_active".to_owned(),
                        "sort_order".to_owned(),
                        "version".to_owned(),
                        "updated_at".to_owned(),
                    ],
                    ..PatchDocumentOptions::default()
                },
            )
            .await
            .context("failed to persist material mutation")?;

        Ok(())
    }

    async fn persist_material_deletion(&self, material_key: &str) -> Result<()> {
        let client = self.firestore_client().await?;

        let material_name = format!("{}/materials/{}", self.parent, material_key);
        client
            .delete_document(&material_name, &DeleteDocumentOptions::default())
            .await
            .context("failed to persist material deletion")?;

        Ok(())
    }
}

fn render_orders_list(orders: &[OrderListItemView]) -> Result<String> {
    let template = OrdersListTemplate {
        orders: orders.to_vec(),
        has_orders: !orders.is_empty(),
    };
    render_html(&template)
}

fn render_order_detail(detail: &OrderDetailView) -> Result<String> {
    render_html(&OrderDetailTemplate {
        detail: detail.clone(),
    })
}

fn render_materials_list(materials: &[MaterialListItemView]) -> Result<String> {
    let template = MaterialsListTemplate {
        materials: materials.to_vec(),
        has_materials: !materials.is_empty(),
    };
    render_html(&template)
}

fn render_material_detail(detail: &MaterialDetailView) -> Result<String> {
    render_html(&MaterialDetailTemplate {
        detail: detail.clone(),
    })
}

fn render_material_create(view: &MaterialCreateView) -> Result<String> {
    render_html(&MaterialCreateTemplate { view: view.clone() })
}

fn render_template<T: Template>(template: &T) -> Response {
    match render_html(template) {
        Ok(html) => html_response(StatusCode::OK, html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render template: {error}"),
        ),
    }
}

fn render_html<T: Template>(template: &T) -> Result<String> {
    template
        .render()
        .map_err(|error| anyhow!(error.to_string()))
}

fn html_response(status: StatusCode, body: String) -> Response {
    (
        status,
        [(header::CONTENT_TYPE, "text/html; charset=utf-8")],
        body,
    )
        .into_response()
}

fn html_response_with_trigger(status: StatusCode, body: String, trigger: &str) -> Response {
    let mut response = html_response(status, body);
    if let Ok(value) = HeaderValue::from_str(trigger) {
        response.headers_mut().insert("HX-Trigger", value);
    }
    response
}

fn plain_error(status: StatusCode, message: String) -> Response {
    (status, message).into_response()
}

fn json_response(status: StatusCode, payload: JsonValue) -> Response {
    (
        status,
        [(header::CONTENT_TYPE, "application/json; charset=utf-8")],
        payload.to_string(),
    )
        .into_response()
}

fn json_error(status: StatusCode, message: &str) -> Response {
    json_response(
        status,
        json!({
            "error": message,
        }),
    )
}

fn form_value(form: &HashMap<String, String>, key: &str) -> String {
    form.get(key)
        .map(|value| value.trim().to_owned())
        .unwrap_or_default()
}

fn new_material_create_view(message: &str, render_error: &str) -> MaterialCreateView {
    MaterialCreateView {
        key: String::new(),
        label_ja: String::new(),
        label_en: String::new(),
        description_ja: String::new(),
        description_en: String::new(),
        price_jpy: "0".to_owned(),
        sort_order: "0".to_owned(),
        photo_storage_path: String::new(),
        photo_alt_ja: String::new(),
        photo_alt_en: String::new(),
        is_active: true,
        message: message.to_owned(),
        has_message: !message.is_empty(),
        error: render_error.to_owned(),
        has_error: !render_error.is_empty(),
    }
}

fn material_create_view_from_form(
    form: &HashMap<String, String>,
    message: &str,
    render_error: &str,
) -> MaterialCreateView {
    MaterialCreateView {
        key: form_value(form, "key"),
        label_ja: form_value(form, "label_ja"),
        label_en: form_value(form, "label_en"),
        description_ja: form_value(form, "description_ja"),
        description_en: form_value(form, "description_en"),
        price_jpy: form_value(form, "price_jpy"),
        sort_order: form_value(form, "sort_order"),
        photo_storage_path: form_value(form, "photo_storage_path"),
        photo_alt_ja: form_value(form, "photo_alt_ja"),
        photo_alt_en: form_value(form, "photo_alt_en"),
        is_active: form.contains_key("is_active"),
        message: message.to_owned(),
        has_message: !message.is_empty(),
        error: render_error.to_owned(),
        has_error: !render_error.is_empty(),
    }
}

fn render_material_create_response(status: StatusCode, view: &MaterialCreateView) -> Response {
    match render_material_create(view) {
        Ok(html) => html_response(status, html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render material create: {error}"),
        ),
    }
}

fn render_material_create_response_with_trigger(
    status: StatusCode,
    view: &MaterialCreateView,
    trigger: &str,
) -> Response {
    match render_material_create(view) {
        Ok(html) => html_response_with_trigger(status, html, trigger),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render material create: {error}"),
        ),
    }
}

fn validate_material_key(key: &str) -> std::result::Result<(), String> {
    if key.is_empty() {
        return Err("材質キーは必須です。".to_owned());
    }
    if key.len() > 64 {
        return Err("材質キーは 64 文字以内で入力してください。".to_owned());
    }
    if key.starts_with("__") && key.ends_with("__") {
        return Err("材質キーに `__...__` 形式は利用できません。".to_owned());
    }
    if !key
        .chars()
        .all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || matches!(ch, '-' | '_'))
    {
        return Err(
            "材質キーは英小文字・数字・ハイフン・アンダースコアのみ使用できます。".to_owned(),
        );
    }
    Ok(())
}

fn validate_material_values(
    label_ja: &str,
    label_en: &str,
    description_ja: &str,
    description_en: &str,
    price_jpy: i64,
    sort_order: i64,
    photo_storage_path: &str,
) -> std::result::Result<(), String> {
    if label_ja.is_empty() || label_en.is_empty() {
        return Err("材質名（ja/en）は必須です。".to_owned());
    }
    if description_ja.is_empty() || description_en.is_empty() {
        return Err("説明文（ja/en）は必須です。".to_owned());
    }
    if price_jpy < 0 {
        return Err("価格は 0 以上で入力してください。".to_owned());
    }
    if sort_order < 0 {
        return Err("表示順は 0 以上で入力してください。".to_owned());
    }
    validate_material_photo_storage_path(photo_storage_path)?;
    Ok(())
}

fn normalize_storage_path(value: &str) -> String {
    value.trim().trim_start_matches('/').to_owned()
}

fn normalize_image_content_type(
    file_name: &str,
    content_type: Option<&str>,
) -> Option<&'static str> {
    let normalized_content_type = content_type
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(|value| value.to_ascii_lowercase())
        .and_then(|value| match value.as_str() {
            "image/jpeg" | "image/jpg" => Some("image/jpeg"),
            "image/png" => Some("image/png"),
            "image/webp" => Some("image/webp"),
            "image/gif" => Some("image/gif"),
            "image/avif" => Some("image/avif"),
            _ => None,
        });

    if normalized_content_type.is_some() {
        return normalized_content_type;
    }

    let extension = file_name
        .rsplit_once('.')
        .map(|(_, ext)| ext.trim().to_ascii_lowercase())
        .unwrap_or_default();

    match extension.as_str() {
        "jpg" | "jpeg" => Some("image/jpeg"),
        "png" => Some("image/png"),
        "webp" => Some("image/webp"),
        "gif" => Some("image/gif"),
        "avif" => Some("image/avif"),
        _ => None,
    }
}

fn image_extension_for_content_type(content_type: &str) -> &'static str {
    match content_type {
        "image/jpeg" => "jpg",
        "image/png" => "png",
        "image/gif" => "gif",
        "image/avif" => "avif",
        _ => "webp",
    }
}

fn build_storage_path_for_uploaded_photo(
    material_key: &str,
    file_name: &str,
    content_type: Option<&str>,
) -> String {
    let normalized_content_type =
        normalize_image_content_type(file_name, content_type).unwrap_or("image/webp");
    let extension = image_extension_for_content_type(normalized_content_type);
    let asset_id = format!("mat_{}", Uuid::new_v4().simple());
    format!("materials/{material_key}/{asset_id}.{extension}")
}

fn select_primary_material_photo(photos: &[MaterialPhoto]) -> Option<&MaterialPhoto> {
    photos
        .iter()
        .find(|photo| photo.is_primary)
        .or_else(|| photos.first())
}

fn build_single_material_photos(
    material_key: &str,
    storage_path: &str,
    alt_ja: &str,
    alt_en: &str,
) -> Vec<MaterialPhoto> {
    if storage_path.is_empty() {
        return Vec::new();
    }

    let mut alt_i18n = HashMap::new();
    if !alt_ja.trim().is_empty() {
        alt_i18n.insert("ja".to_owned(), alt_ja.trim().to_owned());
    }
    if !alt_en.trim().is_empty() {
        alt_i18n.insert("en".to_owned(), alt_en.trim().to_owned());
    }

    vec![MaterialPhoto {
        asset_id: format!("mat_{}_01", material_key),
        storage_path: storage_path.to_owned(),
        alt_i18n,
        sort_order: 0,
        is_primary: true,
        width: 0,
        height: 0,
    }]
}

fn merge_primary_material_photo(
    existing: &[MaterialPhoto],
    material_key: &str,
    storage_path: &str,
    alt_ja: &str,
    alt_en: &str,
) -> Vec<MaterialPhoto> {
    if storage_path.is_empty() {
        return existing.to_vec();
    }

    if existing.is_empty() {
        return build_single_material_photos(material_key, storage_path, alt_ja, alt_en);
    }

    let mut photos = existing.to_vec();
    let primary_index = photos
        .iter()
        .position(|photo| photo.is_primary)
        .unwrap_or(0);

    {
        let primary = &mut photos[primary_index];
        primary.storage_path = storage_path.to_owned();

        if alt_ja.trim().is_empty() {
            primary.alt_i18n.remove("ja");
        } else {
            primary
                .alt_i18n
                .insert("ja".to_owned(), alt_ja.trim().to_owned());
        }
        if alt_en.trim().is_empty() {
            primary.alt_i18n.remove("en");
        } else {
            primary
                .alt_i18n
                .insert("en".to_owned(), alt_en.trim().to_owned());
        }

        if primary.asset_id.trim().is_empty() {
            primary.asset_id = format!("mat_{}_01", material_key);
        }
        primary.is_primary = true;
    }

    for (index, photo) in photos.iter_mut().enumerate() {
        if index != primary_index {
            photo.is_primary = false;
        }
    }

    photos
}

fn validate_material_photo_storage_path(storage_path: &str) -> std::result::Result<(), String> {
    if storage_path.is_empty() {
        return Ok(());
    }

    let lowered = storage_path.to_lowercase();
    if lowered.starts_with("http://")
        || lowered.starts_with("https://")
        || lowered.starts_with("gs://")
    {
        return Err(
            "写真は URL ではなく Storage パス（例: materials/titanium/mat_titanium_01.webp）を入力してください。".to_owned(),
        );
    }

    if storage_path.chars().any(|ch| ch.is_whitespace()) {
        return Err("写真パスに空白文字は使用できません。".to_owned());
    }

    Ok(())
}

fn normalize_query_value(value: Option<String>) -> String {
    value
        .map(|value| value.trim().to_owned())
        .unwrap_or_default()
}

fn order_status_label(status: &str) -> &str {
    match status {
        "pending_payment" => "支払い待ち",
        "paid" => "支払い済み",
        "manufacturing" => "製造中",
        "shipped" => "出荷済み",
        "delivered" => "配達完了",
        "canceled" => "キャンセル",
        "refunded" => "返金済み",
        _ => status,
    }
}

fn payment_status_label(status: &str) -> &str {
    match status {
        "unpaid" => "未払い",
        "processing" => "処理中",
        "paid" => "支払い済み",
        "failed" => "失敗",
        "refunded" => "返金済み",
        _ => status,
    }
}

fn fulfillment_status_label(status: &str) -> &str {
    match status {
        "pending" => "未着手",
        "manufacturing" => "製造中",
        "shipped" => "出荷済み",
        "delivered" => "配達完了",
        _ => status,
    }
}

fn status_transitions(current: &str) -> &'static [&'static str] {
    match current {
        "pending_payment" => &["paid", "canceled"],
        "paid" => &["manufacturing", "refunded"],
        "manufacturing" => &["shipped", "refunded"],
        "shipped" => &["delivered", "refunded"],
        "delivered" => &[],
        "canceled" => &[],
        "refunded" => &[],
        _ => &[],
    }
}

fn status_options() -> Vec<StatusOptionView> {
    let mut keys = vec![
        "pending_payment",
        "paid",
        "manufacturing",
        "shipped",
        "delivered",
        "canceled",
        "refunded",
    ];
    keys.sort();
    keys.into_iter()
        .map(|value| StatusOptionView {
            value: value.to_owned(),
            label: order_status_label(value).to_owned(),
        })
        .collect()
}

fn next_status_options(current: &str) -> Vec<StatusOptionView> {
    status_transitions(current)
        .iter()
        .map(|value| StatusOptionView {
            value: (*value).to_owned(),
            label: order_status_label(value).to_owned(),
        })
        .collect()
}

fn shipping_transition_options(current: &str) -> Vec<StatusOptionView> {
    let mut options = vec![StatusOptionView {
        value: "none".to_owned(),
        label: "ステータス変更なし".to_owned(),
    }];

    for next in status_transitions(current) {
        if matches!(*next, "manufacturing" | "shipped" | "delivered") {
            options.push(StatusOptionView {
                value: (*next).to_owned(),
                label: order_status_label(next).to_owned(),
            });
        }
    }

    options
}

fn country_label(countries: &HashMap<String, String>, code: &str) -> String {
    countries
        .get(code)
        .cloned()
        .unwrap_or_else(|| code.to_owned())
}

fn apply_derived_statuses(order: &mut Order) {
    match order.status.as_str() {
        "pending_payment" => {
            order.payment_status = "unpaid".to_owned();
            order.fulfillment_status = "pending".to_owned();
        }
        "paid" => {
            order.payment_status = "paid".to_owned();
            order.fulfillment_status = "pending".to_owned();
        }
        "manufacturing" => {
            order.payment_status = "paid".to_owned();
            order.fulfillment_status = "manufacturing".to_owned();
        }
        "shipped" => {
            order.payment_status = "paid".to_owned();
            order.fulfillment_status = "shipped".to_owned();
        }
        "delivered" => {
            order.payment_status = "paid".to_owned();
            order.fulfillment_status = "delivered".to_owned();
        }
        "canceled" => {
            order.payment_status = "failed".to_owned();
            order.fulfillment_status = "pending".to_owned();
        }
        "refunded" => {
            order.payment_status = "refunded".to_owned();
            if order.fulfillment_status.is_empty() {
                order.fulfillment_status = "pending".to_owned();
            }
        }
        _ => {
            order.payment_status = "processing".to_owned();
            if order.fulfillment_status.is_empty() {
                order.fulfillment_status = "pending".to_owned();
            }
        }
    }
}

fn fill_derived_statuses(order: &mut Order) {
    if !order.payment_status.is_empty() && !order.fulfillment_status.is_empty() {
        return;
    }

    let mut derived = order.clone();
    apply_derived_statuses(&mut derived);

    if order.payment_status.is_empty() {
        order.payment_status = derived.payment_status;
    }
    if order.fulfillment_status.is_empty() {
        order.fulfillment_status = derived.fulfillment_status;
    }
}

fn format_datetime(value: DateTime<Utc>) -> String {
    value
        .with_timezone(&Local)
        .format("%Y-%m-%d %H:%M")
        .to_string()
}

fn format_yen(value: i64) -> String {
    if value == 0 {
        return "0".to_owned();
    }

    let sign = if value < 0 { "-" } else { "" };
    let digits = value.abs().to_string();
    let mut out = String::with_capacity(digits.len() + digits.len() / 3 + 1);

    for (index, ch) in digits.chars().enumerate() {
        if index > 0 && (digits.len() - index) % 3 == 0 {
            out.push(',');
        }
        out.push(ch);
    }

    format!("{sign}{out}")
}

fn resolve_localized_field(
    data: &BTreeMap<String, JsonValue>,
    i18n_field: &str,
    legacy_field: &str,
    locale: &str,
    default_locale: &str,
    fallback: &str,
) -> String {
    let values = read_string_map_field(data, i18n_field);
    let localized = resolve_localized_text(&values, locale, default_locale);
    if !localized.is_empty() {
        return localized;
    }

    if !legacy_field.is_empty() {
        let legacy = read_string_field(data, legacy_field);
        if !legacy.is_empty() {
            return legacy;
        }
    }

    fallback.to_owned()
}

fn resolve_localized_text(
    values: &HashMap<String, String>,
    locale: &str,
    default_locale: &str,
) -> String {
    if values.is_empty() {
        return String::new();
    }

    if let Some(value) = lookup_locale(values, locale) {
        return value;
    }
    if let Some(value) = lookup_locale(values, default_locale) {
        return value;
    }
    if let Some(value) = lookup_locale(values, "ja") {
        return value;
    }

    let mut keys = values
        .iter()
        .filter_map(|(key, value)| {
            if value.trim().is_empty() {
                None
            } else {
                Some(key.clone())
            }
        })
        .collect::<Vec<_>>();
    keys.sort();

    if let Some(key) = keys.first() {
        return values
            .get(key)
            .map(|value| value.trim().to_owned())
            .unwrap_or_default();
    }

    String::new()
}

fn lookup_locale(values: &HashMap<String, String>, target: &str) -> Option<String> {
    let target = target.trim().to_lowercase();
    if target.is_empty() {
        return None;
    }

    for (key, value) in values {
        if key.trim().to_lowercase() == target {
            let trimmed = value.trim();
            if !trimmed.is_empty() {
                return Some(trimmed.to_owned());
            }
        }
    }

    if let Some((base, _)) = target.split_once('-') {
        for (key, value) in values {
            if key.trim().to_lowercase() == base {
                let trimmed = value.trim();
                if !trimmed.is_empty() {
                    return Some(trimmed.to_owned());
                }
            }
        }
    }

    None
}

fn encode_order_event(event: &OrderEvent) -> BTreeMap<String, JsonValue> {
    let mut fields = btree_from_pairs(vec![
        ("type", fs_string(event.kind.clone())),
        ("actor_type", fs_string(event.actor_type.clone())),
        ("created_at", fs_timestamp(event.created_at)),
    ]);

    if !event.actor_id.trim().is_empty() {
        fields.insert("actor_id".to_owned(), fs_string(event.actor_id.clone()));
    }
    if !event.before_status.trim().is_empty() {
        fields.insert(
            "before_status".to_owned(),
            fs_string(event.before_status.clone()),
        );
    }
    if !event.after_status.trim().is_empty() {
        fields.insert(
            "after_status".to_owned(),
            fs_string(event.after_status.clone()),
        );
    }
    if !event.note.trim().is_empty() {
        fields.insert("note".to_owned(), fs_string(event.note.clone()));
    }

    if event.kind == "shipment_registered" {
        let mut payload_fields = BTreeMap::new();
        let parts = event.note.splitn(2, " / ").collect::<Vec<_>>();
        if let Some(carrier) = parts.first() {
            let carrier = carrier.trim();
            if !carrier.is_empty() {
                payload_fields.insert("carrier".to_owned(), fs_string(carrier.to_owned()));
            }
        }
        if let Some(tracking_no) = parts.get(1) {
            let tracking_no = tracking_no.trim();
            if !tracking_no.is_empty() {
                payload_fields.insert("tracking_no".to_owned(), fs_string(tracking_no.to_owned()));
            }
        }

        if !payload_fields.is_empty() {
            fields.insert("payload".to_owned(), fs_map(payload_fields));
        }
    }

    fields
}

fn document_id(document: &Document) -> Option<String> {
    document
        .name
        .as_deref()
        .and_then(|name| name.rsplit('/').next())
        .map(ToOwned::to_owned)
}

fn read_string_field(data: &BTreeMap<String, JsonValue>, key: &str) -> String {
    data.get(key)
        .and_then(|value| {
            value
                .get("stringValue")
                .and_then(JsonValue::as_str)
                .or_else(|| value.as_str())
        })
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
        .unwrap_or_default()
}

fn read_int_field(data: &BTreeMap<String, JsonValue>, key: &str) -> Option<i64> {
    let value = data.get(key)?;

    if let Some(integer_value) = value.get("integerValue") {
        if let Some(text) = integer_value.as_str() {
            if let Ok(parsed) = text.trim().parse::<i64>() {
                return Some(parsed);
            }
        }
        if let Some(parsed) = integer_value.as_i64() {
            return Some(parsed);
        }
        if let Some(parsed) = integer_value
            .as_u64()
            .and_then(|value| i64::try_from(value).ok())
        {
            return Some(parsed);
        }
    }

    if let Some(double_value) = value.get("doubleValue").and_then(JsonValue::as_f64) {
        return Some(double_value as i64);
    }

    value
        .as_i64()
        .or_else(|| value.as_u64().and_then(|value| i64::try_from(value).ok()))
}

fn read_bool_field(data: &BTreeMap<String, JsonValue>, key: &str) -> Option<bool> {
    let value = data.get(key)?;
    if let Some(boolean_value) = value.get("booleanValue").and_then(JsonValue::as_bool) {
        return Some(boolean_value);
    }
    value.as_bool()
}

fn read_timestamp_field(data: &BTreeMap<String, JsonValue>, key: &str) -> Option<DateTime<Utc>> {
    let value = data.get(key)?;

    let raw = value
        .get("timestampValue")
        .and_then(JsonValue::as_str)
        .or_else(|| value.as_str())?;

    DateTime::parse_from_rfc3339(raw)
        .ok()
        .map(|value| value.with_timezone(&Utc))
}

fn read_array_field(data: &BTreeMap<String, JsonValue>, key: &str) -> Vec<JsonValue> {
    let Some(value) = data.get(key) else {
        return Vec::new();
    };

    value
        .get("arrayValue")
        .and_then(|array| array.get("values"))
        .and_then(JsonValue::as_array)
        .cloned()
        .or_else(|| value.as_array().cloned())
        .unwrap_or_default()
}

fn read_material_photos(data: &BTreeMap<String, JsonValue>) -> Vec<MaterialPhoto> {
    let mut photos = read_array_field(data, "photos")
        .into_iter()
        .filter_map(|photo| {
            let fields = photo
                .get("mapValue")
                .and_then(|map| map.get("fields"))
                .and_then(JsonValue::as_object)?;

            let fields = fields
                .iter()
                .map(|(key, value)| (key.clone(), value.clone()))
                .collect::<BTreeMap<_, _>>();

            Some(MaterialPhoto {
                asset_id: read_string_field(&fields, "asset_id"),
                storage_path: normalize_storage_path(&read_string_field(&fields, "storage_path")),
                alt_i18n: read_string_map_field(&fields, "alt_i18n"),
                sort_order: read_int_field(&fields, "sort_order").unwrap_or_default(),
                is_primary: read_bool_field(&fields, "is_primary").unwrap_or(false),
                width: read_int_field(&fields, "width").unwrap_or_default(),
                height: read_int_field(&fields, "height").unwrap_or_default(),
            })
        })
        .filter(|photo| !photo.storage_path.is_empty())
        .collect::<Vec<_>>();

    photos.sort_by(|left, right| {
        let left_primary = if left.is_primary { 0 } else { 1 };
        let right_primary = if right.is_primary { 0 } else { 1 };
        left_primary
            .cmp(&right_primary)
            .then(left.sort_order.cmp(&right.sort_order))
            .then(left.asset_id.cmp(&right.asset_id))
    });

    photos
}

fn read_map_field(data: &BTreeMap<String, JsonValue>, key: &str) -> BTreeMap<String, JsonValue> {
    let Some(value) = data.get(key) else {
        return BTreeMap::new();
    };

    if let Some(fields) = value
        .get("mapValue")
        .and_then(|map_value| map_value.get("fields"))
        .and_then(JsonValue::as_object)
    {
        return fields
            .iter()
            .map(|(map_key, map_value)| (map_key.clone(), map_value.clone()))
            .collect();
    }

    value
        .as_object()
        .map(|fields| {
            fields
                .iter()
                .map(|(map_key, map_value)| (map_key.clone(), map_value.clone()))
                .collect::<BTreeMap<_, _>>()
        })
        .unwrap_or_default()
}

fn read_string_map_field(data: &BTreeMap<String, JsonValue>, key: &str) -> HashMap<String, String> {
    let Some(value) = data.get(key) else {
        return HashMap::new();
    };

    let Some(fields) = value
        .get("mapValue")
        .and_then(|map_value| map_value.get("fields"))
        .and_then(JsonValue::as_object)
        .or_else(|| value.as_object())
    else {
        return HashMap::new();
    };

    let mut result = HashMap::new();
    for (map_key, map_value) in fields {
        let text = map_value
            .get("stringValue")
            .and_then(JsonValue::as_str)
            .or_else(|| map_value.as_str())
            .map(str::trim)
            .filter(|value| !value.is_empty());
        if let Some(text) = text {
            result.insert(map_key.clone(), text.to_owned());
        }
    }

    result
}

fn fs_string(value: impl Into<String>) -> JsonValue {
    json!({ "stringValue": value.into() })
}

fn fs_bool(value: bool) -> JsonValue {
    json!({ "booleanValue": value })
}

fn fs_int(value: i64) -> JsonValue {
    json!({ "integerValue": value.to_string() })
}

fn fs_timestamp(value: DateTime<Utc>) -> JsonValue {
    json!({ "timestampValue": value.to_rfc3339_opts(SecondsFormat::Secs, true) })
}

fn fs_map(fields: BTreeMap<String, JsonValue>) -> JsonValue {
    json!({ "mapValue": { "fields": fields } })
}

fn fs_array(values: Vec<JsonValue>) -> JsonValue {
    json!({ "arrayValue": { "values": values } })
}

fn fs_string_map(values: &HashMap<String, String>) -> JsonValue {
    if values.is_empty() {
        return fs_map(BTreeMap::new());
    }

    let mut keys = values.keys().cloned().collect::<Vec<_>>();
    keys.sort();

    let mut fields = BTreeMap::new();
    for key in keys {
        if let Some(value) = values.get(&key) {
            fields.insert(key, fs_string(value.clone()));
        }
    }

    fs_map(fields)
}

fn fs_material_photos(photos: &[MaterialPhoto]) -> JsonValue {
    let values = photos
        .iter()
        .map(|photo| {
            let mut fields = btree_from_pairs(vec![
                ("asset_id", fs_string(photo.asset_id.clone())),
                ("storage_path", fs_string(photo.storage_path.clone())),
                ("alt_i18n", fs_string_map(&photo.alt_i18n)),
                ("sort_order", fs_int(photo.sort_order)),
                ("is_primary", fs_bool(photo.is_primary)),
            ]);

            if photo.width > 0 {
                fields.insert("width".to_owned(), fs_int(photo.width));
            }
            if photo.height > 0 {
                fields.insert("height".to_owned(), fs_int(photo.height));
            }

            fs_map(fields)
        })
        .collect::<Vec<_>>();

    fs_array(values)
}

fn btree_from_pairs(pairs: Vec<(&str, JsonValue)>) -> BTreeMap<String, JsonValue> {
    pairs
        .into_iter()
        .map(|(key, value)| (key.to_owned(), value))
        .collect::<BTreeMap<_, _>>()
}

fn new_mock_snapshot() -> AdminSnapshot {
    let now = Utc::now();

    let mut orders = HashMap::from([
        (
            "ord_1007".to_owned(),
            Order {
                id: "ord_1007".to_owned(),
                order_no: "HF-20260209-1007".to_owned(),
                channel: "web".to_owned(),
                locale: "ja".to_owned(),
                status: "manufacturing".to_owned(),
                status_updated_at: now - chrono::Duration::hours(4),
                payment_status: String::new(),
                fulfillment_status: String::new(),
                tracking_no: String::new(),
                carrier: String::new(),
                country_code: "JP".to_owned(),
                contact_email: "ito@example.com".to_owned(),
                seal_line1: "伊".to_owned(),
                seal_line2: "藤".to_owned(),
                material_label_ja: "黒水牛".to_owned(),
                total_jpy: 5400,
                created_at: now - chrono::Duration::hours(9),
                updated_at: now - chrono::Duration::hours(4),
                events: vec![
                    OrderEvent {
                        kind: "order_created".to_owned(),
                        actor_type: "system".to_owned(),
                        actor_id: "api".to_owned(),
                        before_status: String::new(),
                        after_status: String::new(),
                        note: "注文を受付".to_owned(),
                        created_at: now - chrono::Duration::hours(9),
                    },
                    OrderEvent {
                        kind: "payment_paid".to_owned(),
                        actor_type: "webhook".to_owned(),
                        actor_id: "stripe".to_owned(),
                        before_status: "pending_payment".to_owned(),
                        after_status: "paid".to_owned(),
                        note: String::new(),
                        created_at: now - chrono::Duration::hours(6),
                    },
                    OrderEvent {
                        kind: "status_changed".to_owned(),
                        actor_type: "admin".to_owned(),
                        actor_id: "admin.console".to_owned(),
                        before_status: "paid".to_owned(),
                        after_status: "manufacturing".to_owned(),
                        note: String::new(),
                        created_at: now - chrono::Duration::hours(4),
                    },
                ],
            },
        ),
        (
            "ord_1006".to_owned(),
            Order {
                id: "ord_1006".to_owned(),
                order_no: "HF-20260209-1006".to_owned(),
                channel: "app".to_owned(),
                locale: "en".to_owned(),
                status: "paid".to_owned(),
                status_updated_at: now - chrono::Duration::hours(2),
                payment_status: String::new(),
                fulfillment_status: String::new(),
                tracking_no: String::new(),
                carrier: String::new(),
                country_code: "US".to_owned(),
                contact_email: "jane.smith@example.com".to_owned(),
                seal_line1: "JA".to_owned(),
                seal_line2: "NE".to_owned(),
                material_label_ja: "チタン".to_owned(),
                total_jpy: 11600,
                created_at: now - chrono::Duration::hours(12),
                updated_at: now - chrono::Duration::hours(2),
                events: vec![
                    OrderEvent {
                        kind: "order_created".to_owned(),
                        actor_type: "system".to_owned(),
                        actor_id: "api".to_owned(),
                        before_status: String::new(),
                        after_status: String::new(),
                        note: "Order accepted".to_owned(),
                        created_at: now - chrono::Duration::hours(12),
                    },
                    OrderEvent {
                        kind: "payment_paid".to_owned(),
                        actor_type: "webhook".to_owned(),
                        actor_id: "stripe".to_owned(),
                        before_status: "pending_payment".to_owned(),
                        after_status: "paid".to_owned(),
                        note: String::new(),
                        created_at: now - chrono::Duration::hours(2),
                    },
                ],
            },
        ),
        (
            "ord_1005".to_owned(),
            Order {
                id: "ord_1005".to_owned(),
                order_no: "HF-20260209-1005".to_owned(),
                channel: "web".to_owned(),
                locale: "ja".to_owned(),
                status: "shipped".to_owned(),
                status_updated_at: now - chrono::Duration::hours(26),
                payment_status: String::new(),
                fulfillment_status: String::new(),
                tracking_no: "SGP-824901".to_owned(),
                carrier: "DHL".to_owned(),
                country_code: "SG".to_owned(),
                contact_email: "tanaka@example.com".to_owned(),
                seal_line1: "田".to_owned(),
                seal_line2: "中".to_owned(),
                material_label_ja: "柘植".to_owned(),
                total_jpy: 4900,
                created_at: now - chrono::Duration::hours(36),
                updated_at: now - chrono::Duration::hours(26),
                events: vec![
                    OrderEvent {
                        kind: "order_created".to_owned(),
                        actor_type: "system".to_owned(),
                        actor_id: "api".to_owned(),
                        before_status: String::new(),
                        after_status: String::new(),
                        note: "注文を受付".to_owned(),
                        created_at: now - chrono::Duration::hours(36),
                    },
                    OrderEvent {
                        kind: "payment_paid".to_owned(),
                        actor_type: "webhook".to_owned(),
                        actor_id: "stripe".to_owned(),
                        before_status: "pending_payment".to_owned(),
                        after_status: "paid".to_owned(),
                        note: String::new(),
                        created_at: now - chrono::Duration::hours(31),
                    },
                    OrderEvent {
                        kind: "status_changed".to_owned(),
                        actor_type: "admin".to_owned(),
                        actor_id: "admin.console".to_owned(),
                        before_status: "paid".to_owned(),
                        after_status: "manufacturing".to_owned(),
                        note: String::new(),
                        created_at: now - chrono::Duration::hours(29),
                    },
                    OrderEvent {
                        kind: "shipment_registered".to_owned(),
                        actor_type: "admin".to_owned(),
                        actor_id: "admin.console".to_owned(),
                        before_status: String::new(),
                        after_status: String::new(),
                        note: "DHL / SGP-824901".to_owned(),
                        created_at: now - chrono::Duration::hours(26),
                    },
                    OrderEvent {
                        kind: "status_changed".to_owned(),
                        actor_type: "admin".to_owned(),
                        actor_id: "admin.console".to_owned(),
                        before_status: "manufacturing".to_owned(),
                        after_status: "shipped".to_owned(),
                        note: String::new(),
                        created_at: now - chrono::Duration::hours(26),
                    },
                ],
            },
        ),
        (
            "ord_1004".to_owned(),
            Order {
                id: "ord_1004".to_owned(),
                order_no: "HF-20260208-1004".to_owned(),
                channel: "app".to_owned(),
                locale: "ja".to_owned(),
                status: "delivered".to_owned(),
                status_updated_at: now - chrono::Duration::hours(72),
                payment_status: String::new(),
                fulfillment_status: String::new(),
                tracking_no: "YMT-99120".to_owned(),
                carrier: "ヤマト運輸".to_owned(),
                country_code: "JP".to_owned(),
                contact_email: "kato@example.com".to_owned(),
                seal_line1: "加".to_owned(),
                seal_line2: "藤".to_owned(),
                material_label_ja: "柘植".to_owned(),
                total_jpy: 4200,
                created_at: now - chrono::Duration::hours(96),
                updated_at: now - chrono::Duration::hours(72),
                events: vec![
                    OrderEvent {
                        kind: "order_created".to_owned(),
                        actor_type: "system".to_owned(),
                        actor_id: "api".to_owned(),
                        before_status: String::new(),
                        after_status: String::new(),
                        note: "注文を受付".to_owned(),
                        created_at: now - chrono::Duration::hours(96),
                    },
                    OrderEvent {
                        kind: "status_changed".to_owned(),
                        actor_type: "admin".to_owned(),
                        actor_id: "admin.console".to_owned(),
                        before_status: "shipped".to_owned(),
                        after_status: "delivered".to_owned(),
                        note: String::new(),
                        created_at: now - chrono::Duration::hours(72),
                    },
                ],
            },
        ),
        (
            "ord_1003".to_owned(),
            Order {
                id: "ord_1003".to_owned(),
                order_no: "HF-20260208-1003".to_owned(),
                channel: "web".to_owned(),
                locale: "en".to_owned(),
                status: "pending_payment".to_owned(),
                status_updated_at: now - chrono::Duration::hours(8),
                payment_status: String::new(),
                fulfillment_status: String::new(),
                tracking_no: String::new(),
                carrier: String::new(),
                country_code: "CA".to_owned(),
                contact_email: "chris@example.com".to_owned(),
                seal_line1: "CH".to_owned(),
                seal_line2: "RI".to_owned(),
                material_label_ja: "チタン".to_owned(),
                total_jpy: 11800,
                created_at: now - chrono::Duration::hours(30),
                updated_at: now - chrono::Duration::hours(8),
                events: vec![OrderEvent {
                    kind: "order_created".to_owned(),
                    actor_type: "system".to_owned(),
                    actor_id: "api".to_owned(),
                    before_status: String::new(),
                    after_status: String::new(),
                    note: "Order accepted".to_owned(),
                    created_at: now - chrono::Duration::hours(30),
                }],
            },
        ),
        (
            "ord_1002".to_owned(),
            Order {
                id: "ord_1002".to_owned(),
                order_no: "HF-20260207-1002".to_owned(),
                channel: "app".to_owned(),
                locale: "ja".to_owned(),
                status: "refunded".to_owned(),
                status_updated_at: now - chrono::Duration::hours(130),
                payment_status: String::new(),
                fulfillment_status: String::new(),
                tracking_no: "GB-12400".to_owned(),
                carrier: "Royal Mail".to_owned(),
                country_code: "GB".to_owned(),
                contact_email: "suzuki@example.com".to_owned(),
                seal_line1: "鈴".to_owned(),
                seal_line2: "木".to_owned(),
                material_label_ja: "黒水牛".to_owned(),
                total_jpy: 6900,
                created_at: now - chrono::Duration::hours(150),
                updated_at: now - chrono::Duration::hours(130),
                events: vec![
                    OrderEvent {
                        kind: "order_created".to_owned(),
                        actor_type: "system".to_owned(),
                        actor_id: "api".to_owned(),
                        before_status: String::new(),
                        after_status: String::new(),
                        note: "注文を受付".to_owned(),
                        created_at: now - chrono::Duration::hours(150),
                    },
                    OrderEvent {
                        kind: "status_changed".to_owned(),
                        actor_type: "admin".to_owned(),
                        actor_id: "admin.console".to_owned(),
                        before_status: "shipped".to_owned(),
                        after_status: "refunded".to_owned(),
                        note: String::new(),
                        created_at: now - chrono::Duration::hours(130),
                    },
                ],
            },
        ),
        (
            "ord_1001".to_owned(),
            Order {
                id: "ord_1001".to_owned(),
                order_no: "HF-20260207-1001".to_owned(),
                channel: "web".to_owned(),
                locale: "ja".to_owned(),
                status: "canceled".to_owned(),
                status_updated_at: now - chrono::Duration::hours(80),
                payment_status: String::new(),
                fulfillment_status: String::new(),
                tracking_no: String::new(),
                carrier: String::new(),
                country_code: "AU".to_owned(),
                contact_email: "yamada@example.com".to_owned(),
                seal_line1: "山".to_owned(),
                seal_line2: "田".to_owned(),
                material_label_ja: "柘植".to_owned(),
                total_jpy: 5600,
                created_at: now - chrono::Duration::hours(120),
                updated_at: now - chrono::Duration::hours(80),
                events: vec![
                    OrderEvent {
                        kind: "order_created".to_owned(),
                        actor_type: "system".to_owned(),
                        actor_id: "api".to_owned(),
                        before_status: String::new(),
                        after_status: String::new(),
                        note: "注文を受付".to_owned(),
                        created_at: now - chrono::Duration::hours(120),
                    },
                    OrderEvent {
                        kind: "status_changed".to_owned(),
                        actor_type: "system".to_owned(),
                        actor_id: "scheduler".to_owned(),
                        before_status: "pending_payment".to_owned(),
                        after_status: "canceled".to_owned(),
                        note: String::new(),
                        created_at: now - chrono::Duration::hours(80),
                    },
                ],
            },
        ),
    ]);

    for order in orders.values_mut() {
        apply_derived_statuses(order);
    }

    let materials = HashMap::from([
        (
            "boxwood".to_owned(),
            Material {
                key: "boxwood".to_owned(),
                label_i18n: HashMap::from([
                    ("ja".to_owned(), "柘植".to_owned()),
                    ("en".to_owned(), "Boxwood".to_owned()),
                ]),
                description_i18n: HashMap::from([
                    ("ja".to_owned(), "軽くて扱いやすい定番材".to_owned()),
                    (
                        "en".to_owned(),
                        "A standard wood that is lightweight and easy to handle.".to_owned(),
                    ),
                ]),
                photos: vec![MaterialPhoto {
                    asset_id: "mat_boxwood_01".to_owned(),
                    storage_path: "materials/boxwood/mat_boxwood_01.webp".to_owned(),
                    alt_i18n: HashMap::from([
                        ("ja".to_owned(), "柘植の材質サンプル".to_owned()),
                        ("en".to_owned(), "Boxwood material sample".to_owned()),
                    ]),
                    sort_order: 0,
                    is_primary: true,
                    width: 1200,
                    height: 1200,
                }],
                price_jpy: 3600,
                is_active: true,
                sort_order: 10,
                version: 3,
                updated_at: now - chrono::Duration::hours(36),
            },
        ),
        (
            "black_buffalo".to_owned(),
            Material {
                key: "black_buffalo".to_owned(),
                label_i18n: HashMap::from([
                    ("ja".to_owned(), "黒水牛".to_owned()),
                    ("en".to_owned(), "Black Buffalo".to_owned()),
                ]),
                description_i18n: HashMap::from([
                    ("ja".to_owned(), "しっとりした質感で耐久性が高い".to_owned()),
                    (
                        "en".to_owned(),
                        "Durable material with a smooth texture.".to_owned(),
                    ),
                ]),
                photos: vec![MaterialPhoto {
                    asset_id: "mat_black_buffalo_01".to_owned(),
                    storage_path: "materials/black_buffalo/mat_black_buffalo_01.webp".to_owned(),
                    alt_i18n: HashMap::from([
                        ("ja".to_owned(), "黒水牛の材質サンプル".to_owned()),
                        ("en".to_owned(), "Black buffalo material sample".to_owned()),
                    ]),
                    sort_order: 0,
                    is_primary: true,
                    width: 1200,
                    height: 1200,
                }],
                price_jpy: 4800,
                is_active: true,
                sort_order: 20,
                version: 5,
                updated_at: now - chrono::Duration::hours(24),
            },
        ),
        (
            "titanium".to_owned(),
            Material {
                key: "titanium".to_owned(),
                label_i18n: HashMap::from([
                    ("ja".to_owned(), "チタン".to_owned()),
                    ("en".to_owned(), "Titanium".to_owned()),
                ]),
                description_i18n: HashMap::from([
                    ("ja".to_owned(), "重厚で摩耗に強いプレミアム材".to_owned()),
                    (
                        "en".to_owned(),
                        "Premium material with excellent wear resistance.".to_owned(),
                    ),
                ]),
                photos: vec![MaterialPhoto {
                    asset_id: "mat_titanium_01".to_owned(),
                    storage_path: "materials/titanium/mat_titanium_01.webp".to_owned(),
                    alt_i18n: HashMap::from([
                        ("ja".to_owned(), "チタンの材質サンプル".to_owned()),
                        ("en".to_owned(), "Titanium material sample".to_owned()),
                    ]),
                    sort_order: 0,
                    is_primary: true,
                    width: 1200,
                    height: 1200,
                }],
                price_jpy: 9800,
                is_active: false,
                sort_order: 30,
                version: 2,
                updated_at: now - chrono::Duration::hours(12),
            },
        ),
    ]);

    let countries = HashMap::from([
        ("JP".to_owned(), "日本".to_owned()),
        ("US".to_owned(), "United States".to_owned()),
        ("CA".to_owned(), "Canada".to_owned()),
        ("GB".to_owned(), "United Kingdom".to_owned()),
        ("AU".to_owned(), "Australia".to_owned()),
        ("SG".to_owned(), "Singapore".to_owned()),
    ]);

    let mut snapshot = AdminSnapshot {
        orders,
        order_ids: Vec::new(),
        materials,
        material_ids: Vec::new(),
        countries,
    };
    snapshot.refresh_order_ids();
    snapshot.refresh_material_ids();
    snapshot
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mock_server_state() -> ServerState {
        ServerState {
            source_label: "Mock".to_owned(),
            source: DataSource::Mock,
            data: RwLock::new(new_mock_snapshot()),
        }
    }

    #[tokio::test]
    async fn filter_orders_by_status() {
        let state = mock_server_state();
        let orders = state
            .filter_orders(&OrderFilter {
                status: "paid".to_owned(),
                country: String::new(),
                email: String::new(),
            })
            .await;

        assert!(!orders.is_empty());
    }

    #[tokio::test]
    async fn update_order_status_valid_transition() {
        let state = mock_server_state();

        let result = state
            .update_order_status("ord_1006", "manufacturing", "test.admin")
            .await;
        assert!(result.is_ok());

        let detail = state
            .get_order_detail("ord_1006", "", "")
            .await
            .expect("order should exist");
        assert_eq!(detail.status_label, "製造中");
        assert_eq!(detail.payment_status_label, "支払い済み");
        assert_eq!(detail.fulfillment_status_label, "製造中");
    }

    #[tokio::test]
    async fn update_shipping_invalid_transition_does_not_mutate() {
        let state = mock_server_state();

        let before = state
            .get_order_detail("ord_1007", "", "")
            .await
            .expect("order should exist");

        let result = state
            .update_shipping("ord_1007", "DHL", "DHL-999", "delivered", "test.admin")
            .await;
        assert!(result.is_err());

        let after = state
            .get_order_detail("ord_1007", "", "")
            .await
            .expect("order should exist");

        assert_eq!(before.carrier, after.carrier);
        assert_eq!(before.tracking_no, after.tracking_no);
    }

    #[test]
    fn format_yen_with_separator() {
        assert_eq!(format_yen(0), "0");
        assert_eq!(format_yen(1200), "1,200");
        assert_eq!(format_yen(1234567), "1,234,567");
    }
}
