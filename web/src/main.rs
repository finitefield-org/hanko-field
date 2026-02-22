use std::{
    collections::{BTreeMap, HashMap, HashSet},
    env,
    sync::Arc,
    time::Duration,
};

use anyhow::{Context, Result, anyhow, bail};
use askama::Template;
use axum::{
    Router,
    extract::{Form, State, rejection::FormRejection},
    http::{HeaderName, HeaderValue, StatusCode, header},
    response::{IntoResponse, Response},
    routing::{get, post},
};
use firebase_sdk_rust::firebase_firestore::{Document, FirebaseFirestoreClient, RunQueryRequest};
use gcp_auth::{CustomServiceAccount, TokenProvider, provider};
use serde::{Deserialize, Serialize, de::DeserializeOwned};
use serde_json::{Value as JsonValue, json};
use tower_http::services::ServeDir;
use uuid::Uuid;

const DATASTORE_SCOPE: &str = "https://www.googleapis.com/auth/datastore";
const DEFAULT_KANJI_CANDIDATE_COUNT: usize = 6;
const HX_REDIRECT_HEADER: &str = "hx-redirect";

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
    port: String,
    mode: RunMode,
    locale: String,
    default_locale: String,
    api_base_url: String,
    firestore_project_id: Option<String>,
    credentials_file: Option<String>,
    storage_assets_bucket: Option<String>,
}

#[derive(Debug, Clone)]
struct FontOption {
    key: String,
    label: String,
    family: String,
    stylesheet_url: String,
    kanji_style: String,
}

#[derive(Debug, Clone)]
struct MaterialOption {
    key: String,
    label: String,
    description: String,
    shape: String,
    shape_label: String,
    price: i64,
    price_display: String,
    photo_url: String,
    photo_alt: String,
    has_photo: bool,
}

#[derive(Debug, Clone)]
struct CountryOption {
    code: String,
    label: String,
    shipping: i64,
}

#[derive(Debug, Clone)]
struct CatalogData {
    fonts: Vec<FontOption>,
    materials: Vec<MaterialOption>,
    countries: Vec<CountryOption>,
}

#[derive(Debug, Clone)]
struct KanjiCandidate {
    kanji: String,
    line1: String,
    line2: String,
    reading_hiragana: String,
    reading_romaji: String,
    reason: String,
}

#[derive(Debug, Clone, Default)]
struct PurchaseResultData {
    error: String,
    seal_line1: String,
    seal_line2: String,
    font_label: String,
    shape_label: String,
    material_label: String,
    stripe_name: String,
    stripe_phone: String,
    country_label: String,
    postal_code: String,
    state: String,
    city: String,
    address_line1: String,
    address_line2: String,
    subtotal: i64,
    shipping: i64,
    total: i64,
    email: String,
    source_label: String,
    is_mock: bool,
}

#[derive(Template)]
#[template(path = "index.html")]
struct PageTemplate {
    fonts: Vec<FontOption>,
    font_stylesheet_urls: Vec<String>,
    materials: Vec<MaterialOption>,
    countries: Vec<CountryOption>,
    is_mock: bool,
    default_font_key: String,
    default_font_label: String,
}

#[derive(Template)]
#[template(path = "kanji_suggestions.html")]
struct KanjiSuggestionsTemplate {
    real_name: String,
    suggestions: Vec<KanjiCandidate>,
    has_suggestions: bool,
    error: String,
}

#[derive(Debug, Deserialize)]
struct KanjiCandidatesApiResponse {
    candidates: Vec<KanjiCandidatesApiItem>,
}

#[derive(Debug, Deserialize)]
struct KanjiCandidatesApiItem {
    kanji: String,
    reading_hiragana: String,
    reading_romaji: String,
    reason: String,
}

#[derive(Debug, Serialize)]
struct CreateOrderApiRequest {
    channel: String,
    locale: String,
    idempotency_key: String,
    terms_agreed: bool,
    seal: CreateOrderSealApiRequest,
    material_key: String,
    shipping: CreateOrderShippingApiRequest,
    contact: CreateOrderContactApiRequest,
}

#[derive(Debug, Serialize)]
struct CreateOrderSealApiRequest {
    line1: String,
    line2: String,
    shape: String,
    font_key: String,
}

#[derive(Debug, Serialize)]
struct CreateOrderShippingApiRequest {
    country_code: String,
    recipient_name: String,
    phone: String,
    postal_code: String,
    state: String,
    city: String,
    address_line1: String,
    address_line2: String,
}

#[derive(Debug, Serialize)]
struct CreateOrderContactApiRequest {
    email: String,
    preferred_locale: String,
}

#[derive(Debug, Deserialize)]
struct CreateOrderApiResponse {
    order_id: String,
}

#[derive(Debug, Serialize)]
struct CreateStripeCheckoutSessionApiRequest {
    order_id: String,
    customer_email: String,
}

#[derive(Debug, Deserialize)]
struct CreateStripeCheckoutSessionApiResponse {
    checkout_url: String,
}

#[derive(Debug, Deserialize)]
struct ApiErrorEnvelope {
    error: ApiErrorBody,
}

#[derive(Debug, Deserialize)]
struct ApiErrorBody {
    code: String,
    message: String,
}

#[derive(Template)]
#[template(path = "purchase_result.html")]
struct PurchaseResultTemplate {
    has_error: bool,
    error: String,
    seal_line1: String,
    seal_line2: String,
    has_seal_line2: bool,
    font_label: String,
    shape_label: String,
    material_label: String,
    stripe_name: String,
    stripe_phone: String,
    country_label: String,
    postal_code: String,
    state: String,
    city: String,
    address_line1: String,
    address_line2: String,
    has_address_line2: bool,
    subtotal_display: String,
    shipping_display: String,
    total_display: String,
    email: String,
    source_label: String,
    is_mock: bool,
}

#[derive(Clone)]
enum CatalogSource {
    Mock(MockCatalogSource),
    Firestore(FirestoreCatalogSource),
}

