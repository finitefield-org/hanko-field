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
    CommitRequest, CreateDocumentOptions, Document, FirebaseFirestoreClient,
    FirebaseFirestoreError, GetDocumentOptions, PatchDocumentOptions, RunQueryRequest,
};
use gcp_auth::{CustomServiceAccount, TokenProvider, provider};
use regex::Regex;
use serde::Deserialize;
use serde_json::{Value as JsonValue, json};
use sha2::{Digest, Sha256};
use stripe_sdk::{
    Event as StripeEvent, PostCheckoutSessionsRequest, StripeClient, webhook as stripe_webhook,
};
use tokio::net::TcpListener;
use uuid::Uuid;

const DATASTORE_SCOPE: &str = "https://www.googleapis.com/auth/datastore";
const MAX_REQUEST_BODY_BYTES: usize = 1 << 20;
const DEFAULT_PORT: &str = "3050";
const DEFAULT_LOCALE: &str = "ja";
const DEFAULT_CURRENCY: &str = "USD";
const DEFAULT_JA_CURRENCY: &str = "JPY";
const DEFAULT_STRIPE_CHECKOUT_SUCCESS_URL: &str =
    "http://127.0.0.1:3052/payment/success?session_id={CHECKOUT_SESSION_ID}";
const DEFAULT_STRIPE_CHECKOUT_CANCEL_URL: &str = "http://127.0.0.1:3052/payment/failure";
const DEFAULT_GEMINI_MODEL: &str = "gemini-2.5-flash-lite";
const DEFAULT_GEMINI_THINKING_BUDGET: i32 = 1024;
const DEFAULT_KANJI_CANDIDATE_COUNT: usize = 6;
const MAX_KANJI_CANDIDATE_COUNT: usize = 10;

#[derive(Debug, Clone)]
struct AppConfig {
    addr: String,
    firestore_project_id: String,
    storage_assets_bucket: String,
    stripe_api_key: String,
    stripe_webhook_secret: String,
    stripe_checkout_success_url: String,
    stripe_checkout_cancel_url: String,
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
    stripe_client: Option<StripeClient>,
    stripe_checkout: StripeCheckoutConfig,
    gemini: GeminiClientConfig,
    http_client: reqwest::Client,
}

#[derive(Debug, Clone)]
struct StripeCheckoutConfig {
    success_url: String,
    cancel_url: String,
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
    default_currency: String,
    currency_by_locale: HashMap<String, String>,
}

#[derive(Debug, Clone)]
struct Font {
    key: String,
    label: String,
    font_family: String,
    kanji_style: String,
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
    shape: String,
    photos: Vec<MaterialPhoto>,
    price_by_currency: HashMap<String, i64>,
    version: i64,
}

#[derive(Debug, Clone)]
struct StoneListingFacets {
    color_family: String,
    color_tags: Vec<String>,
    pattern_primary: String,
    pattern_tags: Vec<String>,
    stone_shape: String,
    translucency: String,
}

#[derive(Debug, Clone)]
struct StoneListing {
    key: String,
    listing_code: String,
    material_key: String,
    title_i18n: HashMap<String, String>,
    description_i18n: HashMap<String, String>,
    story_i18n: HashMap<String, String>,
    facets: StoneListingFacets,
    supported_seal_shapes: Vec<String>,
    photos: Vec<MaterialPhoto>,
    price_by_currency: HashMap<String, i64>,
    status: String,
    is_active: bool,
    sort_order: i64,
    version: i64,
}

#[derive(Debug, Clone)]
struct Country {
    code: String,
    label_i18n: HashMap<String, String>,
    shipping_fee_by_currency: HashMap<String, i64>,
    version: i64,
}

#[derive(Debug, Clone)]
struct CreateOrderResult {
    order_id: String,
    order_no: String,
    status: String,
    payment_status: String,
    fulfillment_status: String,
    total: i64,
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
    listing_id: Option<String>,
    material_key: Option<String>,
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
struct OrderCheckoutContext {
    order_id: String,
    order_locale: String,
    status: String,
    payment_status: String,
    listing_key: String,
    listing_label: String,
    listing_code: String,
    material_label: String,
    seal_shape: String,
    shipping_country_code: String,
    shipping_recipient_name: String,
    shipping_phone: String,
    shipping_postal_code: String,
    shipping_state: String,
    shipping_city: String,
    shipping_address_line1: String,
    shipping_address_line2: String,
    total: i64,
    currency: String,
    contact_email: String,
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

#[derive(Debug, Deserialize, Default)]
struct QueryStoneListings {
    locale: Option<String>,
    material_key: Option<String>,
    color_family: Option<String>,
    pattern_primary: Option<String>,
    stone_shape: Option<String>,
    seal_shape: Option<String>,
    status: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct GenerateKanjiCandidatesRequest {
    real_name: String,
    reason_language: Option<String>,
    gender: Option<String>,
    kanji_style: Option<String>,
    count: Option<usize>,
}

#[derive(Debug, Clone)]
struct GenerateKanjiCandidatesInput {
    real_name: String,
    reason_language: String,
    gender: CandidateGender,
    kanji_style: KanjiStyle,
    count: usize,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum CandidateGender {
    Unspecified,
    Male,
    Female,
}

impl CandidateGender {
    fn as_str(self) -> &'static str {
        match self {
            Self::Unspecified => "unspecified",
            Self::Male => "male",
            Self::Female => "female",
        }
    }

    fn prompt_instruction(self) -> &'static str {
        match self {
            Self::Unspecified => {
                "Gender preference: unspecified. Do not force masculine/feminine bias."
            }
            Self::Male => {
                "Gender preference: masculine. Prefer names with masculine impression while staying natural."
            }
            Self::Female => {
                "Gender preference: feminine. Prefer names with feminine impression while staying natural."
            }
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum KanjiStyle {
    Japanese,
    Chinese,
    Taiwanese,
}

impl KanjiStyle {
    fn as_str(self) -> &'static str {
        match self {
            Self::Japanese => "japanese",
            Self::Chinese => "chinese",
            Self::Taiwanese => "taiwanese",
        }
    }

    fn prompt_instruction(self) -> &'static str {
        match self {
            Self::Japanese => {
                "Style preference: Japanese style. Follow Japanese naming conventions and aesthetics. reading must be lowercase romaji."
            }
            Self::Chinese => {
                "Style preference: Chinese style. Follow modern Chinese naming conventions and aesthetics. reading must be lowercase Hanyu Pinyin without tone marks."
            }
            Self::Taiwanese => {
                "Style preference: Taiwanese style. Prefer Traditional Chinese naming conventions common in Taiwan. reading must be lowercase Hanyu Pinyin without tone marks."
            }
        }
    }
}

#[derive(Debug, Clone)]
struct KanjiNameCandidate {
    kanji: String,
    reading: String,
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
    listing_id: Option<String>,
    material_key: Option<String>,
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
#[serde(deny_unknown_fields)]
struct CreateStripeCheckoutSessionRequest {
    order_id: String,
    customer_email: Option<String>,
}

#[derive(Debug, Clone)]
struct CreateStripeCheckoutSessionInput {
    order_id: String,
    customer_email: String,
}

#[derive(Debug, Clone)]
struct CreateStripeCheckoutSessionResult {
    session_id: String,
    checkout_url: String,
    payment_intent_id: String,
}

#[derive(Debug, thiserror::Error)]
enum StoreError {
    #[error("unsupported locale")]
    UnsupportedLocale,
    #[error("invalid reference")]
    InvalidReference,
    #[error("inactive reference")]
    InactiveReference,
    #[error("material shape mismatch")]
    MaterialShapeMismatch,
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

    let stripe_client = if cfg.stripe_api_key.trim().is_empty() {
        None
    } else {
        Some(
            StripeClient::builder(cfg.stripe_api_key.trim().to_owned())
                .http_client(http_client.clone())
                .build()
                .context("failed to initialize stripe client")?,
        )
    };

    let state = AppState {
        store,
        storage_assets_bucket: cfg.storage_assets_bucket,
        stripe_webhook_secret: cfg.stripe_webhook_secret,
        stripe_client,
        stripe_checkout: StripeCheckoutConfig {
            success_url: cfg.stripe_checkout_success_url,
            cancel_url: cfg.stripe_checkout_cancel_url,
        },
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
        .route("/v1/stone-listings", get(handle_stone_listings))
        .route(
            "/v1/kanji-candidates",
            post(handle_generate_kanji_candidates),
        )
        .route("/v1/orders", post(handle_create_order))
        .route(
            "/v1/payments/stripe/checkout-session",
            post(handle_create_stripe_checkout_session),
        )
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
        .unwrap_or_else(|| "hanko-field-dev".to_owned());

    let stripe_api_key =
        first_non_empty(&[std::env::var("API_PSP_STRIPE_API_KEY").ok()]).unwrap_or_default();

    let stripe_webhook_secret =
        first_non_empty(&[std::env::var("API_PSP_STRIPE_WEBHOOK_SECRET").ok()]).unwrap_or_default();

    let stripe_checkout_success_url =
        first_non_empty(&[std::env::var("API_PSP_STRIPE_CHECKOUT_SUCCESS_URL").ok()])
            .unwrap_or_else(|| DEFAULT_STRIPE_CHECKOUT_SUCCESS_URL.to_owned());

    let stripe_checkout_cancel_url =
        first_non_empty(&[std::env::var("API_PSP_STRIPE_CHECKOUT_CANCEL_URL").ok()])
            .unwrap_or_else(|| DEFAULT_STRIPE_CHECKOUT_CANCEL_URL.to_owned());

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
        stripe_api_key,
        stripe_webhook_secret,
        stripe_checkout_success_url,
        stripe_checkout_cancel_url,
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
                "default_currency": cfg.default_currency,
                "currency_by_locale": cfg.currency_by_locale,
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
    let pricing_currency = resolve_pricing_currency(&cfg, &requested_locale);

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

    let stone_listings = match state.store.list_active_stone_listings().await {
        Ok(v) => v,
        Err(err) => {
            eprintln!("failed to load stone listings: {err:#}");
            return error_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal",
                "internal server error",
            );
        }
    };
    let stone_listing_resp = stone_listings
        .into_iter()
        .map(|listing| {
            stone_listing_response(
                &state.storage_assets_bucket,
                &requested_locale,
                &cfg.default_locale,
                &pricing_currency,
                listing,
            )
        })
        .collect::<Vec<_>>();

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
                "label": font.label,
                "font_family": font.font_family,
                "kanji_style": font.kanji_style,
                "version": font.version,
            })
        })
        .collect::<Vec<_>>();

    let material_resp = materials
        .into_iter()
        .map(|material| {
            let resolved_price = material_price_for_currency(&material, &pricing_currency);
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
                "shape": material.shape,
                "price": resolved_price,
                "price_by_currency": material.price_by_currency,
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
                "shipping_fee": country_shipping_fee_for_currency(&country, &pricing_currency),
                "shipping_fee_by_currency": country.shipping_fee_by_currency,
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
            "default_currency": cfg.default_currency,
            "currency_by_locale": cfg.currency_by_locale,
            "currency": pricing_currency,
            "fonts": font_resp,
            "materials": material_resp,
            "stone_listings": stone_listing_resp,
            "countries": country_resp,
        }),
    )
}

