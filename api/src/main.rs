use std::{
    collections::{BTreeMap, HashMap, HashSet},
    net::SocketAddr,
    str::FromStr,
    sync::Arc,
    time::Duration as StdDuration,
};

use anyhow::{Context, Result, anyhow, bail};
use axum::{
    Router,
    body::Bytes,
    extract::{DefaultBodyLimit, Query, State},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post},
};
use chrono::{DateTime, Duration, FixedOffset, SecondsFormat, Utc};
use firebase_sdk_rust::firebase_firestore::{
    CreateDocumentOptions, Document, FirebaseFirestoreClient, FirebaseFirestoreError,
    GetDocumentOptions, PatchDocumentOptions, RunQueryRequest,
};
use gcp_auth::{CustomServiceAccount, TokenProvider, provider};
use hmac::{Hmac, Mac};
use regex::Regex;
use serde::Deserialize;
use serde_json::{Value as JsonValue, json};
use sha2::{Digest, Sha256};
use tokio::net::TcpListener;
use uuid::Uuid;

type HmacSha256 = Hmac<Sha256>;

const DATASTORE_SCOPE: &str = "https://www.googleapis.com/auth/datastore";
const MAX_REQUEST_BODY_BYTES: usize = 1 << 20;
const DEFAULT_PORT: &str = "3050";
const DEFAULT_LOCALE: &str = "ja";
const STRIPE_SIGNATURE_TOLERANCE_SECONDS: i64 = 300;
const DEFAULT_GEMINI_MODEL: &str = "gemini-2.5-flash-lite";
const DEFAULT_KANJI_CANDIDATE_COUNT: usize = 6;
const MAX_KANJI_CANDIDATE_COUNT: usize = 10;

#[derive(Debug, Clone)]
struct AppConfig {
    addr: String,
    firestore_project_id: String,
    storage_assets_bucket: String,
    stripe_webhook_secret: String,
    gemini_api_key: String,
    gemini_model: String,
    gemini_base_url: String,
    credentials_file: Option<String>,
}

#[derive(Clone)]
struct AppState {
    store: Arc<FirestoreStore>,
    storage_assets_bucket: String,
    stripe_webhook_secret: String,
    gemini: GeminiClientConfig,
    http_client: reqwest::Client,
}

#[derive(Debug, Clone)]
struct GeminiClientConfig {
    api_key: String,
    model: String,
    base_url: String,
}

#[derive(Clone)]
struct FirestoreStore {
    parent: String,
    token_provider: Arc<dyn TokenProvider>,
    jst: FixedOffset,
}

#[derive(Debug, Clone)]
struct PublicConfig {
    supported_locales: Vec<String>,
    default_locale: String,
}

#[derive(Debug, Clone)]
struct Font {
    key: String,
    label_i18n: HashMap<String, String>,
    font_family: String,
    version: i64,
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
    version: i64,
}

#[derive(Debug, Clone)]
struct Country {
    code: String,
    label_i18n: HashMap<String, String>,
    shipping_fee_jpy: i64,
    version: i64,
}

#[derive(Debug, Clone)]
struct CreateOrderResult {
    order_id: String,
    order_no: String,
    status: String,
    payment_status: String,
    fulfillment_status: String,
    total_jpy: i64,
    currency: String,
    idempotent_replay: bool,
}

#[derive(Debug, Clone)]
struct ProcessStripeWebhookResult {
    processed: bool,
    already_processed: bool,
}

#[derive(Debug, Clone)]
struct CreateOrderInput {
    channel: String,
    locale: String,
    idempotency_key: String,
    terms_agreed: bool,
    seal: SealInput,
    material_key: String,
    shipping: ShippingInput,
    contact: ContactInput,
}

#[derive(Debug, Clone)]
struct SealInput {
    line1: String,
    line2: String,
    shape: String,
    font_key: String,
}

#[derive(Debug, Clone)]
struct ShippingInput {
    country_code: String,
    recipient_name: String,
    phone: String,
    postal_code: String,
    state: String,
    city: String,
    address_line1: String,
    address_line2: String,
}

#[derive(Debug, Clone)]
struct ContactInput {
    email: String,
    preferred_locale: String,
}

#[derive(Debug, Clone)]
struct StripeWebhookEvent {
    provider_event_id: String,
    event_type: String,
    payment_intent_id: String,
    order_id: String,
}

#[derive(Debug, Deserialize)]
struct QueryLocale {
    locale: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct GenerateKanjiCandidatesRequest {
    real_name: String,
    reason_language: Option<String>,
    count: Option<usize>,
}

#[derive(Debug, Clone)]
struct GenerateKanjiCandidatesInput {
    real_name: String,
    reason_language: String,
    count: usize,
}

#[derive(Debug, Clone)]
struct KanjiNameCandidate {
    kanji: String,
    reading_hiragana: String,
    reading_romaji: String,
    reason: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct CreateOrderRequest {
    channel: String,
    locale: String,
    idempotency_key: String,
    terms_agreed: bool,
    seal: CreateOrderSealRequest,
    material_key: String,
    shipping: CreateOrderShippingRequest,
    contact: CreateOrderContactRequest,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct CreateOrderSealRequest {
    line1: String,
    line2: String,
    shape: String,
    font_key: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct CreateOrderShippingRequest {
    country_code: String,
    recipient_name: String,
    phone: String,
    postal_code: String,
    state: String,
    city: String,
    address_line1: String,
    address_line2: String,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct CreateOrderContactRequest {
    email: String,
    preferred_locale: String,
}

#[derive(Debug, Deserialize)]
struct StripeEventEnvelope {
    id: String,
    #[serde(rename = "type")]
    event_type: String,
    data: StripeEventData,
}

#[derive(Debug, Deserialize)]
struct StripeEventData {
    object: JsonValue,
}

#[derive(Debug, thiserror::Error)]
enum StoreError {
    #[error("unsupported locale")]
    UnsupportedLocale,
    #[error("invalid reference")]
    InvalidReference,
    #[error("inactive reference")]
    InactiveReference,
    #[error("idempotency key conflict")]
    IdempotencyConflict,
    #[error("internal: {0}")]
    Internal(#[from] anyhow::Error),
}

#[tokio::main]
async fn main() {
    if let Err(err) = run().await {
        eprintln!("failed to start api server: {err:#}");
        std::process::exit(1);
    }
}

async fn run() -> Result<()> {
    let cfg = load_config().context("failed to load config")?;

    let token_provider: Arc<dyn TokenProvider> = if let Some(credentials_file) =
        cfg.credentials_file.as_deref()
    {
        Arc::new(
            CustomServiceAccount::from_file(credentials_file)
                .with_context(|| format!("failed to read credentials file: {credentials_file}"))?,
        )
    } else {
        provider()
            .await
            .context("failed to initialize default GCP auth provider")?
    };

    let store = Arc::new(FirestoreStore {
        parent: format!(
            "projects/{}/databases/(default)/documents",
            cfg.firestore_project_id
        ),
        token_provider,
        jst: FixedOffset::east_opt(9 * 60 * 60).expect("valid JST offset"),
    });

    let http_client = reqwest::Client::builder()
        .timeout(StdDuration::from_secs(20))
        .build()
        .context("failed to initialize http client")?;

    let state = AppState {
        store,
        storage_assets_bucket: cfg.storage_assets_bucket,
        stripe_webhook_secret: cfg.stripe_webhook_secret,
        gemini: GeminiClientConfig {
            api_key: cfg.gemini_api_key,
            model: cfg.gemini_model,
            base_url: cfg.gemini_base_url,
        },
        http_client,
    };

    let app = Router::new()
        .route("/healthz", get(handle_healthz))
        .route("/v1/config/public", get(handle_public_config))
        .route("/v1/catalog", get(handle_catalog))
        .route(
            "/v1/kanji-candidates",
            post(handle_generate_kanji_candidates),
        )
        .route("/v1/orders", post(handle_create_order))
        .route("/v1/payments/stripe/webhook", post(handle_stripe_webhook))
        .layer(DefaultBodyLimit::max(MAX_REQUEST_BODY_BYTES))
        .with_state(state);

    let addr = SocketAddr::from_str(&format!("0.0.0.0{}", cfg.addr))
        .with_context(|| format!("invalid listen addr: {}", cfg.addr))?;
    let listener = TcpListener::bind(addr)
        .await
        .with_context(|| format!("failed to bind on {addr}"))?;

    eprintln!("hanko api listening on http://localhost{}", cfg.addr);

    axum::serve(listener, app)
        .with_graceful_shutdown(async {
            let _ = tokio::signal::ctrl_c().await;
        })
        .await
        .context("api server exited unexpectedly")
}

fn load_config() -> Result<AppConfig> {
    let port = first_non_empty(&[
        std::env::var("API_SERVER_PORT").ok(),
        std::env::var("PORT").ok(),
    ])
    .unwrap_or_else(|| DEFAULT_PORT.to_owned());

    let firestore_project_id = first_non_empty(&[
        std::env::var("API_FIRESTORE_PROJECT_ID").ok(),
        std::env::var("FIRESTORE_PROJECT_ID").ok(),
        std::env::var("API_FIREBASE_PROJECT_ID").ok(),
        std::env::var("FIREBASE_PROJECT_ID").ok(),
        std::env::var("GOOGLE_CLOUD_PROJECT").ok(),
    ])
    .ok_or_else(|| {
        anyhow!(
            "missing Firestore project id: set API_FIRESTORE_PROJECT_ID or FIRESTORE_PROJECT_ID"
        )
    })?;

    let storage_assets_bucket = first_non_empty(&[std::env::var("API_STORAGE_ASSETS_BUCKET").ok()])
        .unwrap_or_else(|| "local-assets".to_owned());

    let stripe_webhook_secret =
        first_non_empty(&[std::env::var("API_PSP_STRIPE_WEBHOOK_SECRET").ok()]).unwrap_or_default();

    let gemini_api_key = first_non_empty(&[
        std::env::var("API_GEMINI_API_KEY").ok(),
        std::env::var("GEMINI_API_KEY").ok(),
    ])
    .unwrap_or_default();

    let gemini_model = first_non_empty(&[std::env::var("API_GEMINI_MODEL").ok()])
        .unwrap_or_else(|| DEFAULT_GEMINI_MODEL.to_owned());

    let gemini_base_url = first_non_empty(&[std::env::var("API_GEMINI_BASE_URL").ok()])
        .unwrap_or_else(|| "https://generativelanguage.googleapis.com".to_owned());

    let credentials_file = first_non_empty(&[
        std::env::var("API_FIREBASE_CREDENTIALS_FILE").ok(),
        std::env::var("GOOGLE_APPLICATION_CREDENTIALS").ok(),
    ]);

    Ok(AppConfig {
        addr: format!(":{}", port.trim()),
        firestore_project_id,
        storage_assets_bucket,
        stripe_webhook_secret,
        gemini_api_key,
        gemini_model,
        gemini_base_url,
        credentials_file,
    })
}

fn first_non_empty(values: &[Option<String>]) -> Option<String> {
    values
        .iter()
        .filter_map(|value| value.as_deref())
        .map(str::trim)
        .find(|value| !value.is_empty())
        .map(ToOwned::to_owned)
}

async fn handle_healthz() -> Response {
    json_response(StatusCode::OK, json!({ "ok": true }))
}

async fn handle_public_config(State(state): State<AppState>) -> Response {
    match state.store.get_public_config().await {
        Ok(cfg) => json_response(
            StatusCode::OK,
            json!({
                "supported_locales": cfg.supported_locales,
                "default_locale": cfg.default_locale,
            }),
        ),
        Err(err) => {
            eprintln!("failed to load public config: {err:#}");
            error_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal",
                "internal server error",
            )
        }
    }
}

async fn handle_catalog(
    State(state): State<AppState>,
    Query(query): Query<QueryLocale>,
) -> Response {
    let cfg = match state.store.get_public_config().await {
        Ok(cfg) => cfg,
        Err(err) => {
            eprintln!("failed to load public config: {err:#}");
            return error_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal",
                "internal server error",
            );
        }
    };

    let requested_locale = query
        .locale
        .unwrap_or_else(|| cfg.default_locale.clone())
        .trim()
        .to_lowercase();

    if !cfg
        .supported_locales
        .iter()
        .any(|locale| locale == &requested_locale)
    {
        return error_response(
            StatusCode::BAD_REQUEST,
            "invalid_locale",
            "unsupported locale",
        );
    }

    let fonts = match state.store.list_active_fonts().await {
        Ok(v) => v,
        Err(err) => {
            eprintln!("failed to load fonts: {err:#}");
            return error_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal",
                "internal server error",
            );
        }
    };

    let materials = match state.store.list_active_materials().await {
        Ok(v) => v,
        Err(err) => {
            eprintln!("failed to load materials: {err:#}");
            return error_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal",
                "internal server error",
            );
        }
    };

    let countries = match state.store.list_active_countries().await {
        Ok(v) => v,
        Err(err) => {
            eprintln!("failed to load countries: {err:#}");
            return error_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal",
                "internal server error",
            );
        }
    };