impl CatalogSource {
    fn label(&self) -> &str {
        match self {
            Self::Mock(_) => "Mock",
            Self::Firestore(source) => &source.label,
        }
    }

    fn is_mock(&self) -> bool {
        matches!(self, Self::Mock(_))
    }

    async fn load_catalog(&self) -> Result<CatalogData> {
        match self {
            Self::Mock(source) => Ok(source.catalog.clone()),
            Self::Firestore(source) => source.load_catalog().await,
        }
    }
}

#[derive(Debug, Clone)]
struct MockCatalogSource {
    catalog: CatalogData,
}

#[derive(Clone)]
struct FirestoreCatalogSource {
    project_id: String,
    locale: String,
    default_locale: String,
    label: String,
    storage_assets_bucket: String,
    token_provider: Arc<dyn TokenProvider>,
}

impl FirestoreCatalogSource {
    async fn load_catalog(&self) -> Result<CatalogData> {
        let access_token = self
            .token_provider
            .token(&[DATASTORE_SCOPE])
            .await
            .context("failed to acquire firestore access token")?;

        let client = FirebaseFirestoreClient::new(access_token.as_str().to_owned());
        let parent = format!("projects/{}/databases/(default)/documents", self.project_id);

        let fonts = self.load_fonts(&client, &parent).await?;
        let materials = self.load_materials(&client, &parent).await?;
        let countries = self.load_countries(&client, &parent).await?;

        Ok(CatalogData {
            fonts,
            materials,
            countries,
        })
    }

    async fn load_fonts(
        &self,
        client: &FirebaseFirestoreClient,
        parent: &str,
    ) -> Result<Vec<FontOption>> {
        let documents = self.query_active_documents(client, parent, "fonts").await?;

        let mut fonts = Vec::with_capacity(documents.len());
        for document in documents {
            let doc_id =
                document_id(&document).ok_or_else(|| anyhow!("fonts document is missing name"))?;
            let mut family = read_string_field(&document.fields, "font_family");
            if family.is_empty() {
                family = read_string_field(&document.fields, "family");
            }
            if family.is_empty() {
                bail!("fonts/{doc_id} is missing font_family");
            }
            let mut stylesheet_url = read_string_field(&document.fields, "font_stylesheet_url");
            if stylesheet_url.is_empty() {
                stylesheet_url = read_string_field(&document.fields, "font_url");
            }
            if stylesheet_url.is_empty() {
                bail!("fonts/{doc_id} is missing font_stylesheet_url");
            }

            let label = resolve_localized_field(
                &document.fields,
                "label_i18n",
                "label",
                &self.locale,
                &self.default_locale,
                &doc_id,
            );
            let mut kanji_style = read_string_field(&document.fields, "kanji_style");
            if kanji_style.is_empty() {
                kanji_style = read_string_field(&document.fields, "style");
            }
            let kanji_style = normalize_kanji_style(&kanji_style).to_owned();

            fonts.push(FontOption {
                key: doc_id,
                label,
                family,
                stylesheet_url,
                kanji_style,
            });
        }

        if fonts.is_empty() {
            bail!("no active fonts found in firestore");
        }

        Ok(fonts)
    }

    async fn load_materials(
        &self,
        client: &FirebaseFirestoreClient,
        parent: &str,
    ) -> Result<Vec<MaterialOption>> {
        let documents = self
            .query_active_documents(client, parent, "materials")
            .await?;

        let mut materials = Vec::with_capacity(documents.len());
        for document in documents {
            let doc_id = document_id(&document)
                .ok_or_else(|| anyhow!("materials document is missing name"))?;

            let price = read_int_field(&document.fields, "price_jpy")
                .or_else(|| read_int_field(&document.fields, "price"))
                .ok_or_else(|| anyhow!("materials/{doc_id} is missing price_jpy"))?;

            let label = resolve_localized_field(
                &document.fields,
                "label_i18n",
                "label",
                &self.locale,
                &self.default_locale,
                &doc_id,
            );
            let description = resolve_localized_field(
                &document.fields,
                "description_i18n",
                "description",
                &self.locale,
                &self.default_locale,
                "",
            );
            let shape = normalize_material_shape(&read_string_field(&document.fields, "shape"));
            let (photo_url, photo_alt, has_photo) = resolve_material_photo(
                &document.fields,
                &self.storage_assets_bucket,
                &self.locale,
                &self.default_locale,
            );
            let photo_alt = if has_photo && photo_alt.is_empty() {
                format!("{label}の写真")
            } else {
                photo_alt
            };

            materials.push(MaterialOption {
                key: doc_id,
                label,
                description,
                shape: shape.to_owned(),
                shape_label: material_shape_label(shape).to_owned(),
                price,
                price_display: format_yen(price),
                photo_url,
                photo_alt,
                has_photo,
            });
        }

        if materials.is_empty() {
            bail!("no active materials found in firestore");
        }

        Ok(materials)
    }

    async fn load_countries(
        &self,
        client: &FirebaseFirestoreClient,
        parent: &str,
    ) -> Result<Vec<CountryOption>> {
        let documents = self
            .query_active_documents(client, parent, "countries")
            .await?;

        let mut countries = Vec::with_capacity(documents.len());
        for document in documents {
            let doc_id = document_id(&document)
                .ok_or_else(|| anyhow!("countries document is missing name"))?;

            let shipping = read_int_field(&document.fields, "shipping_fee_jpy")
                .or_else(|| read_int_field(&document.fields, "shipping"))
                .ok_or_else(|| anyhow!("countries/{doc_id} is missing shipping_fee_jpy"))?;

            let label = resolve_localized_field(
                &document.fields,
                "label_i18n",
                "label",
                &self.locale,
                &self.default_locale,
                &doc_id,
            );

            countries.push(CountryOption {
                code: doc_id,
                label,
                shipping,
            });
        }

        if countries.is_empty() {
            bail!("no active countries found in firestore");
        }

        Ok(countries)
    }