async fn handle_stone_listings(
    State(state): State<AppState>,
    Query(query): Query<QueryStoneListings>,
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
    let pricing_currency = resolve_pricing_currency(&cfg, &requested_locale);

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

    let stone_listings = match state.store.list_active_stone_listings().await {
        Ok(v) => v,
        Err(err) => {
            eprintln!("failed to load stone listings: {err:#}");
            return error_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal",
                "internal server error",
            );
        }
    };

    let requested_material_key = query.material_key.unwrap_or_default().trim().to_owned();
    let requested_color_family = query.color_family.unwrap_or_default().trim().to_lowercase();
    let requested_pattern_primary = query
        .pattern_primary
        .unwrap_or_default()
        .trim()
        .to_lowercase();
    let requested_stone_shape = query.stone_shape.unwrap_or_default().trim().to_lowercase();
    let requested_seal_shape = query.seal_shape.unwrap_or_default().trim().to_lowercase();
    let requested_status = query
        .status
        .unwrap_or_else(|| "published".to_owned())
        .trim()
        .to_lowercase();

    let stone_listings = stone_listings
        .into_iter()
        .filter(|listing| {
            if !requested_material_key.is_empty() && listing.material_key != requested_material_key
            {
                return false;
            }
            if !requested_color_family.is_empty()
                && listing.facets.color_family.to_lowercase() != requested_color_family
            {
                return false;
            }
            if !requested_pattern_primary.is_empty()
                && listing.facets.pattern_primary.to_lowercase() != requested_pattern_primary
            {
                return false;
            }
            if !requested_stone_shape.is_empty()
                && listing.facets.stone_shape.to_lowercase() != requested_stone_shape
            {
                return false;
            }
            if !requested_seal_shape.is_empty()
                && !listing
                    .supported_seal_shapes
                    .iter()
                    .any(|shape| shape.trim().to_lowercase() == requested_seal_shape)
            {
                return false;
            }
            if !requested_status.is_empty() && listing.status.to_lowercase() != requested_status {
                return false;
            }
            true
        })
        .map(|listing| {
            stone_listing_response(
                &state.storage_assets_bucket,
                &requested_locale,
                &cfg.default_locale,
                &pricing_currency,
                listing,
            )
        })
        .collect::<Vec<_>>();

    json_response(
        StatusCode::OK,
        json!({
            "locale": requested_locale,
            "currency": pricing_currency,
            "stone_listings": stone_listings,
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
            "gender": input.gender.as_str(),
            "kanji_style": input.kanji_style.as_str(),
            "candidates": candidates.into_iter().map(|candidate| {
                json!({
                    "kanji": candidate.kanji,
                    "reading": candidate.reading,
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
                        "total": result.total,
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
            "invalid font/material/listing/country",
        ),
        Err(StoreError::InactiveReference) => error_response(
            StatusCode::BAD_REQUEST,
            "inactive_reference",
            "inactive font/material/listing/country",
        ),
        Err(StoreError::MaterialShapeMismatch) => error_response(
            StatusCode::BAD_REQUEST,
            "material_shape_mismatch",
            "selected material does not support seal shape",
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

async fn handle_create_stripe_checkout_session(
    State(state): State<AppState>,
    body: Bytes,
) -> Response {
    if state.stripe_client.is_none() {
        return error_response(
            StatusCode::SERVICE_UNAVAILABLE,
            "stripe_not_configured",
            "stripe client is not configured",
        );
    }
    if state.stripe_checkout.success_url.trim().is_empty()
        || state.stripe_checkout.cancel_url.trim().is_empty()
    {
        return error_response(
            StatusCode::SERVICE_UNAVAILABLE,
            "stripe_not_configured",
            "stripe checkout urls are not configured",
        );
    }

    let request = match serde_json::from_slice::<CreateStripeCheckoutSessionRequest>(&body) {
        Ok(v) => v,
        Err(err) => {
            return error_response(
                StatusCode::BAD_REQUEST,
                "invalid_json",
                &format!("invalid JSON: {err}"),
            );
        }
    };

    let input = match validate_create_stripe_checkout_session_request(request) {
        Ok(v) => v,
        Err(err) => {
            return error_response(
                StatusCode::BAD_REQUEST,
                "validation_error",
                &err.to_string(),
            );
        }
    };

    let Some(order) = (match state
        .store
        .get_order_checkout_context(&input.order_id)
        .await
    {
        Ok(v) => v,
        Err(err) => {
            eprintln!("failed to load order for stripe checkout session: {err}");
            return error_response(
                StatusCode::INTERNAL_SERVER_ERROR,
                "internal",
                "internal server error",
            );
        }
    }) else {
        return error_response(StatusCode::NOT_FOUND, "order_not_found", "order not found");
    };

    if order.status != "pending_payment" || order.payment_status != "unpaid" {
        return error_response(
            StatusCode::CONFLICT,
            "order_not_payable",
            "order is not payable",
        );
    }
    if order.total <= 0 {
        return error_response(
            StatusCode::BAD_REQUEST,
            "invalid_order_total",
            "order total must be greater than zero",
        );
    }

    let customer_email = if input.customer_email.is_empty() {
        order.contact_email.clone()
    } else {
        input.customer_email.clone()
    };

    let session = match create_stripe_checkout_session(&state, &order, &customer_email).await {
        Ok(v) => v,
        Err(err) => {
            eprintln!("failed to create stripe checkout session: {err:#}");
            if let Err(rollback_err) = state
                .store
                .cancel_pending_order_and_release_listing(
                    &order.order_id,
                    order.listing_key.as_str(),
                )
                .await
            {
                eprintln!(
                    "failed to roll back reserved listing after stripe checkout failure: {rollback_err:#}"
                );
                return error_response(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "internal",
                    "internal server error",
                );
            }
            return error_response(
                StatusCode::BAD_GATEWAY,
                "stripe_checkout_failed",
                "failed to create stripe checkout session",
            );
        }
    };

    if let Err(err) = state
        .store
        .set_order_checkout_session(&order.order_id, &session.session_id)
        .await
    {
        eprintln!("failed to persist stripe checkout session id: {err}");
        if let Err(rollback_err) = state
            .store
            .cancel_pending_order_and_release_listing(
                &order.order_id,
                order.listing_key.as_str(),
            )
            .await
        {
            eprintln!(
                "failed to roll back reserved listing after persisting stripe checkout session id failed: {rollback_err:#}"
            );
        }
        return error_response(
            StatusCode::INTERNAL_SERVER_ERROR,
            "internal",
            "internal server error",
        );
    }

    json_response(
        StatusCode::CREATED,
        json!({
            "order_id": order.order_id,
            "session_id": session.session_id,
            "checkout_url": session.checkout_url,
            "payment_intent_id": session.payment_intent_id,
        }),
    )
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

    let sdk_event = if state.stripe_webhook_secret.trim().is_empty() {
        match serde_json::from_slice::<StripeEvent>(&body) {
            Ok(event) => event,
            Err(err) => {
                return error_response(
                    StatusCode::BAD_REQUEST,
                    "invalid_payload",
                    &err.to_string(),
                );
            }
        }
    } else {
        match stripe_webhook::construct_event(&body, signature, &state.stripe_webhook_secret) {
            Ok(event) => event,
            Err(stripe_webhook::StripeWebhookError::Json(err)) => {
                return error_response(
                    StatusCode::BAD_REQUEST,
                    "invalid_payload",
                    &err.to_string(),
                );
            }
            Err(err) => {
                return error_response(
                    StatusCode::UNAUTHORIZED,
                    "invalid_signature",
                    &err.to_string(),
                );
            }
        }
    };

    let event = match parse_stripe_event(sdk_event) {
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

fn firestore_client_from_access_token(access_token: &str) -> Result<FirebaseFirestoreClient> {
    Ok(FirebaseFirestoreClient::new(access_token.to_owned()))
}

impl FirestoreStore {
    async fn firestore_client(&self) -> Result<FirebaseFirestoreClient> {
        let access_token = self
            .token_provider
            .token(&[DATASTORE_SCOPE])
            .await
            .context("failed to acquire firestore access token")?;
        firestore_client_from_access_token(access_token.as_str())
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
                let default_currency = first_non_empty(&[
                    Some(read_string_field(&document.fields, "default_currency")),
                    Some(read_string_field(&document.fields, "currency")),
                ])
                .unwrap_or_default();
                let currency_by_locale =
                    read_string_map_field(&document.fields, "currency_by_locale");
                Ok(normalize_public_config(PublicConfig {
                    supported_locales: supported,
                    default_locale,
                    default_currency,
                    currency_by_locale,
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
            let label = resolve_font_label_field(&document.fields, &key);
            let mut kanji_style = read_string_field(&document.fields, "kanji_style");
            if kanji_style.is_empty() {
                kanji_style = read_string_field(&document.fields, "style");
            }
            let kanji_style = normalize_catalog_kanji_style(&kanji_style).to_owned();

            fonts.push(Font {
                key,
                label,
                font_family,
                kanji_style,
                version: read_int_field(&document.fields, "version").unwrap_or(1),
            });
        }

        Ok(fonts)
    }

    async fn list_active_materials(&self) -> Result<Vec<Material>> {
        let documents = self.query_active_documents("materials").await?;
        let mut materials = Vec::with_capacity(documents.len());

        for document in documents {
            let key = document_id(&document)
                .ok_or_else(|| anyhow!("materials document is missing name"))?;
            let price_by_currency = material_price_by_currency_from_fields(&document.fields);
            if price_by_currency.is_empty() {
                bail!("materials/{key} is missing price_by_currency");
            }

            let photos = read_material_photos(&document.fields);

            materials.push(Material {
                key,
                label_i18n: read_string_map_field(&document.fields, "label_i18n"),
                description_i18n: read_string_map_field(&document.fields, "description_i18n"),
                shape: read_material_shape(&document.fields),
                photos,
                price_by_currency,
                version: read_int_field(&document.fields, "version").unwrap_or(1),
            });
        }

        Ok(materials)
    }

    async fn list_active_stone_listings(&self) -> Result<Vec<StoneListing>> {
        let client = self.firestore_client().await?;
        let documents = self
            .run_documents_query(&client, "stone_listings", false, true)
            .await?;
        if documents.is_empty() {
            bail!("no stone_listings found in firestore");
        }
        let mut listings = Vec::with_capacity(documents.len());

        for document in documents {
            let key = document_id(&document)
                .ok_or_else(|| anyhow!("stone_listings document is missing name"))?;
            let is_active = read_bool_field(&document.fields, "is_active").unwrap_or(true);
            let status = read_string_field(&document.fields, "status");
            if !stone_listing_is_orderable(is_active, &status) {
                continue;
            }
            let price_by_currency = stone_listing_price_by_currency_from_fields(&document.fields);
            if price_by_currency.is_empty() {
                bail!("stone_listings/{key} is missing price_by_currency");
            }

            listings.push(stone_listing_from_fields(&key, &document.fields));
        }

        Ok(listings)
    }

    async fn list_active_countries(&self) -> Result<Vec<Country>> {
        let documents = self.query_active_documents("countries").await?;
        let mut countries = Vec::with_capacity(documents.len());

        for document in documents {
            let code = document_id(&document)
                .ok_or_else(|| anyhow!("countries document is missing name"))?;
            let shipping_fee_by_currency =
                country_shipping_fee_by_currency_from_fields(&document.fields);
            if shipping_fee_by_currency.is_empty() {
                bail!("countries/{code} is missing shipping_fee_by_currency");
            }

            countries.push(Country {
                code,
                label_i18n: read_string_map_field(&document.fields, "label_i18n"),
                shipping_fee_by_currency,
                version: read_int_field(&document.fields, "version").unwrap_or(1),
            });
        }

        Ok(countries)
    }

    async fn get_active_stone_listing(
        &self,
        client: &FirebaseFirestoreClient,
        key: &str,
    ) -> Result<StoneListing, StoreError> {
        let doc = self
            .get_orderable_stone_listing_document(client, key)
            .await?;
        Ok(stone_listing_from_fields(key, &doc.fields))
    }

    async fn get_orderable_stone_listing_document(
        &self,
        client: &FirebaseFirestoreClient,
        key: &str,
    ) -> Result<Document, StoreError> {
        let doc_name = format!("{}/stone_listings/{}", self.parent, key);
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
        let is_active = read_bool_field(&doc.fields, "is_active").unwrap_or(false);
        let status = read_string_field(&doc.fields, "status");
        if !stone_listing_is_orderable(is_active, &status) {
            return Err(StoreError::InactiveReference);
        }
        if stone_listing_price_by_currency_from_fields(&doc.fields).is_empty() {
            return Err(StoreError::Internal(anyhow!(
                "stone_listings/{key} is missing price_by_currency"
            )));
        }

        Ok(doc)
    }

    async fn query_active_documents(&self, collection: &str) -> Result<Vec<Document>> {
        let client = self.firestore_client().await?;
        let documents = self
            .run_documents_query(&client, collection, true, false)
            .await?;
        if documents.is_empty() {
            bail!("no active {collection} found in firestore");
        }

        Ok(documents)
    }

    async fn run_documents_query(
        &self,
        client: &FirebaseFirestoreClient,
        collection: &str,
        active_only: bool,
        sort_by_published_at: bool,
    ) -> Result<Vec<Document>> {
        let query = RunQueryRequest {
            structured_query: Some({
                let mut query = json!({
                    "from": [
                        { "collectionId": collection }
                    ],
                });
                if active_only {
                    query["where"] = json!({
                        "fieldFilter": {
                            "field": { "fieldPath": "is_active" },
                            "op": "EQUAL",
                            "value": { "booleanValue": true }
                        }
                    });
                }
                query
            }),
            ..RunQueryRequest::default()
        };

        let rows = client
            .run_query(&self.parent, &query)
            .await
            .with_context(|| format!("failed to load {collection}"))?;

        let mut documents = rows
            .into_iter()
            .filter_map(|row| row.document)
            .collect::<Vec<_>>();
        documents.sort_by(|left, right| {
            let left_sort_order = read_int_field(&left.fields, "sort_order").unwrap_or_default();
            let right_sort_order = read_int_field(&right.fields, "sort_order").unwrap_or_default();
            left_sort_order
                .cmp(&right_sort_order)
                .then_with(|| {
                    if sort_by_published_at {
                        let left_published_at = read_timestamp_field(&left.fields, "published_at")
                            .unwrap_or(DateTime::<Utc>::UNIX_EPOCH);
                        let right_published_at =
                            read_timestamp_field(&right.fields, "published_at")
                                .unwrap_or(DateTime::<Utc>::UNIX_EPOCH);
                        right_published_at
                            .cmp(&left_published_at)
                            .then_with(|| document_id(left).cmp(&document_id(right)))
                    } else {
                        document_id(left).cmp(&document_id(right))
                    }
                })
        });
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
        let pricing_currency = resolve_pricing_currency(&cfg, &normalized.locale);

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
        let listing_bundle = if let Some(listing_id) = normalized.listing_id.as_deref() {
            let listing_doc = self
                .get_orderable_stone_listing_document(&client, listing_id)
                .await?;
            let listing = stone_listing_from_fields(listing_id, &listing_doc.fields);
            Some((listing_id.to_owned(), listing_doc, listing))
        } else {
            None
        };
        let listing = listing_bundle
            .as_ref()
            .map(|(_, _, listing)| listing.clone());
        let material_key = if let Some(listing) = listing.as_ref() {
            if let Some(requested_key) = normalized.material_key.as_deref()
                && !requested_key.trim().is_empty()
                && requested_key.trim() != listing.material_key
            {
                return Err(StoreError::InvalidReference);
            }
            listing.material_key.clone()
        } else {
            normalized
                .material_key
                .clone()
                .ok_or(StoreError::InvalidReference)?
        };
        let material = self.get_active_material(&client, &material_key).await?;
        let country = self
            .get_active_country(&client, &normalized.shipping.country_code)
            .await?;
        let shape_supports = if let Some(listing) = listing.as_ref() {
            stone_listing_supports_seal_shape(listing, &normalized.seal.shape)
        } else {
            material_supports_shape(&material, &normalized.seal.shape)
        };
        if !shape_supports {
            return Err(StoreError::MaterialShapeMismatch);
        }

        let now = Utc::now();
        let subtotal = if let Some(listing) = listing.as_ref() {
            stone_listing_price_for_currency(listing, &pricing_currency)
        } else {
            material_price_for_currency(&material, &pricing_currency)
        };
        let shipping = country_shipping_fee_for_currency(&country, &pricing_currency);
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

        if let Some((listing_key, listing_doc, listing_snapshot)) = listing_bundle.as_ref() {
            let order_id = Uuid::new_v4().to_string();
            let order_doc = Document {
                name: None,
                fields: build_order_fields(
                    &normalized,
                    &font,
                    &material,
                    Some(listing_snapshot),
                    &country,
                    &order_no,
                    subtotal,
                    shipping,
                    tax,
                    discount,
                    total,
                    &pricing_currency,
                    now,
                ),
                ..Document::default()
            };
            let event_doc = Document {
                name: None,
                fields: btree_from_pairs(vec![
                    ("type", fs_string("order_created")),
                    ("actor_type", fs_string("system")),
                    (
                        "payload",
                        fs_map(btree_from_pairs(vec![
                            ("channel", fs_string(normalized.channel.clone())),
                            ("total", fs_int(total)),
                            ("currency", fs_string(pricing_currency.clone())),
                        ])),
                    ),
                    ("created_at", fs_timestamp(now)),
                ]),
                ..Document::default()
            };
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
            let listing_doc_name = format!("{}/stone_listings/{}", self.parent, listing_key);
            let listing_update_time = listing_doc.update_time.clone().ok_or_else(|| {
                StoreError::Internal(anyhow!(
                    "stone_listings/{listing_key} is missing update_time"
                ))
            })?;

            let commit_result = client
                .commit(
                    &self.parent,
                    &CommitRequest {
                        writes: vec![
                            json!({
                                "update": {
                                    "name": listing_doc_name,
                                    "fields": {
                                        "status": fs_string("reserved"),
                                        "version": fs_int(listing_snapshot.version + 1),
                                        "updated_at": fs_timestamp(now),
                                    }
                                },
                                "updateMask": {
                                    "fieldPaths": ["status", "version", "updated_at"]
                                },
                                "currentDocument": {
                                    "updateTime": listing_update_time
                                }
                            }),
                            json!({
                                "update": {
                                    "name": format!("{}/orders/{}", self.parent, order_id),
                                    "fields": order_doc.fields
                                },
                                "currentDocument": {
                                    "exists": false
                                }
                            }),
                            json!({
                                "update": {
                                    "name": format!("{}/orders/{}/events/{}", self.parent, order_id, Uuid::new_v4()),
                                    "fields": event_doc.fields
                                },
                                "currentDocument": {
                                    "exists": false
                                }
                            }),
                            json!({
                                "update": {
                                    "name": format!("{}/idempotency_keys/{}", self.parent, idempotency_id),
                                    "fields": idempotency_doc.fields
                                },
                                "currentDocument": {
                                    "exists": false
                                }
                            }),
                        ],
                        transaction: None,
                    },
                )
                .await;

            if let Err(err) = commit_result {
                if is_conflict(&err) || is_precondition_failed(&err) {
                    if let Some(result) = self
                        .try_idempotent_replay(&client, &idempotency_doc_name, &request_hash)
                        .await?
                    {
                        return Ok(result);
                    }
                    return Err(StoreError::InactiveReference);
                }
                return Err(StoreError::Internal(anyhow!(err)));
            }

            return Ok(CreateOrderResult {
                order_id,
                order_no,
                status: "pending_payment".to_owned(),
                payment_status: "unpaid".to_owned(),
                fulfillment_status: "pending".to_owned(),
                total,
                currency: pricing_currency,
                idempotent_replay: false,
            });
        }

        let order_doc = Document {
            name: None,
            fields: build_order_fields(
                &normalized,
                &font,
                &material,
                listing.as_ref(),
                &country,
                &order_no,
                subtotal,
                shipping,
                tax,
                discount,
                total,
                &pricing_currency,
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
                        ("total", fs_int(total)),
                        ("currency", fs_string(pricing_currency.clone())),
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
            total,
            currency: pricing_currency,
            idempotent_replay: false,
        })
    }

    async fn get_order_checkout_context(
        &self,
        order_id: &str,
    ) -> Result<Option<OrderCheckoutContext>, StoreError> {
        let client = self
            .firestore_client()
            .await
            .map_err(StoreError::Internal)?;
        let order_doc_name = format!("{}/orders/{}", self.parent, order_id);

        let order_doc = match client
            .get_document(&order_doc_name, &GetDocumentOptions::default())
            .await
        {
            Ok(doc) => doc,
            Err(err) if is_not_found(&err) => return Ok(None),
            Err(err) => return Err(StoreError::Internal(anyhow!(err))),
        };

        let payment = read_map_field(&order_doc.fields, "payment");
        let pricing = read_map_field(&order_doc.fields, "pricing");
        let contact = read_map_field(&order_doc.fields, "contact");
        let seal = read_map_field(&order_doc.fields, "seal");
        let material = read_map_field(&order_doc.fields, "material");
        let listing = read_map_field(&order_doc.fields, "listing");
        let shipping = read_map_field(&order_doc.fields, "shipping");
        let order_locale = read_string_field(&order_doc.fields, "locale");
        let resolved_order_locale = if order_locale.trim().is_empty() {
            DEFAULT_LOCALE.to_owned()
        } else {
            order_locale.trim().to_lowercase()
        };
        let material_label = resolve_localized(
            &read_string_map_field(&material, "label_i18n"),
            &resolved_order_locale,
            DEFAULT_LOCALE,
        );
        let fallback_material_label = read_string_field(&material, "label");
        let material_key = read_string_field(&material, "key");
        let listing_label = resolve_localized(
            &read_string_map_field(&listing, "title_i18n"),
            &resolved_order_locale,
            DEFAULT_LOCALE,
        );
        let fallback_listing_label = read_string_field(&listing, "title");
        let listing_code = read_string_field(&listing, "listing_code");
        let seal_shape = first_non_empty(&[
            Some(read_string_field(&seal, "shape")),
            Some(read_string_field(&material, "shape")),
        ])
        .unwrap_or_default();
        let resolved_material_label = first_non_empty(&[
            Some(material_label),
            Some(fallback_material_label),
            Some(material_key),
        ])
        .unwrap_or_default();

        Ok(Some(OrderCheckoutContext {
            order_id: order_id.to_owned(),
            order_locale: resolved_order_locale,
            status: read_string_field(&order_doc.fields, "status"),
            payment_status: read_string_field(&payment, "status"),
            listing_key: read_string_field(&listing, "key"),
            listing_label: first_non_empty(&[
                Some(listing_label),
                Some(fallback_listing_label),
                Some(listing_code.clone()),
            ])
            .unwrap_or_default(),
            listing_code,
            material_label: resolved_material_label,
            seal_shape,
            shipping_country_code: read_string_field(&shipping, "country_code"),
            shipping_recipient_name: read_string_field(&shipping, "recipient_name"),
            shipping_phone: read_string_field(&shipping, "phone"),
            shipping_postal_code: read_string_field(&shipping, "postal_code"),
            shipping_state: read_string_field(&shipping, "state"),
            shipping_city: read_string_field(&shipping, "city"),
            shipping_address_line1: read_string_field(&shipping, "address_line1"),
            shipping_address_line2: read_string_field(&shipping, "address_line2"),
            total: pricing_total(&pricing),
            currency: pricing_currency(&pricing),
            contact_email: read_string_field(&contact, "email"),
        }))
    }

    async fn set_order_checkout_session(
        &self,
        order_id: &str,
        session_id: &str,
    ) -> Result<(), StoreError> {
        let client = self
            .firestore_client()
            .await
            .map_err(StoreError::Internal)?;
        let order_doc_name = format!("{}/orders/{}", self.parent, order_id);

        let mut order_doc = client
            .get_document(&order_doc_name, &GetDocumentOptions::default())
            .await
            .map_err(|err| StoreError::Internal(anyhow!(err)))?;

        let mut payment = read_map_field(&order_doc.fields, "payment");
        payment.insert("provider".to_owned(), fs_string("stripe"));
        payment.insert(
            "checkout_session_id".to_owned(),
            fs_string(session_id.to_owned()),
        );
        order_doc
            .fields
            .insert("payment".to_owned(), fs_map(payment));
        order_doc
            .fields
            .insert("updated_at".to_owned(), fs_timestamp(Utc::now()));

        client
            .patch_document(
                &order_doc_name,
                &order_doc,
                &PatchDocumentOptions::default(),
            )
            .await
            .map_err(|err| StoreError::Internal(anyhow!(err)))?;

        Ok(())
    }

    async fn cancel_pending_order_and_release_listing(
        &self,
        order_id: &str,
        listing_key: &str,
    ) -> Result<(), StoreError> {
        let listing_key = listing_key.trim();
        if listing_key.is_empty() {
            return Ok(());
        }

        let client = self
            .firestore_client()
            .await
            .map_err(StoreError::Internal)?;
        let order_doc_name = format!("{}/orders/{}", self.parent, order_id);
        let listing_doc_name = format!("{}/stone_listings/{}", self.parent, listing_key);
        let now = Utc::now();

        let order_doc = client
            .get_document(&order_doc_name, &GetDocumentOptions::default())
            .await
            .map_err(|err| StoreError::Internal(anyhow!(err)))?;
        let order_update_time = order_doc.update_time.clone().ok_or_else(|| {
            StoreError::Internal(anyhow!(
                "orders/{order_id} is missing update_time"
            ))
        })?;
        let mut payment = read_map_field(&order_doc.fields, "payment");
        payment.insert("status".to_owned(), fs_string("failed"));

        let mut writes = vec![json!({
            "update": {
                "name": order_doc_name,
                "fields": {
                    "payment": fs_map(payment),
                    "status": fs_string("canceled"),
                    "status_updated_at": fs_timestamp(now),
                    "updated_at": fs_timestamp(now),
                }
            },
            "updateMask": {
                "fieldPaths": ["payment", "status", "status_updated_at", "updated_at"]
            },
            "currentDocument": {
                "updateTime": order_update_time
            }
        })];

        let listing_doc = client
            .get_document(&listing_doc_name, &GetDocumentOptions::default())
            .await
            .map_err(|err| StoreError::Internal(anyhow!(err)))?;
        let target_listing_status = stone_listing_status_after_order_status("canceled")
            .unwrap_or("published");
        let current_listing_status = read_string_field(&listing_doc.fields, "status");
        let current_published_at = read_timestamp_field(&listing_doc.fields, "published_at");
        if !current_listing_status
            .trim()
            .eq_ignore_ascii_case(target_listing_status)
            || (target_listing_status.eq_ignore_ascii_case("published")
                && current_published_at.is_none())
        {
            let listing_update_time = listing_doc.update_time.clone().ok_or_else(|| {
                StoreError::Internal(anyhow!(
                    "stone_listings/{listing_key} is missing update_time"
                ))
            })?;
            let listing_version =
                read_int_field(&listing_doc.fields, "version").unwrap_or_default();
            writes.push(json!({
                "update": {
                    "name": listing_doc_name,
                    "fields": {
                        "status": fs_string(target_listing_status),
                        "published_at": fs_timestamp(now),
                        "version": fs_int(listing_version + 1),
                        "updated_at": fs_timestamp(now),
                    }
                },
                "updateMask": {
                    "fieldPaths": ["status", "published_at", "version", "updated_at"]
                },
                "currentDocument": {
                    "updateTime": listing_update_time
                }
            }));
        }

        client
            .commit(
                &self.parent,
                &CommitRequest {
                    writes,
                    transaction: None,
                },
            )
            .await
            .map_err(|err| StoreError::Internal(anyhow!(err)))?;

        Ok(())
    }

    async fn update_stone_listing_status(
        &self,
        listing_key: &str,
        next_status: &str,
    ) -> Result<(), StoreError> {
        let listing_key = listing_key.trim();
        if listing_key.is_empty() {
            return Ok(());
        }

        let client = self
            .firestore_client()
            .await
            .map_err(StoreError::Internal)?;
        let listing_doc_name = format!("{}/stone_listings/{}", self.parent, listing_key);
        let mut listing_doc = client
            .get_document(&listing_doc_name, &GetDocumentOptions::default())
            .await
            .map_err(|err| StoreError::Internal(anyhow!(err)))?;

        let current_status = read_string_field(&listing_doc.fields, "status");
        let current_published_at = read_timestamp_field(&listing_doc.fields, "published_at");
        if current_status.trim().eq_ignore_ascii_case(next_status)
            && (!next_status.eq_ignore_ascii_case("published") || current_published_at.is_some())
        {
            return Ok(());
        }

        let listing_version = read_int_field(&listing_doc.fields, "version").unwrap_or_default();
        listing_doc
            .fields
            .insert("status".to_owned(), fs_string(next_status));
        if next_status.eq_ignore_ascii_case("published") {
            listing_doc
                .fields
                .insert("published_at".to_owned(), fs_timestamp(Utc::now()));
        }
        listing_doc
            .fields
            .insert("version".to_owned(), fs_int(listing_version + 1));
        listing_doc
            .fields
            .insert("updated_at".to_owned(), fs_timestamp(Utc::now()));

        client
            .patch_document(
                &listing_doc_name,
                &listing_doc,
                &PatchDocumentOptions::default(),
            )
            .await
            .map_err(|err| StoreError::Internal(anyhow!(err)))?;

        Ok(())
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
            total: pricing_total(&pricing),
            currency: pricing_currency(&pricing),
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
            label: resolve_font_label_field(&doc.fields, key),
            font_family: read_string_field(&doc.fields, "font_family"),
            kanji_style: normalize_catalog_kanji_style(
                &first_non_empty(&[
                    Some(read_string_field(&doc.fields, "kanji_style")),
                    Some(read_string_field(&doc.fields, "style")),
                ])
                .unwrap_or_default(),
            )
            .to_owned(),
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
            shape: read_material_shape(&doc.fields),
            photos: read_material_photos(&doc.fields),
            price_by_currency: material_price_by_currency_from_fields(&doc.fields),
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
            shipping_fee_by_currency: country_shipping_fee_by_currency_from_fields(&doc.fields),
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
            event_fields.insert("after_status".to_owned(), fs_string(&after_status));
        }

        if let Some(listing_status) = stone_listing_status_after_order_status(&after_status) {
            let listing = read_map_field(&order_doc.fields, "listing");
            let listing_key = read_string_field(&listing, "key");
            if !listing_key.is_empty() {
                self.update_stone_listing_status(&listing_key, listing_status)
                    .await?;
            }
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
    listing: Option<&StoneListing>,
    country: &Country,
    order_no: &str,
    subtotal: i64,
    shipping: i64,
    tax: i64,
    discount: i64,
    total: i64,
    currency: &str,
    now: DateTime<Utc>,
) -> BTreeMap<String, JsonValue> {
    let pricing_currency =
        normalize_currency_code(currency).unwrap_or_else(|| DEFAULT_CURRENCY.to_owned());

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
                ("font_label", fs_string(font.label.clone())),
                ("font_version", fs_int(font.version)),
            ])),
        ),
        (
            "material",
            fs_map(btree_from_pairs(vec![
                ("key", fs_string(material.key.clone())),
                ("label_i18n", fs_string_map(&material.label_i18n)),
                ("shape", fs_string(material.shape.clone())),
                ("unit_price", fs_int(subtotal)),
                ("version", fs_int(material.version)),
            ])),
        ),
        (
            "listing",
            fs_map(stone_listing_snapshot_fields(listing, subtotal)),
        ),
        (
            "shipping",
            fs_map(btree_from_pairs(vec![
                ("country_code", fs_string(country.code.clone())),
                ("country_label_i18n", fs_string_map(&country.label_i18n)),
                ("country_version", fs_int(country.version)),
                ("fee", fs_int(shipping)),
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
                ("subtotal", fs_int(subtotal)),
                ("shipping", fs_int(shipping)),
                ("tax", fs_int(tax)),
                ("discount", fs_int(discount)),
                ("total", fs_int(total)),
                ("currency", fs_string(pricing_currency)),
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
    let mut currency_by_locale = HashMap::new();
    currency_by_locale.insert("ja".to_owned(), DEFAULT_JA_CURRENCY.to_owned());
    currency_by_locale.insert("en".to_owned(), DEFAULT_CURRENCY.to_owned());

    PublicConfig {
        supported_locales: vec!["ja".to_owned(), "en".to_owned()],
        default_locale: DEFAULT_LOCALE.to_owned(),
        default_currency: DEFAULT_CURRENCY.to_owned(),
        currency_by_locale,
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

    let default_currency = normalize_currency_code(&cfg.default_currency)
        .unwrap_or_else(|| DEFAULT_CURRENCY.to_owned());

    let mut currency_by_locale = HashMap::new();
    for (locale, currency) in cfg.currency_by_locale {
        let locale = locale.trim().to_lowercase();
        if locale.is_empty() || !contains(&normalized, &locale) {
            continue;
        }
        let Some(currency) = normalize_currency_code(&currency) else {
            continue;
        };
        currency_by_locale.insert(locale, currency);
    }
    for locale in &normalized {
        let fallback_currency = if locale == DEFAULT_LOCALE {
            DEFAULT_JA_CURRENCY.to_owned()
        } else {
            default_currency.clone()
        };
        currency_by_locale
            .entry(locale.clone())
            .or_insert(fallback_currency);
    }

    PublicConfig {
        supported_locales: normalized,
        default_locale,
        default_currency,
        currency_by_locale,
    }
}

fn normalize_currency_code(raw: &str) -> Option<String> {
    let value = raw.trim().to_uppercase();
    if value.len() != 3 || !value.chars().all(|ch| ch.is_ascii_alphabetic()) {
        return None;
    }
    Some(value)
}

fn resolve_currency_for_locale(cfg: &PublicConfig, locale: &str) -> String {
    if let Some(value) = lookup_locale(&cfg.currency_by_locale, locale)
        && let Some(currency) = normalize_currency_code(&value)
    {
        return currency;
    }
    if let Some(value) = lookup_locale(&cfg.currency_by_locale, &cfg.default_locale)
        && let Some(currency) = normalize_currency_code(&value)
    {
        return currency;
    }
    cfg.default_currency.clone()
}

fn resolve_pricing_currency(cfg: &PublicConfig, locale: &str) -> String {
    resolve_currency_for_locale(cfg, locale)
}

fn material_price_for_currency(material: &Material, currency: &str) -> i64 {
    resolve_amount_for_currency(&material.price_by_currency, currency)
}

fn stone_listing_price_for_currency(listing: &StoneListing, currency: &str) -> i64 {
    resolve_amount_for_currency(&listing.price_by_currency, currency)
}

fn stone_listing_is_published(status: &str) -> bool {
    status.trim().eq_ignore_ascii_case("published")
}

fn stone_listing_is_orderable(is_active: bool, status: &str) -> bool {
    is_active && stone_listing_is_published(status)
}

fn country_shipping_fee_for_currency(country: &Country, currency: &str) -> i64 {
    resolve_amount_for_currency(&country.shipping_fee_by_currency, currency)
}

fn material_supports_shape(material: &Material, shape: &str) -> bool {
    matches!(
        material.key.as_str(),
        "rose_quartz" | "lapis_lazuli" | "jade"
    ) || material.shape == shape
}

fn stone_listing_supports_seal_shape(listing: &StoneListing, shape: &str) -> bool {
    if listing.supported_seal_shapes.is_empty() {
        return true;
    }

    let normalized_shape = shape.trim().to_lowercase();
    listing
        .supported_seal_shapes
        .iter()
        .any(|supported| supported.trim().to_lowercase() == normalized_shape)
}

fn resolve_amount_for_currency(values: &HashMap<String, i64>, currency: &str) -> i64 {
    if let Some(amount) =
        normalize_currency_code(currency).and_then(|code| values.get(&code).copied())
    {
        return amount.max(0);
    }

    if let Some(amount) = values.get("USD").copied() {
        return amount.max(0);
    }
    if let Some(amount) = values.get("JPY").copied() {
        return amount.max(0);
    }

    let mut fallback_keys = values.keys().cloned().collect::<Vec<_>>();
    fallback_keys.sort();
    for key in fallback_keys {
        if let Some(amount) = values.get(&key).copied() {
            return amount.max(0);
        }
    }

    0
}

fn material_price_by_currency_from_fields(
    data: &BTreeMap<String, JsonValue>,
) -> HashMap<String, i64> {
    normalize_currency_amount_map(read_int_map_field(data, "price_by_currency"))
}

fn stone_listing_price_by_currency_from_fields(
    data: &BTreeMap<String, JsonValue>,
) -> HashMap<String, i64> {
    normalize_currency_amount_map(read_int_map_field(data, "price_by_currency"))
}

fn country_shipping_fee_by_currency_from_fields(
    data: &BTreeMap<String, JsonValue>,
) -> HashMap<String, i64> {
    normalize_currency_amount_map(read_int_map_field(data, "shipping_fee_by_currency"))
}

fn normalize_currency_amount_map(values: HashMap<String, i64>) -> HashMap<String, i64> {
    let mut normalized = HashMap::new();
    for (key, amount) in values {
        if let Some(currency) = normalize_currency_code(&key) {
            normalized.insert(currency, amount.max(0));
        }
    }
    normalized
}

fn normalize_create_order_input(input: CreateOrderInput) -> CreateOrderInput {
    let listing_id = input
        .listing_id
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned);
    let material_key = input
        .material_key
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned);

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
        listing_id,
        material_key,
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
        "listing_id": input.listing_id.clone(),
        "material_key": input.material_key.clone(),
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

    let gender = parse_candidate_gender(request.gender.as_deref())?;
    let kanji_style = parse_kanji_style(request.kanji_style.as_deref())?;

    let count = request.count.unwrap_or(DEFAULT_KANJI_CANDIDATE_COUNT);
    if count == 0 || count > MAX_KANJI_CANDIDATE_COUNT {
        bail!("count must be in range 1-{}", MAX_KANJI_CANDIDATE_COUNT);
    }

    Ok(GenerateKanjiCandidatesInput {
        real_name,
        reason_language,
        gender,
        kanji_style,
        count,
    })
}

fn parse_candidate_gender(raw: Option<&str>) -> Result<CandidateGender> {
    let normalized = raw.unwrap_or("unspecified").trim().to_lowercase();
    if normalized.is_empty() || normalized == "unspecified" || normalized == "none" {
        return Ok(CandidateGender::Unspecified);
    }
    if normalized == "male" {
        return Ok(CandidateGender::Male);
    }
    if normalized == "female" {
        return Ok(CandidateGender::Female);
    }
    bail!("gender must be one of unspecified, male, female")
}

fn parse_kanji_style(raw: Option<&str>) -> Result<KanjiStyle> {
    let normalized = raw.unwrap_or("japanese").trim().to_lowercase();
    if normalized.is_empty()
        || normalized == "japanese"
        || normalized == "japan"
        || normalized == "jp"
    {
        return Ok(KanjiStyle::Japanese);
    }
    if normalized == "chinese" || normalized == "china" || normalized == "cn" {
        return Ok(KanjiStyle::Chinese);
    }
    if normalized == "taiwanese" || normalized == "taiwan" || normalized == "tw" {
        return Ok(KanjiStyle::Taiwanese);
    }
    bail!("kanji_style must be one of japanese, chinese, taiwanese")
}

fn normalize_catalog_kanji_style(raw: &str) -> &'static str {
    let normalized = raw.trim().to_lowercase();
    match normalized.as_str() {
        "chinese" | "china" | "cn" => "chinese",
        "taiwanese" | "taiwan" | "tw" => "taiwanese",
        _ => "japanese",
    }
}

fn stone_listing_from_fields(key: &str, data: &BTreeMap<String, JsonValue>) -> StoneListing {
    let facets_data = read_map_field(data, "facets");
    let mut title_i18n = read_string_map_field(data, "title_i18n");
    if title_i18n.is_empty() {
        title_i18n = read_string_map_field(data, "label_i18n");
        if title_i18n.is_empty() {
            let legacy_title = read_string_field(data, "title");
            if !legacy_title.is_empty() {
                title_i18n.insert("ja".to_owned(), legacy_title);
            }
        }
    }
    let mut description_i18n = read_string_map_field(data, "description_i18n");
    if description_i18n.is_empty() {
        let legacy_description = read_string_field(data, "description");
        if !legacy_description.is_empty() {
            description_i18n.insert("ja".to_owned(), legacy_description);
        }
    }
    let story_i18n = read_string_map_field(data, "story_i18n");
    let mut supported_seal_shapes = read_string_array_field(data, "supported_seal_shapes");
    if supported_seal_shapes.is_empty() {
        let fallback_shape = first_non_empty(&[
            Some(read_string_field(data, "seal_shape")),
            Some(read_string_field(data, "shape")),
        ])
        .unwrap_or_default();
        if !fallback_shape.is_empty() {
            supported_seal_shapes.push(normalize_catalog_shape(&fallback_shape).to_owned());
        }
    }

    StoneListing {
        key: key.to_owned(),
        listing_code: first_non_empty(&[
            Some(read_string_field(data, "listing_code")),
            Some(key.to_owned()),
        ])
        .unwrap_or_else(|| key.to_owned()),
        material_key: first_non_empty(&[
            Some(read_string_field(data, "material_key")),
            Some(read_string_field(data, "material")),
        ])
        .unwrap_or_default(),
        title_i18n,
        description_i18n,
        story_i18n,
        facets: StoneListingFacets {
            color_family: first_non_empty(&[
                Some(read_string_field(&facets_data, "color_family")),
                Some(read_string_field(data, "color_family")),
            ])
            .unwrap_or_default(),
            color_tags: read_string_array_field(&facets_data, "color_tags"),
            pattern_primary: first_non_empty(&[
                Some(read_string_field(&facets_data, "pattern_primary")),
                Some(read_string_field(data, "pattern_primary")),
            ])
            .unwrap_or_default(),
            pattern_tags: read_string_array_field(&facets_data, "pattern_tags"),
            stone_shape: first_non_empty(&[
                Some(read_string_field(&facets_data, "stone_shape")),
                Some(read_string_field(data, "stone_shape")),
            ])
            .map(|shape| normalize_catalog_shape(&shape).to_owned())
            .unwrap_or_default(),
            translucency: first_non_empty(&[
                Some(read_string_field(&facets_data, "translucency")),
                Some(read_string_field(data, "translucency")),
            ])
            .unwrap_or_default(),
        },
        supported_seal_shapes,
        photos: read_material_photos(data),
        price_by_currency: stone_listing_price_by_currency_from_fields(data),
        status: first_non_empty(&[
            Some(read_string_field(data, "status")),
            Some("published".to_owned()),
        ])
        .unwrap_or_else(|| "published".to_owned()),
        is_active: read_bool_field(data, "is_active").unwrap_or(true),
        sort_order: read_int_field(data, "sort_order").unwrap_or_default(),
        version: read_int_field(data, "version").unwrap_or(1),
    }
}

fn stone_listing_response(
    storage_assets_bucket: &str,
    requested_locale: &str,
    default_locale: &str,
    pricing_currency: &str,
    listing: StoneListing,
) -> JsonValue {
    let price = stone_listing_price_for_currency(&listing, pricing_currency);
    let title = resolve_localized(&listing.title_i18n, requested_locale, default_locale);
    let description =
        resolve_localized(&listing.description_i18n, requested_locale, default_locale);
    let story = resolve_localized(&listing.story_i18n, requested_locale, default_locale);
    let photos = listing
        .photos
        .into_iter()
        .map(|photo| {
            json!({
                "asset_id": photo.asset_id,
                "asset_url": make_asset_url(storage_assets_bucket, &photo.storage_path),
                "storage_path": photo.storage_path,
                "alt": resolve_localized(&photo.alt_i18n, requested_locale, default_locale),
                "sort_order": photo.sort_order,
                "is_primary": photo.is_primary,
                "width": photo.width,
                "height": photo.height,
            })
        })
        .collect::<Vec<_>>();

    json!({
        "key": listing.key,
        "listing_code": listing.listing_code,
        "material_key": listing.material_key,
        "title": title,
        "description": description,
        "story": story,
        "facets": {
            "color_family": listing.facets.color_family,
            "color_tags": listing.facets.color_tags,
            "pattern_primary": listing.facets.pattern_primary,
            "pattern_tags": listing.facets.pattern_tags,
            "stone_shape": listing.facets.stone_shape,
            "translucency": listing.facets.translucency,
        },
        "supported_seal_shapes": listing.supported_seal_shapes,
        "price": price,
        "price_by_currency": listing.price_by_currency,
        "status": listing.status,
        "is_active": listing.is_active,
        "sort_order": listing.sort_order,
        "version": listing.version,
        "photos": photos,
    })
}

fn stone_listing_snapshot_fields(
    listing: Option<&StoneListing>,
    unit_price: i64,
) -> BTreeMap<String, JsonValue> {
    let Some(listing) = listing else {
        return BTreeMap::new();
    };

    let mut fields = btree_from_pairs(vec![
        ("key", fs_string(listing.key.clone())),
        ("listing_code", fs_string(listing.listing_code.clone())),
        ("material_key", fs_string(listing.material_key.clone())),
        ("title_i18n", fs_string_map(&listing.title_i18n)),
        ("description_i18n", fs_string_map(&listing.description_i18n)),
        ("story_i18n", fs_string_map(&listing.story_i18n)),
        (
            "supported_seal_shapes",
            fs_string_array(&listing.supported_seal_shapes),
        ),
        ("unit_price", fs_int(unit_price)),
        ("version", fs_int(listing.version)),
    ]);

    fields.insert(
        "facets".to_owned(),
        fs_map(btree_from_pairs(vec![
            (
                "color_family",
                fs_string(listing.facets.color_family.clone()),
            ),
            ("color_tags", fs_string_array(&listing.facets.color_tags)),
            (
                "pattern_primary",
                fs_string(listing.facets.pattern_primary.clone()),
            ),
            (
                "pattern_tags",
                fs_string_array(&listing.facets.pattern_tags),
            ),
            ("stone_shape", fs_string(listing.facets.stone_shape.clone())),
            (
                "translucency",
                fs_string(listing.facets.translucency.clone()),
            ),
        ])),
    );
    fields.insert("photos".to_owned(), fs_material_photos(&listing.photos));
    fields.insert(
        "price_by_currency".to_owned(),
        fs_int_map(&listing.price_by_currency),
    );
    fields.insert("status".to_owned(), fs_string(listing.status.clone()));
    fields.insert("is_active".to_owned(), fs_bool(listing.is_active));
    fields.insert("sort_order".to_owned(), fs_int(listing.sort_order));

    fields
}

async fn generate_kanji_candidates_with_gemini(
    state: &AppState,
    input: &GenerateKanjiCandidatesInput,
) -> Result<Vec<KanjiNameCandidate>> {
    let request_body = build_kanji_candidates_request_body(input);

    let endpoint = format!(
        "{}/v1beta/models/{}:generateContent",
        state.gemini.base_url.trim_end_matches('/'),
        state.gemini.model.trim()
    );

    let response = state
        .http_client
        .post(endpoint)
        .query(&[("key", state.gemini.api_key.as_str())])
        .json(&request_body)
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

fn build_kanji_candidates_request_body(input: &GenerateKanjiCandidatesInput) -> JsonValue {
    json!({
        "contents": [
            {
                "role": "user",
                "parts": [
                    {
                        "text": build_kanji_candidates_prompt(input),
                    }
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.4,
            "responseMimeType": "application/json",
            "responseJsonSchema": build_kanji_candidates_response_schema(input.count),
            "thinkingConfig": {
                "thinkingBudget": DEFAULT_GEMINI_THINKING_BUDGET,
            }
        }
    })
}

fn build_kanji_candidates_response_schema(max_count: usize) -> JsonValue {
    json!({
        "type": "object",
        "additionalProperties": false,
        "properties": {
            "candidates": {
                "type": "array",
                "minItems": 1,
                "maxItems": max_count,
                "items": {
                    "type": "object",
                    "additionalProperties": false,
                    "properties": {
                        "kanji": {
                            "type": "string",
                            "description": "1-2 CJK Han characters suitable for a seal.",
                        },
                        "reading": {
                            "type": "string",
                            "description": "Lowercase romaji for Japanese style or lowercase Hanyu Pinyin without tone marks for Chinese/Taiwanese styles.",
                        },
                        "reason": {
                            "type": "string",
                            "description": "Why this Kanji name was chosen.",
                        },
                    },
                    "required": ["kanji", "reading", "reason"],
                },
            },
        },
        "required": ["candidates"],
    })
}

fn build_kanji_candidates_prompt(input: &GenerateKanjiCandidatesInput) -> String {
    let gender_instruction = input.gender.prompt_instruction();
    let style_instruction = input.kanji_style.prompt_instruction();
    let reason_language = reason_language_label(&input.reason_language);
    format!(
        "Generate {} unique Kanji name candidates for a hanko seal.\n\
Input name: \"{}\"\n\
{}\n\
{}\n\
Think through the name fit internally before answering. Consider balance, seal suitability, stroke shape, and pronunciation, but do not reveal your chain of thought.\n\
For each candidate, return these fields:\n\
- kanji: 1-2 CJK Han characters suitable for a seal (no spaces)\n\
- reading: lowercase romaji for japanese style, lowercase Hanyu Pinyin without tone marks for chinese/taiwanese styles\n\
- reason: why this Kanji name was chosen, written in {}\n\
Return only JSON (no markdown, no explanation) in this exact shape:\n\
{{\"candidates\":[{{\"kanji\":\"\",\"reading\":\"\",\"reason\":\"\"}}]}}",
        input.count, input.real_name, gender_instruction, style_instruction, reason_language
    )
}

fn reason_language_label(raw: &str) -> &'static str {
    match raw.trim().to_lowercase().as_str() {
        "ja" | "ja-jp" | "japanese" => "Japanese",
        "en" | "en-us" | "english" => "English",
        _ => "English",
    }
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

    let reading = read_json_string(value, &["reading", "reading_romaji", "romaji"]);
    let reason = read_json_string(value, &["reason"]);
    if reading.is_empty() || reason.is_empty() {
        return None;
    }

    Some(KanjiNameCandidate {
        kanji,
        reading,
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

fn validate_create_stripe_checkout_session_request(
    request: CreateStripeCheckoutSessionRequest,
) -> Result<CreateStripeCheckoutSessionInput> {
    let order_id = request.order_id.trim().to_owned();
    if order_id.is_empty() {
        bail!("order_id is required");
    }

    let customer_email = request.customer_email.unwrap_or_default().trim().to_owned();
    if !customer_email.is_empty() && !is_valid_email(&customer_email) {
        bail!("customer_email must be valid");
    }

    Ok(CreateStripeCheckoutSessionInput {
        order_id,
        customer_email,
    })
}

async fn create_stripe_checkout_session(
    state: &AppState,
    order: &OrderCheckoutContext,
    customer_email: &str,
) -> Result<CreateStripeCheckoutSessionResult> {
    let stripe_client = state
        .stripe_client
        .as_ref()
        .ok_or_else(|| anyhow!("stripe client is not configured"))?;

    let product_name = build_checkout_product_name(order);
    let checkout_currency = stripe_checkout_currency(&order.currency);
    let success_url = append_query_params(
        &state.stripe_checkout.success_url,
        &[
            ("order_id", order.order_id.as_str()),
            ("lang", order.order_locale.as_str()),
        ],
    );
    let cancel_url = append_query_params(
        &state.stripe_checkout.cancel_url,
        &[
            ("order_id", order.order_id.as_str()),
            ("lang", order.order_locale.as_str()),
        ],
    );

    let mut body = json!({
        "mode": "payment",
        "success_url": success_url,
        "cancel_url": cancel_url,
        "line_items": [
            {
                "quantity": 1,
                "price_data": {
                    "currency": checkout_currency,
                    "unit_amount": order.total,
                    "product_data": {
                        "name": product_name,
                    },
                },
            }
        ],
        "metadata": {
            "order_id": order.order_id.clone(),
        },
        "payment_intent_data": {
            "metadata": {
                "order_id": order.order_id.clone(),
            },
        },
    });

    if !customer_email.trim().is_empty() {
        body["customer_email"] = JsonValue::String(customer_email.trim().to_owned());
    }
    if let Some(shipping) = build_payment_intent_shipping(order) {
        body["payment_intent_data"]["shipping"] = shipping;
    }

    let response = stripe_client
        .post_checkout_sessions(
            PostCheckoutSessionsRequest::new()
                .with_idempotency_key(format!("checkout_session_{}", order.order_id))
                .with_body(body),
        )
        .await
        .context("failed to request stripe checkout session")?;

    if response.status < 200 || response.status >= 300 {
        let response_body = serde_json::to_string(&response.body)
            .unwrap_or_else(|_| "<unable to serialize response body>".to_owned());
        bail!(
            "stripe checkout session request failed status={} body={}",
            response.status,
            response_body
        );
    }

    let payload = response.body;

    let session_id = payload.id.trim().to_owned();
    if session_id.is_empty() {
        bail!("stripe checkout session response is missing id");
    }
    let checkout_url = payload.url.unwrap_or_default().trim().to_owned();
    if checkout_url.is_empty() {
        bail!("stripe checkout session response is missing url");
    }

    let payment_intent_id = payload
        .payment_intent
        .as_ref()
        .and_then(stripe_payment_intent_id)
        .unwrap_or_default();

    Ok(CreateStripeCheckoutSessionResult {
        session_id,
        checkout_url,
        payment_intent_id,
    })
}

fn append_query_params(base_url: &str, params: &[(&str, &str)]) -> String {
    let mut url = base_url.trim().to_owned();
    let mut first_param = !url.contains('?') || url.ends_with('?') || url.ends_with('&');

    for (key, value) in params {
        let value = value.trim();
        if value.is_empty() {
            continue;
        }

        if first_param {
            first_param = false;
            if !url.ends_with('?') && !url.ends_with('&') {
                url.push(if url.contains('?') { '&' } else { '?' });
            }
        } else {
            url.push('&');
        }

        url.push_str(key);
        url.push('=');
        url.push_str(value);
    }

    url
}

fn build_checkout_product_name(order: &OrderCheckoutContext) -> String {
    let listing_label = if order.listing_label.trim().is_empty() {
        order.material_label.trim()
    } else {
        order.listing_label.trim()
    };
    if is_japanese_locale(&order.order_locale) {
        let shape_label = checkout_shape_label_ja(&order.seal_shape);
        return format!(
            "宝石印鑑 ({}、{})",
            display_or_dash(listing_label),
            display_or_dash(shape_label),
        );
    }

    let shape_label = checkout_shape_label_en(&order.seal_shape);
    format!(
        "Stone seal ({}; {})",
        display_or_dash(listing_label),
        display_or_dash(shape_label),
    )
}

fn is_japanese_locale(locale: &str) -> bool {
    locale.trim().to_lowercase().starts_with("ja")
}

fn checkout_shape_label_ja(shape: &str) -> &str {
    match shape.trim().to_lowercase().as_str() {
        "round" => "丸",
        "square" => "角",
        _ => "",
    }
}

fn checkout_shape_label_en(shape: &str) -> &str {
    match shape.trim().to_lowercase().as_str() {
        "round" => "circle",
        "square" => "square",
        _ => "",
    }
}

fn build_payment_intent_shipping(order: &OrderCheckoutContext) -> Option<JsonValue> {
    let country = order.shipping_country_code.trim().to_uppercase();
    let recipient_name = order.shipping_recipient_name.trim();
    let postal_code = order.shipping_postal_code.trim();
    let city = order.shipping_city.trim();
    let line1 = order.shipping_address_line1.trim();

    // Stripe shipping requires core address fields.
    if country.is_empty()
        || recipient_name.is_empty()
        || postal_code.is_empty()
        || city.is_empty()
        || line1.is_empty()
    {
        return None;
    }

    let mut address = serde_json::Map::new();
    address.insert("country".to_owned(), JsonValue::String(country));
    address.insert(
        "postal_code".to_owned(),
        JsonValue::String(postal_code.to_owned()),
    );
    address.insert("city".to_owned(), JsonValue::String(city.to_owned()));
    address.insert("line1".to_owned(), JsonValue::String(line1.to_owned()));

    let state = order.shipping_state.trim();
    if !state.is_empty() {
        address.insert("state".to_owned(), JsonValue::String(state.to_owned()));
    }

    let line2 = order.shipping_address_line2.trim();
    if !line2.is_empty() {
        address.insert("line2".to_owned(), JsonValue::String(line2.to_owned()));
    }

    let mut shipping = serde_json::Map::new();
    shipping.insert(
        "name".to_owned(),
        JsonValue::String(recipient_name.to_owned()),
    );
    shipping.insert("address".to_owned(), JsonValue::Object(address));

    let phone = order.shipping_phone.trim();
    if !phone.is_empty() {
        shipping.insert("phone".to_owned(), JsonValue::String(phone.to_owned()));
    }

    Some(JsonValue::Object(shipping))
}

fn display_or_dash(value: &str) -> &str {
    if value.is_empty() { "-" } else { value }
}

fn pricing_currency(pricing: &BTreeMap<String, JsonValue>) -> String {
    normalize_currency_code(&read_string_field(pricing, "currency"))
        .unwrap_or_else(|| DEFAULT_CURRENCY.to_owned())
}

fn pricing_total(pricing: &BTreeMap<String, JsonValue>) -> i64 {
    read_int_field(pricing, "total").unwrap_or_default()
}

fn stripe_checkout_currency(currency: &str) -> String {
    normalize_currency_code(currency)
        .unwrap_or_else(|| DEFAULT_CURRENCY.to_owned())
        .to_lowercase()
}

fn stripe_payment_intent_id(value: &JsonValue) -> Option<String> {
    if let Some(id) = value.as_str() {
        let trimmed = id.trim();
        if !trimmed.is_empty() {
            return Some(trimmed.to_owned());
        }
    }

    value
        .as_object()
        .and_then(|object| object.get("id"))
        .and_then(JsonValue::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
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

    let listing_id = request.listing_id.unwrap_or_default().trim().to_owned();
    let listing_id = if listing_id.is_empty() {
        None
    } else {
        Some(listing_id)
    };

    let material_key = request.material_key.unwrap_or_default().trim().to_owned();
    let material_key = if material_key.is_empty() {
        None
    } else {
        Some(material_key)
    };

    if listing_id.is_none() && material_key.is_none() {
        bail!("listing_id or material_key is required");
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
        listing_id,
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

fn resolve_font_label_field(data: &BTreeMap<String, JsonValue>, fallback: &str) -> String {
    let label = read_string_field(data, "label");
    if !label.is_empty() {
        return label;
    }

    let localized = resolve_localized(&read_string_map_field(data, "label_i18n"), "ja", "ja");
    if !localized.is_empty() {
        return localized;
    }

    fallback.trim().to_owned()
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

fn parse_stripe_event(event: StripeEvent) -> Result<StripeWebhookEvent> {
    let provider_event_id = event.id.trim().to_owned();
    let event_type = event.param_type.trim().to_owned();
    if provider_event_id.is_empty() || event_type.is_empty() {
        bail!("stripe event must include id and type");
    }

    let mut payment_intent_id = String::new();
    let mut order_id = String::new();

    if let Some(object) = event.data.object.as_object() {
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

fn stone_listing_status_after_order_status(status: &str) -> Option<&'static str> {
    match status {
        "paid" => Some("sold"),
        "canceled" => Some("published"),
        _ => None,
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

fn is_precondition_failed(error: &FirebaseFirestoreError) -> bool {
    matches!(
        error,
        FirebaseFirestoreError::UnexpectedStatus { status, .. } if status.as_u16() == 412
    )
}

fn document_id(document: &Document) -> Option<String> {
    document
        .name
        .as_deref()
        .and_then(|name| name.rsplit('/').next())
        .map(ToOwned::to_owned)
}

fn normalize_material_shape(raw: &str) -> &'static str {
    match raw.trim().to_ascii_lowercase().as_str() {
        "round" => "round",
        _ => "square",
    }
}

fn normalize_catalog_shape(raw: &str) -> &'static str {
    match raw.trim().to_ascii_lowercase().as_str() {
        "round" => "round",
        "square" => "square",
        "oval" | "ellipse" | "elliptical" => "oval",
        _ => "square",
    }
}

fn read_material_shape(data: &BTreeMap<String, JsonValue>) -> String {
    normalize_material_shape(&read_string_field(data, "shape")).to_owned()
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

fn read_int_map_field(data: &BTreeMap<String, JsonValue>, key: &str) -> HashMap<String, i64> {
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
    for (currency, amount_value) in fields {
        let mut container = BTreeMap::new();
        container.insert("amount".to_owned(), amount_value.clone());
        if let Some(amount) = read_int_field(&container, "amount") {
            result.insert(currency.trim().to_owned(), amount);
        }
    }

    result
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

fn read_string_array_field(data: &BTreeMap<String, JsonValue>, key: &str) -> Vec<String> {
    read_array_field(data, key)
        .into_iter()
        .filter_map(|value| {
            value
                .get("stringValue")
                .and_then(JsonValue::as_str)
                .or_else(|| value.as_str())
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(ToOwned::to_owned)
        })
        .collect::<Vec<_>>()
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

fn fs_int_map(values: &HashMap<String, i64>) -> JsonValue {
    let mut keys = values.keys().cloned().collect::<Vec<_>>();
    keys.sort();
    let mut fields = BTreeMap::new();
    for key in keys {
        if let Some(value) = values.get(&key) {
            fields.insert(key, fs_int((*value).max(0)));
        }
    }
    fs_map(fields)
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

fn fs_string_array(values: &[String]) -> JsonValue {
    fs_array(values.iter().cloned().map(fs_string).collect::<Vec<_>>())
}

fn fs_material_photos(photos: &[MaterialPhoto]) -> JsonValue {
    fs_array(
        photos
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
            .collect::<Vec<_>>(),
    )
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
        values.insert("ja".to_owned(), "翡翠".to_owned());
        values.insert("en".to_owned(), "Jade".to_owned());

        assert_eq!(resolve_localized(&values, "en", "ja"), "Jade");
        assert_eq!(resolve_localized(&values, "fr", "en"), "Jade");
        assert_eq!(resolve_localized(&values, "fr", "ko"), "翡翠");
    }

    #[test]
    fn default_public_config_sets_ja_to_jpy() {
        let cfg = default_public_config();
        assert_eq!(
            cfg.currency_by_locale.get("ja").map(String::as_str),
            Some("JPY")
        );
        assert_eq!(
            cfg.currency_by_locale.get("en").map(String::as_str),
            Some("USD")
        );
    }

    #[test]
    fn stone_listing_status_helper_requires_published() {
        assert!(stone_listing_is_published("published"));
        assert!(stone_listing_is_published(" Published "));
        assert!(!stone_listing_is_published("draft"));
    }

    #[test]
    fn stone_listing_orderable_helper_requires_active_and_published() {
        assert!(stone_listing_is_orderable(true, "published"));
        assert!(stone_listing_is_orderable(true, " Published "));
        assert!(!stone_listing_is_orderable(true, "draft"));
        assert!(!stone_listing_is_orderable(false, "published"));
    }

    #[test]
    fn stone_listing_status_follows_paid_and_canceled_orders() {
        assert_eq!(stone_listing_status_after_order_status("paid"), Some("sold"));
        assert_eq!(
            stone_listing_status_after_order_status("canceled"),
            Some("published")
        );
        assert_eq!(stone_listing_status_after_order_status("refunded"), None);
    }

    #[test]
    fn resolve_currency_for_locale_uses_locale_map_and_default() {
        let mut currency_by_locale = HashMap::new();
        currency_by_locale.insert("ja".to_owned(), "JPY".to_owned());
        currency_by_locale.insert("en".to_owned(), "USD".to_owned());

        let cfg = PublicConfig {
            supported_locales: vec!["ja".to_owned(), "en".to_owned()],
            default_locale: "ja".to_owned(),
            default_currency: "USD".to_owned(),
            currency_by_locale,
        };

        assert_eq!(resolve_currency_for_locale(&cfg, "ja"), "JPY");
        assert_eq!(resolve_currency_for_locale(&cfg, "ja-jp"), "JPY");
        assert_eq!(resolve_currency_for_locale(&cfg, "fr"), "JPY");
    }

    #[test]
    fn resolve_pricing_currency_uses_locale_currency() {
        let mut currency_by_locale = HashMap::new();
        currency_by_locale.insert("ja".to_owned(), "JPY".to_owned());
        currency_by_locale.insert("en".to_owned(), "USD".to_owned());

        let cfg = PublicConfig {
            supported_locales: vec!["ja".to_owned(), "en".to_owned()],
            default_locale: "ja".to_owned(),
            default_currency: "USD".to_owned(),
            currency_by_locale,
        };

        assert_eq!(resolve_pricing_currency(&cfg, "ja"), "JPY");
        assert_eq!(resolve_pricing_currency(&cfg, "en"), "USD");
        assert_eq!(resolve_pricing_currency(&cfg, "ja-jp"), "JPY");
    }

    #[test]
    fn stripe_checkout_currency_normalizes_iso_code() {
        assert_eq!(stripe_checkout_currency("usd"), "usd");
        assert_eq!(stripe_checkout_currency(" JpY "), "jpy");
        assert_eq!(stripe_checkout_currency(""), "usd");
    }

    #[test]
    fn material_price_for_currency_uses_currency_specific_field() {
        let material = Material {
            key: "jade".to_owned(),
            label_i18n: HashMap::new(),
            description_i18n: HashMap::new(),
            shape: "square".to_owned(),
            photos: Vec::new(),
            price_by_currency: HashMap::from([
                ("USD".to_owned(), 88500),
                ("JPY".to_owned(), 150000),
            ]),
            version: 1,
        };

        assert_eq!(material_price_for_currency(&material, "USD"), 88500);
        assert_eq!(material_price_for_currency(&material, "JPY"), 150000);
    }

    #[test]
    fn material_supports_shape_allows_gemstones_for_both_shapes() {
        let material = Material {
            key: "jade".to_owned(),
            label_i18n: HashMap::new(),
            description_i18n: HashMap::new(),
            shape: "square".to_owned(),
            photos: Vec::new(),
            price_by_currency: HashMap::from([
                ("USD".to_owned(), 88500),
                ("JPY".to_owned(), 150000),
            ]),
            version: 1,
        };

        assert!(material_supports_shape(&material, "square"));
        assert!(material_supports_shape(&material, "round"));
    }

    #[test]
    fn country_shipping_fee_for_currency_uses_currency_specific_field() {
        let country = Country {
            code: "JP".to_owned(),
            label_i18n: HashMap::new(),
            shipping_fee_by_currency: HashMap::from([
                ("USD".to_owned(), 600),
                ("JPY".to_owned(), 800),
            ]),
            version: 1,
        };

        assert_eq!(country_shipping_fee_for_currency(&country, "USD"), 600);
        assert_eq!(country_shipping_fee_for_currency(&country, "JPY"), 800);
    }

    #[test]
    fn pricing_total_reads_neutral_key_only() {
        let pricing_neutral = btree_from_pairs(vec![("total", fs_int(1234))]);
        assert_eq!(pricing_total(&pricing_neutral), 1234);
    }

    #[test]
    fn build_checkout_product_name_uses_japanese_format_for_ja_locale() {
        let order = OrderCheckoutContext {
            order_id: "order_1".to_owned(),
            order_locale: "ja".to_owned(),
            status: "pending_payment".to_owned(),
            payment_status: "unpaid".to_owned(),
            listing_key: String::new(),
            listing_label: String::new(),
            listing_code: String::new(),
            material_label: "翡翠".to_owned(),
            seal_shape: "square".to_owned(),
            shipping_country_code: "JP".to_owned(),
            shipping_recipient_name: "田中 太郎".to_owned(),
            shipping_phone: "09000001111".to_owned(),
            shipping_postal_code: "1000001".to_owned(),
            shipping_state: "東京都".to_owned(),
            shipping_city: "千代田区".to_owned(),
            shipping_address_line1: "1-1-1".to_owned(),
            shipping_address_line2: "テストビル101".to_owned(),
            total: 12345,
            currency: DEFAULT_CURRENCY.to_owned(),
            contact_email: "buyer@example.com".to_owned(),
        };

        assert_eq!(build_checkout_product_name(&order), "宝石印鑑 (翡翠、角)");
    }

    #[test]
    fn build_checkout_product_name_uses_english_format_for_non_ja_locale() {
        let order = OrderCheckoutContext {
            order_id: "order_1".to_owned(),
            order_locale: "en".to_owned(),
            status: "pending_payment".to_owned(),
            payment_status: "unpaid".to_owned(),
            listing_key: String::new(),
            listing_label: String::new(),
            listing_code: String::new(),
            material_label: "Jade".to_owned(),
            seal_shape: "round".to_owned(),
            shipping_country_code: "US".to_owned(),
            shipping_recipient_name: "John Doe".to_owned(),
            shipping_phone: "5551234567".to_owned(),
            shipping_postal_code: "10001".to_owned(),
            shipping_state: "NY".to_owned(),
            shipping_city: "New York".to_owned(),
            shipping_address_line1: "1 Main St".to_owned(),
            shipping_address_line2: "Suite 101".to_owned(),
            total: 12345,
            currency: DEFAULT_CURRENCY.to_owned(),
            contact_email: "buyer@example.com".to_owned(),
        };

        assert_eq!(
            build_checkout_product_name(&order),
            "Stone seal (Jade; circle)"
        );
    }

    #[test]
    fn build_payment_intent_shipping_includes_address_and_phone() {
        let order = OrderCheckoutContext {
            order_id: "order_1".to_owned(),
            order_locale: "ja".to_owned(),
            status: "pending_payment".to_owned(),
            payment_status: "unpaid".to_owned(),
            listing_key: String::new(),
            listing_label: String::new(),
            listing_code: String::new(),
            material_label: "翡翠".to_owned(),
            seal_shape: "round".to_owned(),
            shipping_country_code: "jp".to_owned(),
            shipping_recipient_name: "田中 太郎".to_owned(),
            shipping_phone: "09000001111".to_owned(),
            shipping_postal_code: "1000001".to_owned(),
            shipping_state: "東京都".to_owned(),
            shipping_city: "千代田区".to_owned(),
            shipping_address_line1: "1-1-1".to_owned(),
            shipping_address_line2: "テストビル101".to_owned(),
            total: 12345,
            currency: DEFAULT_CURRENCY.to_owned(),
            contact_email: "buyer@example.com".to_owned(),
        };

        let shipping = build_payment_intent_shipping(&order).expect("shipping must be present");
        let shipping_obj = shipping.as_object().expect("shipping must be object");
        let address = shipping_obj
            .get("address")
            .and_then(JsonValue::as_object)
            .expect("address must be object");

        assert_eq!(
            shipping_obj.get("name").and_then(JsonValue::as_str),
            Some("田中 太郎")
        );
        assert_eq!(
            shipping_obj.get("phone").and_then(JsonValue::as_str),
            Some("09000001111")
        );
        assert_eq!(
            address.get("country").and_then(JsonValue::as_str),
            Some("JP")
        );
        assert_eq!(
            address.get("line1").and_then(JsonValue::as_str),
            Some("1-1-1")
        );
        assert_eq!(
            address.get("line2").and_then(JsonValue::as_str),
            Some("テストビル101")
        );
    }

    #[test]
    fn build_payment_intent_shipping_returns_none_when_address_is_missing() {
        let order = OrderCheckoutContext {
            order_id: "order_1".to_owned(),
            order_locale: "ja".to_owned(),
            status: "pending_payment".to_owned(),
            payment_status: "unpaid".to_owned(),
            listing_key: String::new(),
            listing_label: String::new(),
            listing_code: String::new(),
            material_label: "翡翠".to_owned(),
            seal_shape: "round".to_owned(),
            shipping_country_code: "JP".to_owned(),
            shipping_recipient_name: "田中 太郎".to_owned(),
            shipping_phone: "09000001111".to_owned(),
            shipping_postal_code: "".to_owned(),
            shipping_state: "東京都".to_owned(),
            shipping_city: "千代田区".to_owned(),
            shipping_address_line1: "1-1-1".to_owned(),
            shipping_address_line2: "".to_owned(),
            total: 12345,
            currency: DEFAULT_CURRENCY.to_owned(),
            contact_email: "buyer@example.com".to_owned(),
        };

        assert!(build_payment_intent_shipping(&order).is_none());
    }

    #[test]
    fn append_query_params_preserves_existing_query_string() {
        let url = append_query_params(
            "https://example.com/payment/success?session_id={CHECKOUT_SESSION_ID}",
            &[("order_id", "order_1"), ("lang", "ja")],
        );

        assert_eq!(
            url,
            "https://example.com/payment/success?session_id={CHECKOUT_SESSION_ID}&order_id=order_1&lang=ja"
        );
    }

    #[test]
    fn append_query_params_adds_query_string_when_missing() {
        let url = append_query_params(
            "https://example.com/payment/failure",
            &[("order_id", "order_1"), ("lang", "en")],
        );

        assert_eq!(
            url,
            "https://example.com/payment/failure?order_id=order_1&lang=en"
        );
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
            listing_id: None,
            material_key: Some("jade".to_owned()),
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
            listing_id: None,
            material_key: Some("jade".to_owned()),
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
    fn validate_create_stripe_checkout_session_request_accepts_valid_payload() {
        let request = CreateStripeCheckoutSessionRequest {
            order_id: "order_1".to_owned(),
            customer_email: Some("buyer@example.com".to_owned()),
        };

        let input = validate_create_stripe_checkout_session_request(request)
            .expect("request must be valid");
        assert_eq!(input.order_id, "order_1");
        assert_eq!(input.customer_email, "buyer@example.com");
    }

    #[test]
    fn validate_create_stripe_checkout_session_request_rejects_invalid_email() {
        let request = CreateStripeCheckoutSessionRequest {
            order_id: "order_1".to_owned(),
            customer_email: Some("invalid".to_owned()),
        };

        assert!(validate_create_stripe_checkout_session_request(request).is_err());
    }

    #[test]
    fn stripe_webhook_sdk_rejects_outdated_signature_timestamp() {
        let payload = br#"{"id":"evt_1","type":"payment_intent.succeeded","data":{"object":{"id":"pi_1","metadata":{"order_id":"order_1"}}}}"#;
        let error = stripe_webhook::construct_event(payload, "t=1700000000,v1=00", "whsec_test")
            .expect_err("signature timestamp must be rejected");
        assert!(matches!(
            error,
            stripe_webhook::StripeWebhookError::TimestampOutsideTolerance
        ));
    }

    #[test]
    fn parse_stripe_event_extracts_core_fields() {
        let payload = br#"{"id":"evt_1","type":"payment_intent.succeeded","created":1770638400,"livemode":false,"object":"event","pending_webhooks":1,"data":{"object":{"id":"pi_1","metadata":{"order_id":"order_1"}}}}"#;
        let sdk_event =
            serde_json::from_slice::<StripeEvent>(payload).expect("payload must parse as event");
        let event = parse_stripe_event(sdk_event).expect("event must map");
        assert_eq!(event.provider_event_id, "evt_1");
        assert_eq!(event.payment_intent_id, "pi_1");
        assert_eq!(event.order_id, "order_1");
    }

    #[test]
    fn validate_generate_kanji_candidates_request_accepts_defaults() {
        let request = GenerateKanjiCandidatesRequest {
            real_name: "Michael Smith".to_owned(),
            reason_language: None,
            gender: None,
            kanji_style: None,
            count: None,
        };

        let input =
            validate_generate_kanji_candidates_request(request).expect("request must be valid");
        assert_eq!(input.reason_language, "en");
        assert_eq!(input.gender, CandidateGender::Unspecified);
        assert_eq!(input.kanji_style, KanjiStyle::Japanese);
        assert_eq!(input.count, DEFAULT_KANJI_CANDIDATE_COUNT);
    }

    #[test]
    fn validate_generate_kanji_candidates_request_accepts_gender() {
        let request = GenerateKanjiCandidatesRequest {
            real_name: "John".to_owned(),
            reason_language: Some("en".to_owned()),
            gender: Some("male".to_owned()),
            kanji_style: Some("chinese".to_owned()),
            count: Some(3),
        };

        let input =
            validate_generate_kanji_candidates_request(request).expect("request must be valid");
        assert_eq!(input.gender, CandidateGender::Male);
        assert_eq!(input.kanji_style, KanjiStyle::Chinese);
        assert_eq!(input.count, 3);
    }

    #[test]
    fn validate_generate_kanji_candidates_request_rejects_unknown_style() {
        let request = GenerateKanjiCandidatesRequest {
            real_name: "John".to_owned(),
            reason_language: Some("en".to_owned()),
            gender: Some("male".to_owned()),
            kanji_style: Some("korean".to_owned()),
            count: Some(3),
        };

        let err = validate_generate_kanji_candidates_request(request)
            .expect_err("request must fail for unknown style");
        assert!(
            err.to_string()
                .contains("kanji_style must be one of japanese, chinese, taiwanese")
        );
    }

    #[test]
    fn parse_kanji_candidates_from_gemini_text_accepts_markdown_json() {
        let payload = r#"
```json
{
  "candidates": [
    {
      "kanji": "蒼真",
      "reading": "soma",
      "reason": "Balanced and clear for seal engraving."
    },
    {
      "kanji": "悠花",
      "reading": "yuka",
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
        assert_eq!(candidates[0].reading, "soma");
    }

    #[test]
    fn build_kanji_candidates_prompt_uses_human_language_names() {
        let input = GenerateKanjiCandidatesInput {
            real_name: "山田 太郎".to_owned(),
            reason_language: "ja".to_owned(),
            gender: CandidateGender::Male,
            kanji_style: KanjiStyle::Japanese,
            count: 6,
        };

        let prompt = build_kanji_candidates_prompt(&input);
        assert!(prompt.contains("written in Japanese"));
        assert!(!prompt.contains("written in ja"));
        assert!(prompt.contains("Think through the name fit internally"));
    }

    #[test]
    fn build_kanji_candidates_request_body_enables_thinking_and_schema() {
        let input = GenerateKanjiCandidatesInput {
            real_name: "山田 太郎".to_owned(),
            reason_language: "en".to_owned(),
            gender: CandidateGender::Unspecified,
            kanji_style: KanjiStyle::Chinese,
            count: 4,
        };

        let body = build_kanji_candidates_request_body(&input);
        assert_eq!(
            body["generationConfig"]["thinkingConfig"]["thinkingBudget"],
            json!(DEFAULT_GEMINI_THINKING_BUDGET)
        );
        assert_eq!(
            body["generationConfig"]["responseMimeType"],
            json!("application/json")
        );
        assert_eq!(body["generationConfig"]["temperature"], json!(0.4));
        assert_eq!(
            body["generationConfig"]["responseJsonSchema"]["properties"]["candidates"]["maxItems"],
            json!(4)
        );
        assert_eq!(
            body["generationConfig"]["responseJsonSchema"]["properties"]["candidates"]["items"]["required"],
            json!(["kanji", "reading", "reason"])
        );
    }
}