    let font_resp = fonts
        .into_iter()
        .map(|font| {
            json!({
                "key": font.key,
                "label": resolve_localized(&font.label_i18n, &requested_locale, &cfg.default_locale),
                "font_family": font.font_family,
                "version": font.version,
            })
        })
        .collect::<Vec<_>>();

    let material_resp = materials
        .into_iter()
        .map(|material| {
            let photos = material
                .photos
                .into_iter()
                .map(|photo| {
                    json!({
                        "asset_id": photo.asset_id,
                        "asset_url": make_asset_url(&state.storage_assets_bucket, &photo.storage_path),
                        "storage_path": photo.storage_path,
                        "alt": resolve_localized(&photo.alt_i18n, &requested_locale, &cfg.default_locale),
                        "sort_order": photo.sort_order,
                        "is_primary": photo.is_primary,
                        "width": photo.width,
                        "height": photo.height,
                    })
                })
                .collect::<Vec<_>>();

            json!({
                "key": material.key,
                "label": resolve_localized(&material.label_i18n, &requested_locale, &cfg.default_locale),
                "description": resolve_localized(&material.description_i18n, &requested_locale, &cfg.default_locale),
                "price_jpy": material.price_jpy,
                "version": material.version,
                "photos": photos,
            })
        })
        .collect::<Vec<_>>();

    let country_resp = countries
        .into_iter()
        .map(|country| {
            json!({
                "code": country.code,
                "label": resolve_localized(&country.label_i18n, &requested_locale, &cfg.default_locale),
                "shipping_fee_jpy": country.shipping_fee_jpy,
                "version": country.version,
            })
        })
        .collect::<Vec<_>>();

    json_response(
        StatusCode::OK,
        json!({
            "locale": requested_locale,
            "supported_locales": cfg.supported_locales,
            "default_locale": cfg.default_locale,
            "fonts": font_resp,
            "materials": material_resp,
            "countries": country_resp,
        }),
    )
}

async fn handle_generate_kanji_candidates(State(state): State<AppState>, body: Bytes) -> Response {
    if state.gemini.api_key.trim().is_empty() {
        return error_response(
            StatusCode::SERVICE_UNAVAILABLE,
            "gemini_not_configured",
            "gemini api key is not configured",
        );
    }

    let request = match serde_json::from_slice::<GenerateKanjiCandidatesRequest>(&body) {
        Ok(value) => value,
        Err(err) => {
            return error_response(
                StatusCode::BAD_REQUEST,
                "invalid_json",
                &format!("invalid JSON: {err}"),
            );
        }
    };

    let input = match validate_generate_kanji_candidates_request(request) {
        Ok(value) => value,
        Err(err) => {
            return error_response(
                StatusCode::BAD_REQUEST,
                "validation_error",
                &err.to_string(),
            );
        }
    };

    let candidates = match generate_kanji_candidates_with_gemini(&state, &input).await {
        Ok(value) => value,
        Err(err) => {
            eprintln!("failed to generate kanji candidates with gemini: {err:#}");
            return error_response(
                StatusCode::BAD_GATEWAY,
                "gemini_generation_failed",
                "failed to generate kanji candidates",
            );
        }
    };

    if candidates.is_empty() {
        return error_response(
            StatusCode::BAD_GATEWAY,
            "gemini_generation_failed",
            "gemini returned no valid candidates",
        );
    }

    json_response(
        StatusCode::OK,
        json!({
            "real_name": input.real_name,
            "reason_language": input.reason_language,
            "candidates": candidates.into_iter().map(|candidate| {
                json!({
                    "kanji": candidate.kanji,
                    "reading_hiragana": candidate.reading_hiragana,
                    "reading_romaji": candidate.reading_romaji,
                    "reason": candidate.reason,
                })
            }).collect::<Vec<_>>(),
        }),
    )
}

async fn handle_create_order(State(state): State<AppState>, body: Bytes) -> Response {
    let request = match serde_json::from_slice::<CreateOrderRequest>(&body) {
        Ok(v) => v,
        Err(err) => {
            return error_response(
                StatusCode::BAD_REQUEST,
                "invalid_json",
                &format!("invalid JSON: {err}"),
            );
        }
    };

    let input = match validate_create_order_request(request) {
        Ok(v) => v,
        Err(err) => {
            return error_response(
                StatusCode::BAD_REQUEST,
                "validation_error",
                &err.to_string(),
            );
        }
    };

    match state.store.create_order(input).await {
        Ok(result) => {
            let status = if result.idempotent_replay {
                StatusCode::OK
            } else {
                StatusCode::CREATED
            };
            json_response(
                status,
                json!({
                    "order_id": result.order_id,
                    "order_no": result.order_no,
                    "status": result.status,
                    "payment_status": result.payment_status,
                    "fulfillment_status": result.fulfillment_status,
                    "pricing": {
                        "total_jpy": result.total_jpy,
                        "currency": result.currency,
                    },
                    "idempotent_replay": result.idempotent_replay,
                }),
            )
        }
        Err(StoreError::UnsupportedLocale) => error_response(
            StatusCode::BAD_REQUEST,
            "unsupported_locale",
            "unsupported locale",
        ),
        Err(StoreError::InvalidReference) => error_response(
            StatusCode::BAD_REQUEST,
            "invalid_reference",
            "invalid font/material/country",
        ),
        Err(StoreError::InactiveReference) => error_response(
            StatusCode::BAD_REQUEST,
            "inactive_reference",
            "inactive font/material/country",
        ),
        Err(StoreError::IdempotencyConflict) => error_response(
            StatusCode::CONFLICT,
            "idempotency_conflict",
            "idempotency key is already used with different payload",
        ),
        Err(StoreError::Internal(err)) => {
            eprintln!("failed to create order: {err:#}");
            error_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal",
                "internal server error",
            )
        }
    }
}