    async fn query_active_documents(
        &self,
        client: &FirebaseFirestoreClient,
        parent: &str,
        collection: &str,
    ) -> Result<Vec<Document>> {
        let query = RunQueryRequest {
            structured_query: Some(json!({
                "from": [
                    { "collectionId": collection }
                ],
                "where": {
                    "fieldFilter": {
                        "field": { "fieldPath": "is_active" },
                        "op": "EQUAL",
                        "value": { "booleanValue": true }
                    }
                },
                "orderBy": [
                    {
                        "field": { "fieldPath": "sort_order" },
                        "direction": "ASCENDING"
                    }
                ]
            })),
            ..RunQueryRequest::default()
        };

        let rows = client
            .run_query(parent, &query)
            .await
            .with_context(|| format!("failed to load {collection}"))?;

        let documents = rows
            .into_iter()
            .filter_map(|row| row.document)
            .collect::<Vec<_>>();

        if documents.is_empty() {
            bail!("no active {collection} found in firestore");
        }

        Ok(documents)
    }
}

#[derive(Clone)]
struct KanjiApiClient {
    base_url: String,
    http_client: reqwest::Client,
}

impl KanjiApiClient {
    async fn generate_candidates(
        &self,
        real_name: &str,
        reason_language: &str,
        gender: &str,
        kanji_style: &str,
    ) -> Result<Vec<KanjiCandidate>> {
        let endpoint = format!(
            "{}/v1/kanji-candidates",
            self.base_url.trim_end_matches('/')
        );

        let response = self
            .http_client
            .post(endpoint)
            .json(&json!({
                "real_name": real_name,
                "reason_language": reason_language,
                "gender": gender,
                "kanji_style": kanji_style,
                "count": DEFAULT_KANJI_CANDIDATE_COUNT,
            }))
            .send()
            .await
            .context("failed to request kanji candidates")?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response
                .text()
                .await
                .unwrap_or_else(|_| "<unable to read response body>".to_owned());
            bail!("kanji candidate API failed status={} body={}", status, body);
        }

        let payload = response
            .json::<KanjiCandidatesApiResponse>()
            .await
            .context("failed to decode kanji candidates response")?;

        let suggestions = payload
            .candidates
            .into_iter()
            .filter_map(|item| {
                let kanji = item.kanji.trim().to_owned();
                if kanji.is_empty()
                    || kanji.chars().count() > 2
                    || kanji.chars().any(char::is_whitespace)
                {
                    return None;
                }

                let reading_hiragana = item.reading_hiragana.trim().to_owned();
                let reading_romaji = item.reading_romaji.trim().to_owned();
                let reason = item.reason.trim().to_owned();
                if reading_hiragana.is_empty() || reading_romaji.is_empty() || reason.is_empty() {
                    return None;
                }

                Some(KanjiCandidate {
                    kanji: kanji.clone(),
                    line1: kanji,
                    line2: String::new(),
                    reading_hiragana,
                    reading_romaji,
                    reason,
                })
            })
            .collect::<Vec<_>>();

        Ok(suggestions)
    }

    async fn create_order(
        &self,
        request: &CreateOrderApiRequest,
    ) -> Result<CreateOrderApiResponse> {
        let endpoint = format!("{}/v1/orders", self.base_url.trim_end_matches('/'));
        let response = self
            .http_client
            .post(endpoint)
            .json(request)
            .send()
            .await
            .context("failed to request order creation")?;

        decode_api_response(response, "create order")
            .await
            .context("failed to decode create order response")
    }

    async fn create_stripe_checkout_session(
        &self,
        request: &CreateStripeCheckoutSessionApiRequest,
    ) -> Result<CreateStripeCheckoutSessionApiResponse> {
        let endpoint = format!(
            "{}/v1/payments/stripe/checkout-session",
            self.base_url.trim_end_matches('/')
        );
        let response = self
            .http_client
            .post(endpoint)
            .json(request)
            .send()
            .await
            .context("failed to request stripe checkout session")?;

        decode_api_response(response, "create stripe checkout session")
            .await
            .context("failed to decode stripe checkout session response")
    }
}

async fn decode_api_response<T: DeserializeOwned>(
    response: reqwest::Response,
    op: &str,
) -> Result<T> {
    let status = response.status();
    let body = response
        .bytes()
        .await
        .with_context(|| format!("failed to read response body for {op}"))?;

    if !status.is_success() {
        if let Ok(err) = serde_json::from_slice::<ApiErrorEnvelope>(&body) {
            bail!(
                "{} failed status={} code={} message={}",
                op,
                status,
                err.error.code,
                err.error.message
            );
        }

        let text = String::from_utf8_lossy(&body);
        bail!("{op} failed status={} body={}", status, text);
    }

    serde_json::from_slice::<T>(&body).with_context(|| format!("invalid JSON for {op}"))
}

#[derive(Clone)]
struct AppState {
    source: Arc<CatalogSource>,
    kanji_api: Arc<KanjiApiClient>,
    locale: String,
}

#[tokio::main]
async fn main() {
    if let Err(error) = run().await {
        eprintln!("failed to start web server: {error:#}");
        std::process::exit(1);
    }
}

async fn run() -> Result<()> {
    let cfg = load_config().context("failed to load config")?;
    let state = build_state(&cfg).await?;

    let app = Router::new()
        .route("/", get(handle_index))
        .route("/kanji", post(handle_kanji_suggestions))
        .route("/purchase", post(handle_purchase))
        .route("/mock/kanji", post(handle_kanji_suggestions))
        .route("/mock/purchase", post(handle_purchase))
        .nest_service("/static", ServeDir::new("static"))
        .with_state(state.clone());

    let addr = format!("0.0.0.0:{}", cfg.port);
    if let Some(project_id) = cfg.firestore_project_id.as_deref() {
        println!(
            "hanko web listening on http://localhost:{} mode={} source={} project={} locale={} kanji_api={}",
            cfg.port,
            cfg.mode.as_str(),
            state.source.label(),
            project_id,
            cfg.locale,
            cfg.api_base_url
        );
    } else {
        println!(
            "hanko web listening on http://localhost:{} mode={} source={} locale={} kanji_api={}",
            cfg.port,
            cfg.mode.as_str(),
            state.source.label(),
            cfg.locale,
            cfg.api_base_url
        );
    }

    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .with_context(|| format!("failed to bind {addr}"))?;

    axum::serve(listener, app)
        .await
        .context("web server terminated unexpectedly")
}

async fn build_state(cfg: &AppConfig) -> Result<AppState> {
    let source = Arc::new(new_catalog_source(cfg).await?);
    let kanji_http_client = reqwest::Client::builder()
        .timeout(Duration::from_secs(20))
        .build()
        .context("failed to initialize kanji API client")?;
    let kanji_api = Arc::new(KanjiApiClient {
        base_url: cfg.api_base_url.clone(),
        http_client: kanji_http_client,
    });

    let _catalog = load_catalog_with_timeout(source.as_ref()).await?;

    Ok(AppState {
        source,
        kanji_api,
        locale: cfg.locale.clone(),
    })
}

fn load_config() -> Result<AppConfig> {
    let mut cfg = AppConfig {
        port: env::var("HANKO_WEB_PORT")
            .unwrap_or_default()
            .trim()
            .to_owned(),
        mode: RunMode::Mock,
        locale: env::var("HANKO_WEB_LOCALE")
            .unwrap_or_default()
            .trim()
            .to_owned(),
        default_locale: env::var("HANKO_WEB_DEFAULT_LOCALE")
            .unwrap_or_default()
            .trim()
            .to_owned(),
        api_base_url: env::var("HANKO_WEB_API_BASE_URL")
            .unwrap_or_default()
            .trim()
            .to_owned(),
        firestore_project_id: None,
        credentials_file: None,
        storage_assets_bucket: None,
    };

    if cfg.port.is_empty() {
        cfg.port = "3052".to_owned();
    }

    if cfg.locale.is_empty() {
        cfg.locale = "ja".to_owned();
    }

    if cfg.default_locale.is_empty() {
        cfg.default_locale = "ja".to_owned();
    }

    if cfg.api_base_url.is_empty() {
        cfg.api_base_url = "http://localhost:3050".to_owned();
    }

    let mut mode_value = env_first(&["HANKO_WEB_MODE", "HANKO_WEB_ENV"]).to_lowercase();
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
        _ => bail!("invalid HANKO_WEB_MODE {mode_value:?}: use mock, dev, or prod"),
    }

    let (project_id_keys, credentials_keys, storage_bucket_keys): (&[&str], &[&str], &[&str]) =
        match cfg.mode {
            RunMode::Dev => (
                &[
                    "HANKO_WEB_FIREBASE_PROJECT_ID_DEV",
                    "HANKO_WEB_FIREBASE_PROJECT_ID",
                    "FIREBASE_PROJECT_ID",
                    "GOOGLE_CLOUD_PROJECT",
                ],
                &[
                    "HANKO_WEB_FIREBASE_CREDENTIALS_FILE_DEV",
                    "HANKO_WEB_FIREBASE_CREDENTIALS_FILE",
                    "GOOGLE_APPLICATION_CREDENTIALS",
                ],
                &[
                    "HANKO_WEB_STORAGE_ASSETS_BUCKET_DEV",
                    "HANKO_WEB_STORAGE_ASSETS_BUCKET",
                    "API_STORAGE_ASSETS_BUCKET",
                ],
            ),
            RunMode::Prod => (
                &[
                    "HANKO_WEB_FIREBASE_PROJECT_ID_PROD",
                    "HANKO_WEB_FIREBASE_PROJECT_ID",
                    "FIREBASE_PROJECT_ID",
                    "GOOGLE_CLOUD_PROJECT",
                ],
                &[
                    "HANKO_WEB_FIREBASE_CREDENTIALS_FILE_PROD",
                    "HANKO_WEB_FIREBASE_CREDENTIALS_FILE",
                    "GOOGLE_APPLICATION_CREDENTIALS",
                ],
                &[
                    "HANKO_WEB_STORAGE_ASSETS_BUCKET_PROD",
                    "HANKO_WEB_STORAGE_ASSETS_BUCKET",
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

    let credentials_file = env_first(credentials_keys);
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

async fn new_catalog_source(cfg: &AppConfig) -> Result<CatalogSource> {
    match cfg.mode {
        RunMode::Mock => Ok(CatalogSource::Mock(new_mock_catalog_source())),
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

            Ok(CatalogSource::Firestore(FirestoreCatalogSource {
                project_id: cfg
                    .firestore_project_id
                    .clone()
                    .context("firestore project id is empty")?,
                locale: cfg.locale.clone(),
                default_locale: cfg.default_locale.clone(),
                label,
                storage_assets_bucket: cfg.storage_assets_bucket.clone().unwrap_or_default(),
                token_provider,
            }))
        }
    }
}

fn new_mock_catalog_source() -> MockCatalogSource {
    MockCatalogSource {
        catalog: CatalogData {
            fonts: vec![
                FontOption {
                    key: "zen_maru_gothic".to_owned(),
                    label: "Zen Maru Gothic".to_owned(),
                    family: "'Zen Maru Gothic', sans-serif".to_owned(),
                    stylesheet_url:
                        "https://fonts.googleapis.com/css2?family=Zen+Maru+Gothic:wght@400;700&display=swap"
                            .to_owned(),
                    kanji_style: "japanese".to_owned(),
                },
                FontOption {
                    key: "kosugi_maru".to_owned(),
                    label: "Kosugi Maru".to_owned(),
                    family: "'Kosugi Maru', sans-serif".to_owned(),
                    stylesheet_url:
                        "https://fonts.googleapis.com/css2?family=Kosugi+Maru&display=swap"
                            .to_owned(),
                    kanji_style: "chinese".to_owned(),
                },
                FontOption {
                    key: "potta_one".to_owned(),
                    label: "Potta One".to_owned(),
                    family: "'Potta One', sans-serif".to_owned(),
                    stylesheet_url:
                        "https://fonts.googleapis.com/css2?family=Potta+One&display=swap"
                            .to_owned(),
                    kanji_style: "taiwanese".to_owned(),
                },
                FontOption {
                    key: "kiwi_maru".to_owned(),
                    label: "Kiwi Maru".to_owned(),
                    family: "'Kiwi Maru', sans-serif".to_owned(),
                    stylesheet_url:
                        "https://fonts.googleapis.com/css2?family=Kiwi+Maru:wght@400;700&display=swap"
                            .to_owned(),
                    kanji_style: "japanese".to_owned(),
                },
                FontOption {
                    key: "wdxl_lubrifont_jp_n".to_owned(),
                    label: "WDXL Lubrifont JP N".to_owned(),
                    family: "'WDXL Lubrifont JP N', sans-serif".to_owned(),
                    stylesheet_url:
                        "https://fonts.googleapis.com/css2?family=WDXL+Lubrifont+JP+N&display=swap"
                            .to_owned(),
                    kanji_style: "chinese".to_owned(),
                },
            ],
            materials: vec![
                MaterialOption {
                    key: "boxwood".to_owned(),
                    label: "柘植".to_owned(),
                    description: "軽くて扱いやすい定番材".to_owned(),
                    shape: "square".to_owned(),
                    shape_label: "角印".to_owned(),
                    price: 3600,
                    price_display: format_yen(3600),
                    photo_url: "https://picsum.photos/seed/hf-boxwood/640/420".to_owned(),
                    photo_alt: "柘植材の写真".to_owned(),
                    has_photo: true,
                },
                MaterialOption {
                    key: "black_buffalo".to_owned(),
                    label: "黒水牛".to_owned(),
                    description: "しっとりした質感で耐久性が高い".to_owned(),
                    shape: "round".to_owned(),
                    shape_label: "丸印".to_owned(),
                    price: 4800,
                    price_display: format_yen(4800),
                    photo_url: "https://picsum.photos/seed/hf-black-buffalo/640/420".to_owned(),
                    photo_alt: "黒水牛材の写真".to_owned(),
                    has_photo: true,
                },
                MaterialOption {
                    key: "titanium".to_owned(),
                    label: "チタン".to_owned(),
                    description: "重厚で摩耗に強いプレミアム材".to_owned(),
                    shape: "square".to_owned(),
                    shape_label: "角印".to_owned(),
                    price: 9800,
                    price_display: format_yen(9800),
                    photo_url: "https://picsum.photos/seed/hf-titanium/640/420".to_owned(),
                    photo_alt: "チタン材の写真".to_owned(),
                    has_photo: true,
                },
            ],
            countries: vec![
                CountryOption {
                    code: "JP".to_owned(),
                    label: "日本".to_owned(),
                    shipping: 600,
                },
                CountryOption {
                    code: "US".to_owned(),
                    label: "アメリカ".to_owned(),
                    shipping: 1800,
                },
                CountryOption {
                    code: "CA".to_owned(),
                    label: "カナダ".to_owned(),
                    shipping: 1900,
                },
                CountryOption {
                    code: "GB".to_owned(),
                    label: "イギリス".to_owned(),
                    shipping: 2000,
                },
                CountryOption {
                    code: "AU".to_owned(),
                    label: "オーストラリア".to_owned(),
                    shipping: 2100,
                },
                CountryOption {
                    code: "SG".to_owned(),
                    label: "シンガポール".to_owned(),
                    shipping: 1300,
                },
            ],
        },
    }
}

async fn load_catalog_with_timeout(source: &CatalogSource) -> Result<CatalogData> {
    let catalog = tokio::time::timeout(Duration::from_secs(7), source.load_catalog())
        .await
        .context("catalog load timed out after 7s")??;

    validate_catalog(&catalog)?;
    Ok(catalog)
}

fn validate_catalog(catalog: &CatalogData) -> Result<()> {
    if catalog.fonts.is_empty() {
        bail!("catalog validation failed: fonts is empty");
    }
    if catalog.materials.is_empty() {
        bail!("catalog validation failed: materials is empty");
    }
    if catalog.countries.is_empty() {
        bail!("catalog validation failed: countries is empty");
    }
    Ok(())
}

fn collect_font_stylesheet_urls(fonts: &[FontOption]) -> Vec<String> {
    let mut seen = HashSet::new();
    let mut urls = Vec::new();

    for font in fonts {
        let url = font.stylesheet_url.trim();
        if url.is_empty() {
            continue;
        }
        if seen.insert(url.to_owned()) {
            urls.push(url.to_owned());
        }
    }

    urls
}

async fn handle_index(State(state): State<AppState>) -> Response {
    let catalog = match load_catalog_with_timeout(state.source.as_ref()).await {
        Ok(catalog) => catalog,
        Err(error) => {
            return plain_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("failed to load catalog: {error}"),
            );
        }
    };

    let Some(default_font) = catalog
        .fonts
        .iter()
        .find(|font| font.kanji_style == "japanese")
        .or_else(|| catalog.fonts.first())
    else {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            "catalog validation failed: fonts is empty".to_owned(),
        );
    };

    let template = PageTemplate {
        font_stylesheet_urls: collect_font_stylesheet_urls(&catalog.fonts),
        default_font_key: default_font.key.clone(),
        default_font_label: default_font.label.clone(),
        fonts: catalog.fonts,
        materials: catalog.materials,
        countries: catalog.countries,
        is_mock: state.source.is_mock(),
    };

    match render_html(&template) {
        Ok(html) => html_response(html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render page: {error}"),
        ),
    }
}