async fn handle_stripe_webhook(
    State(state): State<AppState>,
    headers: HeaderMap,
    body: Bytes,
) -> Response {
    let signature = headers
        .get("Stripe-Signature")
        .and_then(|value| value.to_str().ok())
        .unwrap_or_default();

    if let Err(err) = verify_stripe_signature(&body, signature, &state.stripe_webhook_secret) {
        return error_response(
            StatusCode::UNAUTHORIZED,
            "invalid_signature",
            &err.to_string(),
        );
    }

    let event = match parse_stripe_event(&body) {
        Ok(event) => event,
        Err(err) => {
            return error_response(StatusCode::BAD_REQUEST, "invalid_payload", &err.to_string());
        }
    };

    match state.store.process_stripe_webhook(event).await {
        Ok(result) => json_response(
            StatusCode::OK,
            json!({
                "ok": true,
                "processed": result.processed,
                "already_processed": result.already_processed,
            }),
        ),
        Err(StoreError::Internal(err)) => {
            eprintln!("failed to process stripe webhook: {err:#}");
            error_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal",
                "internal server error",
            )
        }
        Err(other) => {
            eprintln!("failed to process stripe webhook: {other}");
            error_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal",
                "internal server error",
            )
        }
    }
}

fn json_response(status: StatusCode, payload: JsonValue) -> Response {
    (status, axum::Json(payload)).into_response()
}

fn error_response(status: StatusCode, code: &str, message: &str) -> Response {
    json_response(
        status,
        json!({
            "error": {
                "code": code,
                "message": message,
            }
        }),
    )
}

impl FirestoreStore {
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

    async fn get_public_config(&self) -> Result<PublicConfig> {
        let client = self.firestore_client().await?;
        let name = format!("{}/app_config/public", self.parent);

        match client
            .get_document(&name, &GetDocumentOptions::default())
            .await
        {
            Ok(document) => {
                let supported = read_string_array_from_map(&document.fields, "supported_locales");
                let default_locale = read_string_field(&document.fields, "default_locale");
                Ok(normalize_public_config(PublicConfig {
                    supported_locales: supported,
                    default_locale,
                }))
            }
            Err(err) if is_not_found(&err) => Ok(default_public_config()),
            Err(err) => Err(anyhow!(err)),
        }
    }

    async fn list_active_fonts(&self) -> Result<Vec<Font>> {
        let documents = self.query_active_documents("fonts").await?;
        let mut fonts = Vec::with_capacity(documents.len());

        for document in documents {
            let key =
                document_id(&document).ok_or_else(|| anyhow!("fonts document is missing name"))?;
            let mut font_family = read_string_field(&document.fields, "font_family");
            if font_family.is_empty() {
                font_family = read_string_field(&document.fields, "family");
            }
            if font_family.is_empty() {
                bail!("fonts/{key} is missing font_family");
            }

            fonts.push(Font {
                key,
                label_i18n: read_string_map_field(&document.fields, "label_i18n"),
                font_family,
                version: read_int_field(&document.fields, "version").unwrap_or(1),
            });
        }

        if fonts.is_empty() {
            bail!("no active fonts found in firestore");
        }

        Ok(fonts)
    }

    async fn list_active_materials(&self) -> Result<Vec<Material>> {
        let documents = self.query_active_documents("materials").await?;
        let mut materials = Vec::with_capacity(documents.len());

        for document in documents {
            let key = document_id(&document)
                .ok_or_else(|| anyhow!("materials document is missing name"))?;
            let price_jpy = read_int_field(&document.fields, "price_jpy")
                .or_else(|| read_int_field(&document.fields, "price"))
                .ok_or_else(|| anyhow!("materials/{key} is missing price_jpy"))?;

            let photos = read_material_photos(&document.fields);

            materials.push(Material {
                key,
                label_i18n: read_string_map_field(&document.fields, "label_i18n"),
                description_i18n: read_string_map_field(&document.fields, "description_i18n"),
                photos,
                price_jpy,
                version: read_int_field(&document.fields, "version").unwrap_or(1),
            });
        }

        if materials.is_empty() {
            bail!("no active materials found in firestore");
        }

        Ok(materials)
    }

    async fn list_active_countries(&self) -> Result<Vec<Country>> {
        let documents = self.query_active_documents("countries").await?;
        let mut countries = Vec::with_capacity(documents.len());

        for document in documents {
            let code = document_id(&document)
                .ok_or_else(|| anyhow!("countries document is missing name"))?;
            let shipping_fee_jpy = read_int_field(&document.fields, "shipping_fee_jpy")
                .or_else(|| read_int_field(&document.fields, "shipping"))
                .ok_or_else(|| anyhow!("countries/{code} is missing shipping_fee_jpy"))?;

            countries.push(Country {
                code,
                label_i18n: read_string_map_field(&document.fields, "label_i18n"),
                shipping_fee_jpy,
                version: read_int_field(&document.fields, "version").unwrap_or(1),
            });
        }

        if countries.is_empty() {
            bail!("no active countries found in firestore");
        }

        Ok(countries)
    }