async fn handle_kanji_suggestions(
    State(state): State<AppState>,
    form: std::result::Result<Form<HashMap<String, String>>, FormRejection>,
) -> Response {
    let Form(form) = match form {
        Ok(form) => form,
        Err(_) => return plain_error(StatusCode::BAD_REQUEST, "invalid request".to_owned()),
    };

    let real_name = form_value(&form, "real_name");
    let reason_language = state.locale.trim().to_owned();
    let candidate_gender = normalize_candidate_gender(&form_value(&form, "candidate_gender"));
    let kanji_style = normalize_kanji_style(&form_value(&form, "kanji_style"));

    let (suggestions, error) = if real_name.is_empty() {
        (Vec::new(), String::new())
    } else {
        match state
            .kanji_api
            .generate_candidates(&real_name, &reason_language, candidate_gender, kanji_style)
            .await
        {
            Ok(suggestions) => (suggestions, String::new()),
            Err(error) => {
                eprintln!("failed to load kanji candidates: {error:#}");
                (
                    Vec::new(),
                    "候補を生成できませんでした。時間をおいて再度お試しください。".to_owned(),
                )
            }
        }
    };

    let template = KanjiSuggestionsTemplate {
        real_name,
        has_suggestions: !suggestions.is_empty(),
        suggestions,
        error,
    };

    match render_html(&template) {
        Ok(html) => html_response(html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render suggestions: {error}"),
        ),
    }
}

async fn handle_purchase(
    State(state): State<AppState>,
    form: std::result::Result<Form<HashMap<String, String>>, FormRejection>,
) -> Response {
    let Form(form) = match form {
        Ok(form) => form,
        Err(_) => return plain_error(StatusCode::BAD_REQUEST, "invalid request".to_owned()),
    };

    let catalog = match load_catalog_with_timeout(state.source.as_ref()).await {
        Ok(catalog) => catalog,
        Err(error) => {
            return plain_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("failed to load catalog: {error}"),
            );
        }
    };

    let font_by_key = catalog
        .fonts
        .iter()
        .cloned()
        .map(|font| (font.key.clone(), font))
        .collect::<HashMap<_, _>>();
    let material_by_key = catalog
        .materials
        .iter()
        .cloned()
        .map(|material| (material.key.clone(), material))
        .collect::<HashMap<_, _>>();
    let country_by_code = catalog
        .countries
        .iter()
        .cloned()
        .map(|country| (country.code.clone(), country))
        .collect::<HashMap<_, _>>();

    let seal_line1 = form_value(&form, "seal_line1");
    let seal_line2 = form_value(&form, "seal_line2");
    let font_key = form_value(&form, "font");
    let shape_key = form_value(&form, "shape");
    let material_key = form_value(&form, "material");
    let recipient_name = form_value(&form, "recipient_name");
    let phone = form_value(&form, "phone");
    let country_code = form_value(&form, "country");
    let postal_code = form_value(&form, "postal_code");
    let state_name = form_value(&form, "state");
    let city = form_value(&form, "city");
    let address_line1 = form_value(&form, "address_line1");
    let address_line2 = form_value(&form, "address_line2");
    let email = form_value(&form, "email");
    let terms_value = form_value(&form, "terms_agreed");
    let terms_agreed =
        terms_value == "on" || terms_value == "1" || terms_value.eq_ignore_ascii_case("true");

    let mut result = PurchaseResultData {
        source_label: state.source.label().to_owned(),
        is_mock: state.source.is_mock(),
        ..PurchaseResultData::default()
    };

    if let Err(message) = validate_seal_lines(&seal_line1, &seal_line2) {
        result.error = message;
        return render_purchase_result(&result);
    }

    let Some(font) = font_by_key.get(&font_key) else {
        result.error = "フォントを選択してください。".to_owned();
        return render_purchase_result(&result);
    };

    let Some(selected_shape_label) = shape_label(&shape_key) else {
        result.error = "印鑑の形状を選択してください。".to_owned();
        return render_purchase_result(&result);
    };

    let Some(material) = material_by_key.get(&material_key) else {
        result.error = "材質を選択してください。".to_owned();
        return render_purchase_result(&result);
    };
    if material.shape != shape_key {
        result.error = format!(
            "{}に対応する材質を選択してください。",
            shape_label(&shape_key).unwrap_or("印鑑の形状")
        );
        return render_purchase_result(&result);
    }

    let Some(country) = country_by_code.get(&country_code) else {
        result.error = "配送先の国を選択してください。".to_owned();
        return render_purchase_result(&result);
    };

    if recipient_name.is_empty() {
        result.error = "購入者名を入力してください。".to_owned();
        return render_purchase_result(&result);
    }

    if phone.is_empty() {
        result.error = "電話番号を入力してください。".to_owned();
        return render_purchase_result(&result);
    }

    if postal_code.is_empty() {
        result.error = "郵便番号を入力してください。".to_owned();
        return render_purchase_result(&result);
    }

    if state_name.is_empty() {
        result.error = "都道府県 / 州を入力してください。".to_owned();
        return render_purchase_result(&result);
    }

    if city.is_empty() {
        result.error = "市区町村 / City を入力してください。".to_owned();
        return render_purchase_result(&result);
    }

    if address_line1.is_empty() {
        result.error = "住所1を入力してください。".to_owned();
        return render_purchase_result(&result);
    }

    if email.is_empty() {
        result.error = "購入確認用のメールアドレスを入力してください。".to_owned();
        return render_purchase_result(&result);
    }

    if !terms_agreed {
        result.error = "利用規約への同意が必要です。".to_owned();
        return render_purchase_result(&result);
    }

    let subtotal = material.price;
    let shipping = country.shipping;
    let total = subtotal + shipping;
    let order_locale = state.locale.trim().to_lowercase();

    let create_order_request = CreateOrderApiRequest {
        channel: "web".to_owned(),
        locale: order_locale.clone(),
        idempotency_key: generate_idempotency_key(),
        terms_agreed: true,
        seal: CreateOrderSealApiRequest {
            line1: seal_line1.clone(),
            line2: seal_line2.clone(),
            shape: shape_key.clone(),
            font_key: font_key.clone(),
        },
        material_key: material_key.clone(),
        shipping: CreateOrderShippingApiRequest {
            country_code: country_code.clone(),
            recipient_name: recipient_name.clone(),
            phone: phone.clone(),
            postal_code: postal_code.clone(),
            state: state_name.clone(),
            city: city.clone(),
            address_line1: address_line1.clone(),
            address_line2: address_line2.clone(),
        },
        contact: CreateOrderContactApiRequest {
            email: email.clone(),
            preferred_locale: order_locale,
        },
    };

    result.seal_line1 = seal_line1;
    result.seal_line2 = seal_line2;
    result.font_label = font.label.clone();
    result.shape_label = selected_shape_label.to_owned();
    result.material_label = material.label.clone();
    result.stripe_name = recipient_name;
    result.stripe_phone = phone;
    result.country_label = country.label.clone();
    result.postal_code = postal_code;
    result.state = state_name;
    result.city = city;
    result.address_line1 = address_line1;
    result.address_line2 = address_line2;
    result.subtotal = subtotal;
    result.shipping = shipping;
    result.total = total;
    result.email = email;

    if result.is_mock {
        return render_purchase_result(&result);
    }

    let order = match state.kanji_api.create_order(&create_order_request).await {
        Ok(order) => order,
        Err(error) => {
            eprintln!("failed to create order for stripe checkout: {error:#}");
            result.error = "注文の作成に失敗しました。時間をおいて再度お試しください。".to_owned();
            return render_purchase_result(&result);
        }
    };

    let checkout_request = CreateStripeCheckoutSessionApiRequest {
        order_id: order.order_id,
        customer_email: result.email.clone(),
    };
    let checkout_session = match state
        .kanji_api
        .create_stripe_checkout_session(&checkout_request)
        .await
    {
        Ok(session) => session,
        Err(error) => {
            eprintln!("failed to create stripe checkout session: {error:#}");
            result.error =
                "決済画面の作成に失敗しました。時間をおいて再度お試しください。".to_owned();
            return render_purchase_result(&result);
        }
    };

    hx_redirect_response(&checkout_session.checkout_url)
}