    async fn query_active_documents(&self, collection: &str) -> Result<Vec<Document>> {
        let client = self.firestore_client().await?;
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
            .run_query(&self.parent, &query)
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

    async fn create_order(&self, input: CreateOrderInput) -> Result<CreateOrderResult, StoreError> {
        let normalized = normalize_create_order_input(input);
        let request_hash =
            hash_order_request(&normalized).map_err(|err| StoreError::Internal(err.into()))?;
        let idempotency_id = format!("{}:{}", normalized.channel, normalized.idempotency_key);

        let cfg = self
            .get_public_config()
            .await
            .map_err(StoreError::Internal)?;
        if !contains(&cfg.supported_locales, &normalized.locale)
            || !contains(&cfg.supported_locales, &normalized.contact.preferred_locale)
        {
            return Err(StoreError::UnsupportedLocale);
        }

        let client = self
            .firestore_client()
            .await
            .map_err(StoreError::Internal)?;

        let idempotency_doc_name = format!("{}/idempotency_keys/{}", self.parent, idempotency_id);
        if let Some(result) = self
            .try_idempotent_replay(&client, &idempotency_doc_name, &request_hash)
            .await?
        {
            return Ok(result);
        }

        let font = self
            .get_active_font(&client, &normalized.seal.font_key)
            .await?;
        let material = self
            .get_active_material(&client, &normalized.material_key)
            .await?;
        let country = self
            .get_active_country(&client, &normalized.shipping.country_code)
            .await?;

        let now = Utc::now();
        let subtotal = material.price_jpy;
        let shipping = country.shipping_fee_jpy;
        let tax = 0_i64;
        let discount = 0_i64;
        let total = (subtotal + shipping + tax - discount).max(0);

        let random = Uuid::new_v4();
        let order_suffix =
            u16::from_be_bytes([random.as_bytes()[0], random.as_bytes()[1]]) % 10_000;
        let order_no = format!(
            "HF-{}-{:04}",
            now.with_timezone(&self.jst).format("%Y%m%d"),
            order_suffix
        );

        let order_doc = Document {
            name: None,
            fields: build_order_fields(
                &normalized,
                &font,
                &material,
                &country,
                &order_no,
                subtotal,
                shipping,
                tax,
                discount,
                total,
                now,
            ),
            ..Document::default()
        };

        let created_order = client
            .create_document(
                &self.parent,
                "orders",
                &order_doc,
                &CreateDocumentOptions::default(),
            )
            .await
            .map_err(|err| StoreError::Internal(anyhow!(err)))?;

        let order_id = document_id(&created_order)
            .ok_or_else(|| StoreError::Internal(anyhow!("created order is missing document id")))?;

        let event_doc = Document {
            name: None,
            fields: btree_from_pairs(vec![
                ("type", fs_string("order_created")),
                ("actor_type", fs_string("system")),
                (
                    "payload",
                    fs_map(btree_from_pairs(vec![
                        ("channel", fs_string(normalized.channel.clone())),
                        ("total_jpy", fs_int(total)),
                    ])),
                ),
                ("created_at", fs_timestamp(now)),
            ]),
            ..Document::default()
        };

        client
            .create_document(
                &format!("{}/orders/{order_id}", self.parent),
                "events",
                &event_doc,
                &CreateDocumentOptions::default(),
            )
            .await
            .map_err(|err| StoreError::Internal(anyhow!(err)))?;

        let idempotency_doc = Document {
            name: None,
            fields: btree_from_pairs(vec![
                ("channel", fs_string(normalized.channel.clone())),
                (
                    "idempotency_key",
                    fs_string(normalized.idempotency_key.clone()),
                ),
                ("request_hash", fs_string(request_hash.clone())),
                ("order_id", fs_string(order_id.clone())),
                ("created_at", fs_timestamp(now)),
                ("expire_at", fs_timestamp(now + Duration::days(30))),
            ]),
            ..Document::default()
        };

        let create_idempotency_result = client
            .create_document(
                &self.parent,
                "idempotency_keys",
                &idempotency_doc,
                &CreateDocumentOptions {
                    document_id: Some(idempotency_id.clone()),
                    ..CreateDocumentOptions::default()
                },
            )
            .await;

        if let Err(err) = create_idempotency_result {
            if is_conflict(&err) {
                if let Some(result) = self
                    .try_idempotent_replay(&client, &idempotency_doc_name, &request_hash)
                    .await?
                {
                    return Ok(result);
                }
                return Err(StoreError::IdempotencyConflict);
            }
            return Err(StoreError::Internal(anyhow!(err)));
        }

        Ok(CreateOrderResult {
            order_id,
            order_no,
            status: "pending_payment".to_owned(),
            payment_status: "unpaid".to_owned(),
            fulfillment_status: "pending".to_owned(),
            total_jpy: total,
            currency: "JPY".to_owned(),
            idempotent_replay: false,
        })
    }

    async fn try_idempotent_replay(
        &self,
        client: &FirebaseFirestoreClient,
        idempotency_doc_name: &str,
        request_hash: &str,
    ) -> Result<Option<CreateOrderResult>, StoreError> {
        let idempotency_doc = match client
            .get_document(idempotency_doc_name, &GetDocumentOptions::default())
            .await
        {
            Ok(doc) => doc,
            Err(err) if is_not_found(&err) => return Ok(None),
            Err(err) => return Err(StoreError::Internal(anyhow!(err))),
        };

        let existing_hash = read_string_field(&idempotency_doc.fields, "request_hash");
        if existing_hash != request_hash {
            return Err(StoreError::IdempotencyConflict);
        }

        let order_id = read_string_field(&idempotency_doc.fields, "order_id");
        if order_id.is_empty() {
            return Err(StoreError::Internal(anyhow!(
                "idempotency key exists but order_id is empty"
            )));
        }

        let order_doc_name = format!("{}/orders/{}", self.parent, order_id);
        let order_doc = client
            .get_document(&order_doc_name, &GetDocumentOptions::default())
            .await
            .map_err(|err| StoreError::Internal(anyhow!(err)))?;

        let status = read_string_field(&order_doc.fields, "status");
        let order_no = read_string_field(&order_doc.fields, "order_no");

        let pricing = read_map_field(&order_doc.fields, "pricing");
        let payment = read_map_field(&order_doc.fields, "payment");
        let fulfillment = read_map_field(&order_doc.fields, "fulfillment");

        Ok(Some(CreateOrderResult {
            order_id,
            order_no,
            status,
            payment_status: read_string_field(&payment, "status"),
            fulfillment_status: read_string_field(&fulfillment, "status"),
            total_jpy: read_int_field(&pricing, "total_jpy").unwrap_or_default(),
            currency: read_string_field(&pricing, "currency"),
            idempotent_replay: true,
        }))
    }

    async fn get_active_font(
        &self,
        client: &FirebaseFirestoreClient,
        key: &str,
    ) -> Result<Font, StoreError> {
        let doc_name = format!("{}/fonts/{}", self.parent, key);
        let doc = client
            .get_document(&doc_name, &GetDocumentOptions::default())
            .await
            .map_err(|err| {
                if is_not_found(&err) {
                    StoreError::InvalidReference
                } else {
                    StoreError::Internal(anyhow!(err))
                }
            })?;

        if !read_bool_field(&doc.fields, "is_active").unwrap_or(false) {
            return Err(StoreError::InactiveReference);
        }

        Ok(Font {
            key: key.to_owned(),
            label_i18n: read_string_map_field(&doc.fields, "label_i18n"),
            font_family: read_string_field(&doc.fields, "font_family"),
            version: read_int_field(&doc.fields, "version").unwrap_or(1),
        })
    }

    async fn get_active_material(
        &self,
        client: &FirebaseFirestoreClient,
        key: &str,
    ) -> Result<Material, StoreError> {
        let doc_name = format!("{}/materials/{}", self.parent, key);
        let doc = client
            .get_document(&doc_name, &GetDocumentOptions::default())
            .await
            .map_err(|err| {
                if is_not_found(&err) {
                    StoreError::InvalidReference
                } else {
                    StoreError::Internal(anyhow!(err))
                }
            })?;

        if !read_bool_field(&doc.fields, "is_active").unwrap_or(false) {
            return Err(StoreError::InactiveReference);
        }

        Ok(Material {
            key: key.to_owned(),
            label_i18n: read_string_map_field(&doc.fields, "label_i18n"),
            description_i18n: read_string_map_field(&doc.fields, "description_i18n"),
            photos: read_material_photos(&doc.fields),
            price_jpy: read_int_field(&doc.fields, "price_jpy")
                .or_else(|| read_int_field(&doc.fields, "price"))
                .unwrap_or_default(),
            version: read_int_field(&doc.fields, "version").unwrap_or(1),
        })
    }

    async fn get_active_country(
        &self,
        client: &FirebaseFirestoreClient,
        code: &str,
    ) -> Result<Country, StoreError> {
        let doc_name = format!("{}/countries/{}", self.parent, code);
        let doc = client
            .get_document(&doc_name, &GetDocumentOptions::default())
            .await
            .map_err(|err| {
                if is_not_found(&err) {
                    StoreError::InvalidReference
                } else {
                    StoreError::Internal(anyhow!(err))
                }
            })?;

        if !read_bool_field(&doc.fields, "is_active").unwrap_or(false) {
            return Err(StoreError::InactiveReference);
        }

        Ok(Country {
            code: code.to_owned(),
            label_i18n: read_string_map_field(&doc.fields, "label_i18n"),
            shipping_fee_jpy: read_int_field(&doc.fields, "shipping_fee_jpy")
                .or_else(|| read_int_field(&doc.fields, "shipping"))
                .unwrap_or_default(),
            version: read_int_field(&doc.fields, "version").unwrap_or(1),
        })
    }

    async fn process_stripe_webhook(
        &self,
        event: StripeWebhookEvent,
    ) -> Result<ProcessStripeWebhookResult, StoreError> {
        let normalized = normalize_webhook_event(event);
        if normalized.provider_event_id.is_empty() {
            return Err(StoreError::Internal(anyhow!(
                "provider event id is required"
            )));
        }

        let client = self
            .firestore_client()
            .await
            .map_err(StoreError::Internal)?;

        let webhook_doc_name = format!(
            "{}/payment_webhook_events/{}",
            self.parent, normalized.provider_event_id
        );

        if let Ok(existing) = client
            .get_document(&webhook_doc_name, &GetDocumentOptions::default())
            .await
        {
            if read_bool_field(&existing.fields, "processed").unwrap_or(false) {
                return Ok(ProcessStripeWebhookResult {
                    processed: false,
                    already_processed: true,
                });
            }
        }

        let now = Utc::now();

        let mut webhook_fields = btree_from_pairs(vec![
            ("provider", fs_string("stripe")),
            ("event_type", fs_string(normalized.event_type.clone())),
            ("order_id", fs_string(normalized.order_id.clone())),
            ("processed", fs_bool(false)),
            ("created_at", fs_timestamp(now)),
            ("expire_at", fs_timestamp(now + Duration::days(90))),
        ]);

        upsert_named_document(
            &client,
            &self.parent,
            "payment_webhook_events",
            &normalized.provider_event_id,
            webhook_fields.clone(),
        )
        .await
        .map_err(|err| StoreError::Internal(err.into()))?;

        if normalized.order_id.is_empty() {
            webhook_fields.insert("processed".to_owned(), fs_bool(true));
            upsert_named_document(
                &client,
                &self.parent,
                "payment_webhook_events",
                &normalized.provider_event_id,
                webhook_fields,
            )
            .await
            .map_err(|err| StoreError::Internal(err.into()))?;

            return Ok(ProcessStripeWebhookResult {
                processed: true,
                already_processed: false,
            });
        }

        let order_doc_name = format!("{}/orders/{}", self.parent, normalized.order_id);
        let mut order_doc = match client
            .get_document(&order_doc_name, &GetDocumentOptions::default())
            .await
        {
            Ok(doc) => doc,
            Err(err) if is_not_found(&err) => {
                webhook_fields.insert("processed".to_owned(), fs_bool(true));
                upsert_named_document(
                    &client,
                    &self.parent,
                    "payment_webhook_events",
                    &normalized.provider_event_id,
                    webhook_fields,
                )
                .await
                .map_err(|e| StoreError::Internal(e.into()))?;
                return Ok(ProcessStripeWebhookResult {
                    processed: true,
                    already_processed: false,
                });
            }
            Err(err) => return Err(StoreError::Internal(anyhow!(err))),
        };

        let order_status = read_string_field(&order_doc.fields, "status");
        let (payment_status, next_status, audit_event_type) =
            stripe_transition(&normalized.event_type);

        let mut payment = read_map_field(&order_doc.fields, "payment");
        payment.insert(
            "last_event_id".to_owned(),
            fs_string(normalized.provider_event_id.clone()),
        );
        if !normalized.payment_intent_id.is_empty() {
            payment.insert(
                "intent_id".to_owned(),
                fs_string(normalized.payment_intent_id.clone()),
            );
        }
        if !payment_status.is_empty() {
            payment.insert("status".to_owned(), fs_string(payment_status));
        }
        order_doc
            .fields
            .insert("payment".to_owned(), fs_map(payment));
        order_doc
            .fields
            .insert("updated_at".to_owned(), fs_timestamp(now));

        let mut after_status = order_status.clone();
        if !next_status.is_empty()
            && next_status != order_status
            && can_transition(&order_status, next_status)
        {
            order_doc
                .fields
                .insert("status".to_owned(), fs_string(next_status));
            order_doc
                .fields
                .insert("status_updated_at".to_owned(), fs_timestamp(now));
            after_status = next_status.to_owned();
        }

        client
            .patch_document(
                &order_doc_name,
                &order_doc,
                &PatchDocumentOptions::default(),
            )
            .await
            .map_err(|err| StoreError::Internal(anyhow!(err)))?;

        let mut payload = btree_from_pairs(vec![
            (
                "provider_event_id",
                fs_string(normalized.provider_event_id.clone()),
            ),
            ("event_type", fs_string(normalized.event_type.clone())),
        ]);
        if !normalized.payment_intent_id.is_empty() {
            payload.insert(
                "payment_intent_id".to_owned(),
                fs_string(normalized.payment_intent_id.clone()),
            );
        }

        let mut event_fields = btree_from_pairs(vec![
            ("type", fs_string(audit_event_type)),
            ("actor_type", fs_string("webhook")),
            ("actor_id", fs_string("stripe")),
            ("payload", fs_map(payload)),
            ("created_at", fs_timestamp(now)),
        ]);
        if after_status != order_status {
            event_fields.insert("before_status".to_owned(), fs_string(order_status));
            event_fields.insert("after_status".to_owned(), fs_string(after_status));
        }

        client
            .create_document(
                &format!("{}/orders/{}", self.parent, normalized.order_id),
                "events",
                &Document {
                    name: None,
                    fields: event_fields,
                    ..Document::default()
                },
                &CreateDocumentOptions::default(),
            )
            .await
            .map_err(|err| StoreError::Internal(anyhow!(err)))?;

        webhook_fields.insert("processed".to_owned(), fs_bool(true));
        upsert_named_document(
            &client,
            &self.parent,
            "payment_webhook_events",
            &normalized.provider_event_id,
            webhook_fields,
        )
        .await
        .map_err(|err| StoreError::Internal(err.into()))?;

        Ok(ProcessStripeWebhookResult {
            processed: true,
            already_processed: false,
        })
    }
}

fn build_order_fields(
    input: &CreateOrderInput,
    font: &Font,
    material: &Material,
    country: &Country,
    order_no: &str,
    subtotal: i64,
    shipping: i64,
    tax: i64,
    discount: i64,
    total: i64,
    now: DateTime<Utc>,
) -> BTreeMap<String, JsonValue> {
    btree_from_pairs(vec![
        ("order_no", fs_string(order_no)),
        ("channel", fs_string(input.channel.clone())),
        ("locale", fs_string(input.locale.clone())),
        ("status", fs_string("pending_payment")),
        ("status_updated_at", fs_timestamp(now)),
        (
            "seal",
            fs_map(btree_from_pairs(vec![
                ("line1", fs_string(input.seal.line1.clone())),
                ("line2", fs_string(input.seal.line2.clone())),
                ("shape", fs_string(input.seal.shape.clone())),
                ("font_key", fs_string(font.key.clone())),
                ("font_label_i18n", fs_string_map(&font.label_i18n)),
                ("font_version", fs_int(font.version)),
            ])),
        ),
        (
            "material",
            fs_map(btree_from_pairs(vec![
                ("key", fs_string(material.key.clone())),
                ("label_i18n", fs_string_map(&material.label_i18n)),
                ("unit_price_jpy", fs_int(material.price_jpy)),
                ("version", fs_int(material.version)),
            ])),
        ),
        (
            "shipping",
            fs_map(btree_from_pairs(vec![
                ("country_code", fs_string(country.code.clone())),
                ("country_label_i18n", fs_string_map(&country.label_i18n)),
                ("country_version", fs_int(country.version)),
                ("fee_jpy", fs_int(country.shipping_fee_jpy)),
                (
                    "recipient_name",
                    fs_string(input.shipping.recipient_name.clone()),
                ),
                ("phone", fs_string(input.shipping.phone.clone())),
                ("postal_code", fs_string(input.shipping.postal_code.clone())),
                ("state", fs_string(input.shipping.state.clone())),
                ("city", fs_string(input.shipping.city.clone())),
                (
                    "address_line1",
                    fs_string(input.shipping.address_line1.clone()),
                ),
                (
                    "address_line2",
                    fs_string(input.shipping.address_line2.clone()),
                ),
            ])),
        ),
        (
            "contact",
            fs_map(btree_from_pairs(vec![
                ("email", fs_string(input.contact.email.clone())),
                (
                    "preferred_locale",
                    fs_string(input.contact.preferred_locale.clone()),
                ),
            ])),
        ),
        (
            "pricing",
            fs_map(btree_from_pairs(vec![
                ("subtotal_jpy", fs_int(subtotal)),
                ("shipping_jpy", fs_int(shipping)),
                ("tax_jpy", fs_int(tax)),
                ("discount_jpy", fs_int(discount)),
                ("total_jpy", fs_int(total)),
                ("currency", fs_string("JPY")),
            ])),
        ),
        (
            "payment",
            fs_map(btree_from_pairs(vec![
                ("provider", fs_string("stripe")),
                ("status", fs_string("unpaid")),
            ])),
        ),
        (
            "fulfillment",
            fs_map(btree_from_pairs(vec![("status", fs_string("pending"))])),
        ),
        ("idempotency_key", fs_string(input.idempotency_key.clone())),
        ("terms_agreed", fs_bool(input.terms_agreed)),
        ("created_at", fs_timestamp(now)),
        ("updated_at", fs_timestamp(now)),
    ])
}

async fn upsert_named_document(
    client: &FirebaseFirestoreClient,
    parent: &str,
    collection: &str,
    doc_id: &str,
    fields: BTreeMap<String, JsonValue>,
) -> Result<Document> {
    let name = format!("{parent}/{collection}/{doc_id}");
    let document = Document {
        name: Some(name.clone()),
        fields,
        ..Document::default()
    };

    match client
        .patch_document(&name, &document, &PatchDocumentOptions::default())
        .await
    {
        Ok(doc) => Ok(doc),
        Err(err) if is_not_found(&err) => client
            .create_document(
                parent,
                collection,
                &document,
                &CreateDocumentOptions {
                    document_id: Some(doc_id.to_owned()),
                    ..CreateDocumentOptions::default()
                },
            )
            .await
            .map_err(anyhow::Error::from),
        Err(err) => Err(anyhow!(err)),
    }
}

fn default_public_config() -> PublicConfig {
    PublicConfig {
        supported_locales: vec!["ja".to_owned(), "en".to_owned()],
        default_locale: DEFAULT_LOCALE.to_owned(),
    }
}

fn normalize_public_config(cfg: PublicConfig) -> PublicConfig {
    let mut normalized = Vec::with_capacity(cfg.supported_locales.len());
    let mut seen = HashSet::with_capacity(cfg.supported_locales.len());
    for locale in cfg.supported_locales {
        let value = locale.trim().to_lowercase();
        if value.is_empty() || seen.contains(&value) {
            continue;
        }
        seen.insert(value.clone());
        normalized.push(value);
    }

    if normalized.is_empty() {
        normalized = vec!["ja".to_owned(), "en".to_owned()];
    }

    let mut default_locale = cfg.default_locale.trim().to_lowercase();
    if default_locale.is_empty() || !contains(&normalized, &default_locale) {
        default_locale = DEFAULT_LOCALE.to_owned();
    }
    if !contains(&normalized, &default_locale) {
        normalized.insert(0, default_locale.clone());
    }

    PublicConfig {
        supported_locales: normalized,
        default_locale,
    }
}

fn normalize_create_order_input(input: CreateOrderInput) -> CreateOrderInput {
    CreateOrderInput {
        channel: input.channel.trim().to_lowercase(),
        locale: input.locale.trim().to_lowercase(),
        idempotency_key: input.idempotency_key.trim().to_owned(),
        terms_agreed: input.terms_agreed,
        seal: SealInput {
            line1: input.seal.line1.trim().to_owned(),
            line2: input.seal.line2.trim().to_owned(),
            shape: input.seal.shape.trim().to_lowercase(),
            font_key: input.seal.font_key.trim().to_owned(),
        },
        material_key: input.material_key.trim().to_owned(),
        shipping: ShippingInput {
            country_code: input.shipping.country_code.trim().to_uppercase(),
            recipient_name: input.shipping.recipient_name.trim().to_owned(),
            phone: input.shipping.phone.trim().to_owned(),
            postal_code: input.shipping.postal_code.trim().to_owned(),
            state: input.shipping.state.trim().to_owned(),
            city: input.shipping.city.trim().to_owned(),
            address_line1: input.shipping.address_line1.trim().to_owned(),
            address_line2: input.shipping.address_line2.trim().to_owned(),
        },
        contact: ContactInput {
            email: input.contact.email.trim().to_owned(),
            preferred_locale: input.contact.preferred_locale.trim().to_lowercase(),
        },
    }
}

fn hash_order_request(input: &CreateOrderInput) -> Result<String> {
    let payload = serde_json::to_vec(&json!({
        "channel": input.channel,
        "locale": input.locale,
        "idempotency_key": input.idempotency_key,
        "terms_agreed": input.terms_agreed,
        "seal": {
            "line1": input.seal.line1,
            "line2": input.seal.line2,
            "shape": input.seal.shape,
            "font_key": input.seal.font_key,
        },
        "material_key": input.material_key,
        "shipping": {
            "country_code": input.shipping.country_code,
            "recipient_name": input.shipping.recipient_name,
            "phone": input.shipping.phone,
            "postal_code": input.shipping.postal_code,
            "state": input.shipping.state,
            "city": input.shipping.city,
            "address_line1": input.shipping.address_line1,
            "address_line2": input.shipping.address_line2,
        },
        "contact": {
            "email": input.contact.email,
            "preferred_locale": input.contact.preferred_locale,
        }
    }))?;

    let mut hasher = Sha256::new();
    hasher.update(payload);
    Ok(hex::encode(hasher.finalize()))
}

fn validate_generate_kanji_candidates_request(
    request: GenerateKanjiCandidatesRequest,
) -> Result<GenerateKanjiCandidatesInput> {
    let real_name = request.real_name.trim().to_owned();
    if real_name.is_empty() {
        bail!("real_name is required");
    }
    if real_name.chars().count() > 120 {
        bail!("real_name must be 120 characters or fewer");
    }

    let reason_language = request
        .reason_language
        .unwrap_or_else(|| "en".to_owned())
        .trim()
        .to_owned();
    if reason_language.is_empty() {
        bail!("reason_language is required");
    }
    if reason_language.chars().count() > 32 {
        bail!("reason_language must be 32 characters or fewer");
    }

    let count = request.count.unwrap_or(DEFAULT_KANJI_CANDIDATE_COUNT);
    if count == 0 || count > MAX_KANJI_CANDIDATE_COUNT {
        bail!("count must be in range 1-{}", MAX_KANJI_CANDIDATE_COUNT);
    }

    Ok(GenerateKanjiCandidatesInput {
        real_name,
        reason_language,
        count,
    })
}

async fn generate_kanji_candidates_with_gemini(
    state: &AppState,
    input: &GenerateKanjiCandidatesInput,
) -> Result<Vec<KanjiNameCandidate>> {
    let prompt = build_kanji_candidates_prompt(input);

    let endpoint = format!(
        "{}/v1beta/models/{}:generateContent",
        state.gemini.base_url.trim_end_matches('/'),
        state.gemini.model.trim()
    );

    let response = state
        .http_client
        .post(endpoint)
        .query(&[("key", state.gemini.api_key.as_str())])
        .json(&json!({
            "contents": [
                {
                    "role": "user",
                    "parts": [
                        {
                            "text": prompt,
                        }
                    ]
                }
            ],
            "generationConfig": {
                "temperature": 0.7,
                "responseMimeType": "application/json",
            }
        }))
        .send()
        .await
        .context("failed to call gemini generateContent")?;

    if !response.status().is_success() {
        let status = response.status();
        let body = response
            .text()
            .await
            .unwrap_or_else(|_| "<unable to read response body>".to_owned());
        bail!("gemini request failed status={} body={}", status, body);
    }

    let payload = response
        .json::<JsonValue>()
        .await
        .context("failed to parse gemini response payload")?;

    let text = extract_gemini_response_text(&payload)
        .ok_or_else(|| anyhow!("gemini response did not include text"))?;

    parse_kanji_candidates_from_gemini_text(&text, input.count)
}

fn build_kanji_candidates_prompt(input: &GenerateKanjiCandidatesInput) -> String {
    format!(
        "Generate {} unique Japanese name candidates for a hanko seal.\n\
Input name: \"{}\"\n\
For each candidate, return these fields:\n\
- kanji: 1-2 Japanese Kanji characters (no spaces)\n\
- reading_hiragana: reading in hiragana\n\
- reading_romaji: reading in lowercase romaji\n\
- reason: why this Kanji name was chosen, written in {}\n\
Return only JSON (no markdown, no explanation) in this exact shape:\n\
{{\"candidates\":[{{\"kanji\":\"\",\"reading_hiragana\":\"\",\"reading_romaji\":\"\",\"reason\":\"\"}}]}}",
        input.count, input.real_name, input.reason_language
    )
}

fn extract_gemini_response_text(payload: &JsonValue) -> Option<String> {
    let candidates = payload.get("candidates")?.as_array()?;
    for candidate in candidates {
        let Some(parts) = candidate
            .get("content")
            .and_then(|content| content.get("parts"))
            .and_then(JsonValue::as_array)
        else {
            continue;
        };
        for part in parts {
            if let Some(text) = part.get("text").and_then(JsonValue::as_str) {
                let trimmed = text.trim();
                if !trimmed.is_empty() {
                    return Some(trimmed.to_owned());
                }
            }
        }
    }
    None
}

fn parse_kanji_candidates_from_gemini_text(
    raw_text: &str,
    max_count: usize,
) -> Result<Vec<KanjiNameCandidate>> {
    let parsed = parse_json_value_loose(raw_text)?;
    let array = parsed
        .get("candidates")
        .and_then(JsonValue::as_array)
        .ok_or_else(|| anyhow!("gemini response JSON must contain candidates array"))?;

    let mut candidates = Vec::with_capacity(array.len());
    let mut seen = HashSet::new();
    for entry in array {
        let Some(candidate) = normalize_kanji_candidate(entry) else {
            continue;
        };
        if !seen.insert(candidate.kanji.clone()) {
            continue;
        }
        candidates.push(candidate);
        if candidates.len() >= max_count {
            break;
        }
    }

    Ok(candidates)
}

fn parse_json_value_loose(raw_text: &str) -> Result<JsonValue> {
    let trimmed = raw_text.trim();
    if trimmed.is_empty() {
        bail!("gemini response text is empty");
    }

    if let Ok(value) = serde_json::from_str::<JsonValue>(trimmed) {
        return Ok(value);
    }

    let content = trimmed
        .trim_start_matches("```json")
        .trim_start_matches("```")
        .trim_end_matches("```")
        .trim();
    if let Ok(value) = serde_json::from_str::<JsonValue>(content) {
        return Ok(value);
    }

    if let (Some(start), Some(end)) = (trimmed.find('{'), trimmed.rfind('}'))
        && start < end
    {
        let slice = &trimmed[start..=end];
        if let Ok(value) = serde_json::from_str::<JsonValue>(slice) {
            return Ok(value);
        }
    }

    bail!("failed to parse json from gemini response text")
}

fn normalize_kanji_candidate(value: &JsonValue) -> Option<KanjiNameCandidate> {
    let kanji = read_json_string(value, &["kanji", "name_kanji"]);
    if kanji.is_empty() {
        return None;
    }
    if kanji.chars().count() > 2 || kanji.chars().any(char::is_whitespace) {
        return None;
    }

    let reading_hiragana = read_json_string(value, &["reading_hiragana", "hiragana"]);
    let reading_romaji = read_json_string(value, &["reading_romaji", "romaji"]);
    let reason = read_json_string(value, &["reason"]);
    if reading_hiragana.is_empty() || reading_romaji.is_empty() || reason.is_empty() {
        return None;
    }

    Some(KanjiNameCandidate {
        kanji,
        reading_hiragana,
        reading_romaji,
        reason,
    })
}

fn read_json_string(value: &JsonValue, keys: &[&str]) -> String {
    for key in keys {
        if let Some(text) = value.get(*key).and_then(JsonValue::as_str) {
            let trimmed = text.trim();
            if !trimmed.is_empty() {
                return trimmed.to_owned();
            }
        }
    }
    String::new()
}

fn validate_create_order_request(request: CreateOrderRequest) -> Result<CreateOrderInput> {
    let idempotency_key_pattern =
        Regex::new(r"^[A-Za-z0-9_-]{8,128}$").expect("idempotency key regex must compile");
    let locale_pattern =
        Regex::new(r"^[a-z]{2,3}(-[a-z0-9]{2,8})*$").expect("locale regex must compile");

    let channel = request.channel.trim().to_lowercase();
    if channel != "app" && channel != "web" {
        bail!("channel must be one of app or web");
    }

    let locale = request.locale.trim().to_lowercase();
    if !locale_pattern.is_match(&locale) {
        bail!("locale must be a valid BCP-47 lowercase tag");
    }

    let idempotency_key = request.idempotency_key.trim().to_owned();
    if !idempotency_key_pattern.is_match(&idempotency_key) {
        bail!("idempotency_key must match ^[A-Za-z0-9_-]{{8,128}}$");
    }

    if !request.terms_agreed {
        bail!("terms_agreed must be true");
    }

    let line1 = request.seal.line1.trim().to_owned();
    validate_seal_line("seal.line1", &line1, 1, 2)?;

    let line2 = request.seal.line2.trim().to_owned();
    validate_seal_line("seal.line2", &line2, 0, 2)?;

    let shape = request.seal.shape.trim().to_lowercase();
    if shape != "square" && shape != "round" {
        bail!("seal.shape must be one of square or round");
    }

    let font_key = request.seal.font_key.trim().to_owned();
    if font_key.is_empty() {
        bail!("seal.font_key is required");
    }

    let material_key = request.material_key.trim().to_owned();
    if material_key.is_empty() {
        bail!("material_key is required");
    }

    let country_code = request.shipping.country_code.trim().to_uppercase();
    if country_code.chars().count() != 2 {
        bail!("shipping.country_code must be ISO alpha-2");
    }

    require_non_empty("shipping.recipient_name", &request.shipping.recipient_name)?;
    require_non_empty("shipping.phone", &request.shipping.phone)?;
    require_non_empty("shipping.postal_code", &request.shipping.postal_code)?;
    require_non_empty("shipping.state", &request.shipping.state)?;
    require_non_empty("shipping.city", &request.shipping.city)?;
    require_non_empty("shipping.address_line1", &request.shipping.address_line1)?;

    let email = request.contact.email.trim().to_owned();
    if email.is_empty() {
        bail!("contact.email is required");
    }
    if !is_valid_email(&email) {
        bail!("contact.email must be valid");
    }

    let preferred_locale = request.contact.preferred_locale.trim().to_lowercase();
    if !locale_pattern.is_match(&preferred_locale) {
        bail!("contact.preferred_locale must be a valid BCP-47 lowercase tag");
    }

    Ok(CreateOrderInput {
        channel,
        locale,
        idempotency_key,
        terms_agreed: request.terms_agreed,
        seal: SealInput {
            line1,
            line2,
            shape,
            font_key,
        },
        material_key,
        shipping: ShippingInput {
            country_code,
            recipient_name: request.shipping.recipient_name.trim().to_owned(),
            phone: request.shipping.phone.trim().to_owned(),
            postal_code: request.shipping.postal_code.trim().to_owned(),
            state: request.shipping.state.trim().to_owned(),
            city: request.shipping.city.trim().to_owned(),
            address_line1: request.shipping.address_line1.trim().to_owned(),
            address_line2: request.shipping.address_line2.trim().to_owned(),
        },
        contact: ContactInput {
            email,
            preferred_locale,
        },
    })
}

fn require_non_empty(field_name: &str, raw: &str) -> Result<()> {
    if raw.trim().is_empty() {
        bail!("{field_name} is required");
    }
    Ok(())
}

fn validate_seal_line(field_name: &str, value: &str, min_len: usize, max_len: usize) -> Result<()> {
    let length = value.chars().count();
    if length < min_len || length > max_len {
        bail!("{field_name} must be {min_len}-{max_len} characters");
    }
    if value.chars().any(char::is_whitespace) {
        bail!("{field_name} must not contain whitespace");
    }
    Ok(())
}

fn is_valid_email(email: &str) -> bool {
    let trimmed = email.trim();
    let mut parts = trimmed.split('@');
    let local = parts.next().unwrap_or_default();
    let domain = parts.next().unwrap_or_default();
    if local.is_empty() || domain.is_empty() || parts.next().is_some() {
        return false;
    }
    if domain.starts_with('.') || domain.ends_with('.') || !domain.contains('.') {
        return false;
    }
    true
}

fn resolve_localized(
    values: &HashMap<String, String>,
    requested_locale: &str,
    default_locale: &str,
) -> String {
    if let Some(value) = lookup_locale(values, requested_locale) {
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
                Some(key.to_owned())
            }
        })
        .collect::<Vec<_>>();
    keys.sort();

    keys.first()
        .and_then(|key| values.get(key))
        .map(|value| value.trim().to_owned())
        .unwrap_or_default()
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

fn parse_stripe_event(payload: &[u8]) -> Result<StripeWebhookEvent> {
    let env: StripeEventEnvelope =
        serde_json::from_slice(payload).context("failed to parse stripe event")?;

    let provider_event_id = env.id.trim().to_owned();
    let event_type = env.event_type.trim().to_owned();
    if provider_event_id.is_empty() || event_type.is_empty() {
        bail!("stripe event must include id and type");
    }

    let mut payment_intent_id = String::new();
    let mut order_id = String::new();

    if let Some(object) = env.data.object.as_object() {
        if let Some(id) = object.get("id").and_then(JsonValue::as_str)
            && id.trim().starts_with("pi_")
        {
            payment_intent_id = id.trim().to_owned();
        }
        if let Some(id) = object.get("payment_intent").and_then(JsonValue::as_str) {
            payment_intent_id = id.trim().to_owned();
        }

        if let Some(id) = object.get("order_id").and_then(JsonValue::as_str) {
            order_id = id.trim().to_owned();
        }

        if order_id.is_empty()
            && let Some(metadata) = object.get("metadata").and_then(JsonValue::as_object)
        {
            for key in ["order_id", "orderId", "orderID"] {
                if let Some(value) = metadata.get(key).and_then(JsonValue::as_str) {
                    let trimmed = value.trim();
                    if !trimmed.is_empty() {
                        order_id = trimmed.to_owned();
                        break;
                    }
                }
            }
        }
    }

    Ok(StripeWebhookEvent {
        provider_event_id,
        event_type,
        payment_intent_id,
        order_id,
    })
}