fn render_purchase_result(data: &PurchaseResultData) -> Response {
    let template = PurchaseResultTemplate {
        has_error: !data.error.is_empty(),
        error: data.error.clone(),
        seal_line1: data.seal_line1.clone(),
        seal_line2: data.seal_line2.clone(),
        has_seal_line2: !data.seal_line2.is_empty(),
        font_label: data.font_label.clone(),
        shape_label: data.shape_label.clone(),
        material_label: data.material_label.clone(),
        stripe_name: data.stripe_name.clone(),
        stripe_phone: data.stripe_phone.clone(),
        country_label: data.country_label.clone(),
        postal_code: data.postal_code.clone(),
        state: data.state.clone(),
        city: data.city.clone(),
        address_line1: data.address_line1.clone(),
        address_line2: data.address_line2.clone(),
        has_address_line2: !data.address_line2.is_empty(),
        subtotal_display: format_yen(data.subtotal),
        shipping_display: format_yen(data.shipping),
        total_display: format_yen(data.total),
        email: data.email.clone(),
        source_label: data.source_label.clone(),
        is_mock: data.is_mock,
    };

    match render_html(&template) {
        Ok(html) => html_response(html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render purchase result: {error}"),
        ),
    }
}

fn hx_redirect_response(url: &str) -> Response {
    let redirect = url.trim();
    if redirect.is_empty() {
        return plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            "failed to redirect to checkout".to_owned(),
        );
    }

    let mut response = StatusCode::OK.into_response();
    if let Ok(value) = HeaderValue::from_str(redirect) {
        response
            .headers_mut()
            .insert(HeaderName::from_static(HX_REDIRECT_HEADER), value);
        return response;
    }

    plain_error(
        StatusCode::INTERNAL_SERVER_ERROR,
        "failed to redirect to checkout".to_owned(),
    )
}

fn generate_idempotency_key() -> String {
    format!("web_{}", Uuid::new_v4().as_simple())
}

fn render_html<T: Template>(template: &T) -> Result<String> {
    template
        .render()
        .map_err(|error| anyhow!(error.to_string()))
}

fn html_response(body: String) -> Response {
    ([(header::CONTENT_TYPE, "text/html; charset=utf-8")], body).into_response()
}

fn plain_error(status: StatusCode, message: String) -> Response {
    (status, message).into_response()
}

fn form_value(form: &HashMap<String, String>, key: &str) -> String {
    form.get(key)
        .map(|value| value.trim().to_owned())
        .unwrap_or_default()
}

fn normalize_candidate_gender(raw: &str) -> &'static str {
    match raw.trim().to_lowercase().as_str() {
        "male" => "male",
        "female" => "female",
        _ => "unspecified",
    }
}

fn normalize_kanji_style(raw: &str) -> &'static str {
    match raw.trim().to_lowercase().as_str() {
        "chinese" => "chinese",
        "taiwanese" => "taiwanese",
        _ => "japanese",
    }
}

fn normalize_material_shape(raw: &str) -> &'static str {
    match raw.trim().to_ascii_lowercase().as_str() {
        "round" => "round",
        _ => "square",
    }
}

fn material_shape_label(shape_key: &str) -> &'static str {
    match shape_key {
        "round" => "丸印",
        _ => "角印",
    }
}

fn shape_label(shape_key: &str) -> Option<&'static str> {
    match shape_key {
        "square" => Some("角印"),
        "round" => Some("丸印"),
        _ => None,
    }
}

fn validate_seal_lines(line1: &str, line2: &str) -> std::result::Result<(), String> {
    let first = line1.trim();
    let second = line2.trim();

    if first.is_empty() {
        return Err("お名前を入力してください。".to_owned());
    }

    if contains_whitespace(first) {
        return Err("1行目に空白は使えません。".to_owned());
    }

    if !second.is_empty() && contains_whitespace(second) {
        return Err("2行目に空白は使えません。".to_owned());
    }

    if first.chars().count() + second.chars().count() > 2 {
        return Err("印影テキストは1行目と2行目の合計で2文字以内で入力してください。".to_owned());
    }

    Ok(())
}

fn contains_whitespace(value: &str) -> bool {
    value.chars().any(char::is_whitespace)
}