fn verify_stripe_signature(payload: &[u8], signature_header: &str, secret: &str) -> Result<()> {
    verify_stripe_signature_at(payload, signature_header, secret, Utc::now())
}

fn verify_stripe_signature_at(
    payload: &[u8],
    signature_header: &str,
    secret: &str,
    now: DateTime<Utc>,
) -> Result<()> {
    if secret.trim().is_empty() {
        return Ok(());
    }

    let signature = signature_header.trim();
    if signature.is_empty() {
        bail!("missing Stripe-Signature header");
    }

    let (timestamp, signatures) = parse_stripe_signature_header(signature)?;
    let event_time = DateTime::<Utc>::from_timestamp(timestamp, 0)
        .ok_or_else(|| anyhow!("invalid stripe signature timestamp"))?;

    let age = (now - event_time).num_seconds();
    if age.abs() > STRIPE_SIGNATURE_TOLERANCE_SECONDS {
        bail!("stripe signature timestamp is outside tolerance");
    }

    let signed_payload = format!("{}.{}", timestamp, String::from_utf8_lossy(payload));
    let mut mac =
        HmacSha256::new_from_slice(secret.as_bytes()).context("invalid signing secret")?;
    mac.update(signed_payload.as_bytes());
    let expected = mac.finalize().into_bytes();

    for candidate in signatures {
        let decoded = match hex::decode(candidate) {
            Ok(v) => v,
            Err(_) => continue,
        };
        if decoded.len() == expected.len() && decoded.eq(expected.as_slice()) {
            return Ok(());
        }
    }

    bail!("invalid stripe signature")
}

fn parse_stripe_signature_header(value: &str) -> Result<(i64, Vec<String>)> {
    let mut timestamp: Option<i64> = None;
    let mut signatures = Vec::new();

    for part in value
        .split(',')
        .map(str::trim)
        .filter(|part| !part.is_empty())
    {
        let mut segments = part.splitn(2, '=');
        let key = segments.next().unwrap_or_default().trim();
        let value = segments.next().unwrap_or_default().trim();
        if key == "t" {
            timestamp = Some(
                value
                    .parse::<i64>()
                    .context("invalid stripe signature timestamp")?,
            );
        } else if key == "v1" && !value.is_empty() {
            signatures.push(value.to_owned());
        }
    }

    let timestamp =
        timestamp.ok_or_else(|| anyhow!("stripe signature does not include timestamp"))?;
    if signatures.is_empty() {
        bail!("stripe signature does not include v1");
    }

    Ok((timestamp, signatures))
}

fn normalize_webhook_event(event: StripeWebhookEvent) -> StripeWebhookEvent {
    StripeWebhookEvent {
        provider_event_id: event.provider_event_id.trim().to_owned(),
        event_type: event.event_type.trim().to_owned(),
        payment_intent_id: event.payment_intent_id.trim().to_owned(),
        order_id: event.order_id.trim().to_owned(),
    }
}

fn stripe_transition(event_type: &str) -> (&'static str, &'static str, &'static str) {
    match event_type {
        "payment_intent.succeeded" => ("paid", "paid", "payment_paid"),
        "payment_intent.payment_failed" | "payment_intent.canceled" => {
            ("failed", "canceled", "payment_failed")
        }
        "charge.refunded" => ("refunded", "refunded", "payment_refunded"),
        _ => ("", "", "payment_event_recorded"),
    }
}