fn format_yen(price: i64) -> String {
    if price == 0 {
        return "0".to_owned();
    }

    let sign = if price < 0 { "-" } else { "" };
    let digits = price.abs().to_string();
    let mut out = String::with_capacity(digits.len() + digits.len() / 3 + 1);

    for (index, ch) in digits.chars().enumerate() {
        if index > 0 && (digits.len() - index) % 3 == 0 {
            out.push(',');
        }
        out.push(ch);
    }

    format!("{sign}{out}")
}

fn document_id(document: &Document) -> Option<String> {
    document
        .name
        .as_deref()
        .and_then(|name| name.rsplit('/').next())
        .map(ToOwned::to_owned)
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
        if let Some(parsed) = integer_value.as_u64().and_then(|v| i64::try_from(v).ok()) {
            return Some(parsed);
        }
    }

    if let Some(double_value) = value.get("doubleValue").and_then(JsonValue::as_f64) {
        return Some(double_value as i64);
    }

    value
        .as_i64()
        .or_else(|| value.as_u64().and_then(|v| i64::try_from(v).ok()))
}

fn read_string_map_field(data: &BTreeMap<String, JsonValue>, key: &str) -> HashMap<String, String> {
    let Some(value) = data.get(key) else {
        return HashMap::new();
    };

    let Some(fields) = value
        .get("mapValue")
        .and_then(|map_value| map_value.get("fields"))
        .and_then(JsonValue::as_object)
    else {
        return HashMap::new();
    };

    let mut result = HashMap::new();
    for (map_key, map_value) in fields {
        let text = map_value
            .get("stringValue")
            .and_then(JsonValue::as_str)
            .map(str::trim)
            .filter(|value| !value.is_empty());
        if let Some(text) = text {
            result.insert(map_key.clone(), text.to_owned());
        }
    }

    result
}

fn resolve_material_photo(
    data: &BTreeMap<String, JsonValue>,
    storage_assets_bucket: &str,
    locale: &str,
    default_locale: &str,
) -> (String, String, bool) {
    let mut photo_url = resolve_localized_field(
        data,
        "photo_url_i18n",
        "photo_url",
        locale,
        default_locale,
        "",
    );
    if photo_url.is_empty() {
        photo_url = resolve_localized_field(
            data,
            "image_url_i18n",
            "image_url",
            locale,
            default_locale,
            "",
        );
    }

    let mut photo_alt = resolve_localized_field(
        data,
        "photo_alt_i18n",
        "photo_alt",
        locale,
        default_locale,
        "",
    );

    if photo_url.is_empty() {
        if let Some((storage_path, storage_alt)) =
            select_primary_material_photo(data, locale, default_locale)
        {
            photo_url = build_storage_media_url(storage_assets_bucket, &storage_path);
            if photo_alt.is_empty() {
                photo_alt = storage_alt;
            }
        }
    }

    let has_photo = !photo_url.is_empty();
    (photo_url, photo_alt, has_photo)
}

fn select_primary_material_photo(
    data: &BTreeMap<String, JsonValue>,
    locale: &str,
    default_locale: &str,
) -> Option<(String, String)> {
    let mut selected_rank: Option<(i32, i64, usize)> = None;
    let mut selected_path = String::new();
    let mut selected_alt = String::new();

    for (index, photo) in read_array_field(data, "photos").into_iter().enumerate() {
        let Some(fields) = photo
            .get("mapValue")
            .and_then(|map| map.get("fields"))
            .and_then(JsonValue::as_object)
        else {
            continue;
        };

        let fields = fields
            .iter()
            .map(|(key, value)| (key.clone(), value.clone()))
            .collect::<BTreeMap<_, _>>();

        let storage_path = normalize_storage_path(&read_string_field(&fields, "storage_path"));
        if storage_path.is_empty() {
            continue;
        }

        let alt = resolve_localized_text(
            &read_string_map_field(&fields, "alt_i18n"),
            locale,
            default_locale,
        );
        let is_primary = read_bool_field(&fields, "is_primary").unwrap_or(false);
        let sort_order = read_int_field(&fields, "sort_order").unwrap_or_default();
        let rank = (if is_primary { 0 } else { 1 }, sort_order, index);

        let should_replace = match selected_rank {
            Some(current_rank) => rank < current_rank,
            None => true,
        };
        if should_replace {
            selected_rank = Some(rank);
            selected_path = storage_path;
            selected_alt = alt;
        }
    }

    if selected_path.is_empty() {
        None
    } else {
        Some((selected_path, selected_alt))
    }
}

fn build_storage_media_url(bucket_name: &str, storage_path: &str) -> String {
    let normalized_bucket = normalize_storage_bucket_name(bucket_name);
    let normalized_path = normalize_storage_path(storage_path);
    if normalized_bucket.is_empty() || normalized_path.is_empty() {
        return String::new();
    }

    let mut endpoint = match reqwest::Url::parse("https://firebasestorage.googleapis.com/v0/b") {
        Ok(endpoint) => endpoint,
        Err(_) => return String::new(),
    };

    {
        let mut path_segments = match endpoint.path_segments_mut() {
            Ok(path_segments) => path_segments,
            Err(_) => return String::new(),
        };
        path_segments.extend([normalized_bucket.as_str(), "o", normalized_path.as_str()]);
    }
    endpoint.query_pairs_mut().append_pair("alt", "media");
    endpoint.to_string()
}

fn normalize_storage_bucket_name(value: &str) -> String {
    value
        .trim()
        .trim_start_matches("gs://")
        .trim_start_matches("GS://")
        .trim_matches('/')
        .to_owned()
}

fn normalize_storage_path(value: &str) -> String {
    value.trim().trim_start_matches('/').to_owned()
}

fn read_bool_field(data: &BTreeMap<String, JsonValue>, key: &str) -> Option<bool> {
    let value = data.get(key)?;
    value
        .get("booleanValue")
        .and_then(JsonValue::as_bool)
        .or_else(|| value.as_bool())
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