fn can_transition(current: &str, next: &str) -> bool {
    match current {
        "pending_payment" => matches!(next, "paid" | "canceled"),
        "paid" => matches!(next, "manufacturing" | "refunded"),
        "manufacturing" => matches!(next, "shipped" | "refunded"),
        "shipped" => matches!(next, "delivered" | "refunded"),
        _ => false,
    }
}

fn make_asset_url(bucket: &str, storage_path: &str) -> String {
    let trimmed_path = storage_path.trim().trim_start_matches('/');
    let trimmed_bucket = bucket.trim().trim_matches('/');
    if trimmed_path.is_empty() {
        return String::new();
    }
    if trimmed_bucket.is_empty() {
        return format!("/{trimmed_path}");
    }
    format!("https://storage.googleapis.com/{trimmed_bucket}/{trimmed_path}")
}

fn contains(values: &[String], value: &str) -> bool {
    values.iter().any(|item| item == value)
}

fn is_not_found(error: &FirebaseFirestoreError) -> bool {
    matches!(
        error,
        FirebaseFirestoreError::UnexpectedStatus { status, .. } if status.as_u16() == 404
    )
}

fn is_conflict(error: &FirebaseFirestoreError) -> bool {
    matches!(
        error,
        FirebaseFirestoreError::UnexpectedStatus { status, .. } if status.as_u16() == 409
    )
}

fn document_id(document: &Document) -> Option<String> {
    document
        .name
        .as_deref()
        .and_then(|name| name.rsplit('/').next())
        .map(ToOwned::to_owned)
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
                storage_path: read_string_field(&fields, "storage_path"),
                alt_i18n: read_string_map_field(&fields, "alt_i18n"),
                sort_order: read_int_field(&fields, "sort_order").unwrap_or_default(),
                is_primary: read_bool_field(&fields, "is_primary").unwrap_or(false),
                width: read_int_field(&fields, "width").unwrap_or_default(),
                height: read_int_field(&fields, "height").unwrap_or_default(),
            })
        })
        .collect::<Vec<_>>();

    photos.sort_by(|left, right| {
        left.sort_order
            .cmp(&right.sort_order)
            .then(left.asset_id.cmp(&right.asset_id))
    });
    photos
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

fn read_bool_field(data: &BTreeMap<String, JsonValue>, key: &str) -> Option<bool> {
    let value = data.get(key)?;
    if let Some(boolean_value) = value.get("booleanValue").and_then(JsonValue::as_bool) {
        return Some(boolean_value);
    }
    value.as_bool()
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

fn read_string_array_from_map(data: &BTreeMap<String, JsonValue>, key: &str) -> Vec<String> {
    read_array_field(data, key)
        .into_iter()
        .filter_map(|value| {
            value
                .get("stringValue")
                .and_then(JsonValue::as_str)
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(ToOwned::to_owned)
        })
        .collect::<Vec<_>>()
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
        .unwrap_or_default()
}

fn read_map_field(data: &BTreeMap<String, JsonValue>, key: &str) -> BTreeMap<String, JsonValue> {
    data.get(key)
        .and_then(|value| value.get("mapValue"))
        .and_then(|map_value| map_value.get("fields"))
        .and_then(JsonValue::as_object)
        .map(|fields| {
            fields
                .iter()
                .map(|(key, value)| (key.clone(), value.clone()))
                .collect::<BTreeMap<_, _>>()
        })
        .unwrap_or_default()
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

fn fs_string_map(values: &HashMap<String, String>) -> JsonValue {
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

fn btree_from_pairs(pairs: Vec<(&str, JsonValue)>) -> BTreeMap<String, JsonValue> {
    pairs
        .into_iter()
        .map(|(key, value)| (key.to_owned(), value))
        .collect::<BTreeMap<_, _>>()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resolve_localized_uses_fallback_order() {
        let mut values = HashMap::new();
        values.insert("ja".to_owned(), "柘植".to_owned());
        values.insert("en".to_owned(), "Boxwood".to_owned());

        assert_eq!(resolve_localized(&values, "en", "ja"), "Boxwood");
        assert_eq!(resolve_localized(&values, "fr", "en"), "Boxwood");
        assert_eq!(resolve_localized(&values, "fr", "ko"), "柘植");
    }

    #[test]
    fn validate_create_order_request_accepts_valid_payload() {
        let request = CreateOrderRequest {
            channel: "web".to_owned(),
            locale: "ja".to_owned(),
            idempotency_key: "demo_key_123".to_owned(),
            terms_agreed: true,
            seal: CreateOrderSealRequest {
                line1: "田中".to_owned(),
                line2: "太郎".to_owned(),
                shape: "square".to_owned(),
                font_key: "zen_maru_gothic".to_owned(),
            },
            material_key: "boxwood".to_owned(),
            shipping: CreateOrderShippingRequest {
                country_code: "jp".to_owned(),
                recipient_name: "田中 太郎".to_owned(),
                phone: "09000001111".to_owned(),
                postal_code: "1000001".to_owned(),
                state: "東京都".to_owned(),
                city: "千代田区".to_owned(),
                address_line1: "1-1-1".to_owned(),
                address_line2: "".to_owned(),
            },
            contact: CreateOrderContactRequest {
                email: "taro@example.com".to_owned(),
                preferred_locale: "ja".to_owned(),
            },
        };

        let input = validate_create_order_request(request).expect("request must be valid");
        assert_eq!(input.shipping.country_code, "JP");
    }

    #[test]
    fn validate_create_order_request_rejects_seal_whitespace() {
        let request = CreateOrderRequest {
            channel: "web".to_owned(),
            locale: "ja".to_owned(),
            idempotency_key: "demo_key_123".to_owned(),
            terms_agreed: true,
            seal: CreateOrderSealRequest {
                line1: "田 中".to_owned(),
                line2: "".to_owned(),
                shape: "square".to_owned(),
                font_key: "zen_maru_gothic".to_owned(),
            },
            material_key: "boxwood".to_owned(),
            shipping: CreateOrderShippingRequest {
                country_code: "JP".to_owned(),
                recipient_name: "田中 太郎".to_owned(),
                phone: "09000001111".to_owned(),
                postal_code: "1000001".to_owned(),
                state: "東京都".to_owned(),
                city: "千代田区".to_owned(),
                address_line1: "1-1-1".to_owned(),
                address_line2: "".to_owned(),
            },
            contact: CreateOrderContactRequest {
                email: "taro@example.com".to_owned(),
                preferred_locale: "ja".to_owned(),
            },
        };

        assert!(validate_create_order_request(request).is_err());
    }

    #[test]
    fn verify_stripe_signature_accepts_valid_signature() {
        let payload = br#"{"id":"evt_1","type":"payment_intent.succeeded","data":{"object":{"id":"pi_1","metadata":{"order_id":"order_1"}}}}"#;
        let secret = "whsec_test";
        let now = DateTime::from_timestamp(1_770_638_400, 0).expect("valid timestamp");
        let timestamp = now.timestamp();

        let signed_payload = format!("{timestamp}.{}", String::from_utf8_lossy(payload));
        let mut mac = HmacSha256::new_from_slice(secret.as_bytes()).expect("valid secret");
        mac.update(signed_payload.as_bytes());
        let signature = hex::encode(mac.finalize().into_bytes());
        let header = format!("t={timestamp},v1={signature}");

        assert!(verify_stripe_signature_at(payload, &header, secret, now).is_ok());
        assert!(verify_stripe_signature_at(payload, &header, "wrong", now).is_err());
    }

    #[test]
    fn parse_stripe_event_extracts_core_fields() {
        let payload = br#"{"id":"evt_1","type":"payment_intent.succeeded","data":{"object":{"id":"pi_1","metadata":{"order_id":"order_1"}}}}"#;

        let event = parse_stripe_event(payload).expect("payload must parse");
        assert_eq!(event.provider_event_id, "evt_1");
        assert_eq!(event.payment_intent_id, "pi_1");
        assert_eq!(event.order_id, "order_1");
    }

    #[test]
    fn validate_generate_kanji_candidates_request_accepts_defaults() {
        let request = GenerateKanjiCandidatesRequest {
            real_name: "Michael Smith".to_owned(),
            reason_language: None,
            count: None,
        };

        let input =
            validate_generate_kanji_candidates_request(request).expect("request must be valid");
        assert_eq!(input.reason_language, "en");
        assert_eq!(input.count, DEFAULT_KANJI_CANDIDATE_COUNT);
    }

    #[test]
    fn parse_kanji_candidates_from_gemini_text_accepts_markdown_json() {
        let payload = r#"
```json
{
  "candidates": [
    {
      "kanji": "蒼真",
      "reading_hiragana": "そうま",
      "reading_romaji": "soma",
      "reason": "Balanced and clear for seal engraving."
    },
    {
      "kanji": "悠花",
      "reading_hiragana": "ゆうか",
      "reading_romaji": "yuka",
      "reason": "Soft sound and elegant strokes."
    }
  ]
}
```
"#;

        let candidates =
            parse_kanji_candidates_from_gemini_text(payload, 5).expect("payload must parse");
        assert_eq!(candidates.len(), 2);
        assert_eq!(candidates[0].kanji, "蒼真");
        assert_eq!(candidates[0].reading_hiragana, "そうま");
        assert_eq!(candidates[0].reading_romaji, "soma");
    }
}
