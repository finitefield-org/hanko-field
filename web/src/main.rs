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
    extract::{Form, Query, State, rejection::FormRejection},
    http::{HeaderName, HeaderValue, StatusCode, header},
    response::{IntoResponse, Redirect, Response},
    routing::{any, get, post},
};
use firebase_sdk_rust::firebase_firestore::{Document, FirebaseFirestoreClient, RunQueryRequest};
use gcp_auth::{CustomServiceAccount, TokenProvider, provider};
use serde::{Deserialize, Serialize, de::DeserializeOwned};
use serde_json::{Value as JsonValue, json};
use tower_http::services::ServeDir;
use uuid::Uuid;

const DATASTORE_SCOPE: &str = "https://www.googleapis.com/auth/datastore";
const DEFAULT_KANJI_CANDIDATE_COUNT: usize = 6;
const ADMIN_PROXY_MAX_BODY_BYTES: usize = 16 * 1024 * 1024;
const HX_REDIRECT_HEADER: &str = "hx-redirect";
const WEB_STATIC_DIR: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/static");

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
    admin_base_url: String,
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
    comparison_texture: String,
    comparison_weight: String,
    comparison_usage: String,
    price_by_currency: HashMap<String, i64>,
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
    shipping_fee_by_currency: HashMap<String, i64>,
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
    reading: String,
    reason: String,
}

#[derive(Debug, Clone, Default)]
struct PurchaseResultData {
    error: String,
    selected_locale: String,
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
#[template(path = "top.html")]
struct TopPageTemplate {
    selected_locale: String,
    top_url: String,
    design_url: String,
    terms_url: String,
    commercial_transactions_url: String,
    privacy_policy_url: String,
}

#[derive(Template)]
#[template(path = "index.html")]
struct PageTemplate {
    fonts: Vec<FontOption>,
    font_stylesheet_urls: Vec<String>,
    materials: Vec<MaterialOption>,
    countries: Vec<CountryOption>,
    default_font_key: String,
    default_font_label: String,
    selected_locale: String,
    purchase_action_path: String,
    purchase_note: String,
    top_url: String,
    terms_url: String,
    commercial_transactions_url: String,
    privacy_policy_url: String,
}

#[derive(Template)]
#[template(path = "kanji_suggestions.html")]
struct KanjiSuggestionsTemplate {
    real_name: String,
    kanji_style: String,
    selected_locale: String,
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
    #[serde(alias = "reading_romaji", alias = "romaji")]
    reading: String,
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
    selected_locale: String,
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

#[derive(Template)]
#[template(path = "payment_success.html")]
struct PaymentSuccessTemplate {
    has_session_id: bool,
    session_id: String,
    has_order_id: bool,
    order_id: String,
    selected_locale: String,
    lang_ja_url: String,
    lang_en_url: String,
    top_url: String,
    terms_url: String,
    commercial_transactions_url: String,
    contact_url: String,
    privacy_policy_url: String,
}

#[derive(Template)]
#[template(path = "payment_failure.html")]
struct PaymentFailureTemplate {
    has_order_id: bool,
    order_id: String,
    selected_locale: String,
    lang_ja_url: String,
    lang_en_url: String,
    top_url: String,
    design_url: String,
    terms_url: String,
    commercial_transactions_url: String,
    contact_url: String,
    privacy_policy_url: String,
}

#[derive(Template)]
#[template(path = "commercial_transactions.html")]
struct CommercialTransactionsTemplate {
    selected_locale: String,
    top_url: String,
    design_url: String,
    terms_url: String,
    commercial_transactions_url: String,
    contact_url: String,
    privacy_policy_url: String,
}

#[derive(Template)]
#[template(path = "terms.html")]
struct TermsTemplate {
    design_url: String,
    contact_url: String,
    selected_locale: String,
    top_url: String,
    terms_url: String,
    commercial_transactions_url: String,
    privacy_policy_url: String,
}

#[derive(Debug, Deserialize, Default)]
struct PaymentRedirectQuery {
    checkout: Option<String>,
    session_id: Option<String>,
    order_id: Option<String>,
    lang: Option<String>,
}

#[derive(Debug, Deserialize, Default)]
struct LocaleQuery {
    lang: Option<String>,
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

    async fn load_catalog(&self, locale: &str) -> Result<CatalogData> {
        match self {
            Self::Mock(source) => {
                let _ = &source.catalog;
                Ok(new_mock_catalog_source(locale).catalog)
            }
            Self::Firestore(source) => source.load_catalog(locale).await,
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
    default_locale: String,
    label: String,
    storage_assets_bucket: String,
    allow_mock_fallback: bool,
    token_provider: Arc<dyn TokenProvider>,
}

impl FirestoreCatalogSource {
    async fn load_catalog(&self, locale: &str) -> Result<CatalogData> {
        let access_token = self
            .token_provider
            .token(&[DATASTORE_SCOPE])
            .await
            .context("failed to acquire firestore access token")?;

        let client = Self::firestore_client_from_access_token(access_token.as_str())?;
        let parent = format!("projects/{}/databases/(default)/documents", self.project_id);
        let fallback_catalog = self
            .allow_mock_fallback
            .then(|| new_mock_catalog_source(locale).catalog);

        let fonts = match self.load_fonts(&client, &parent, locale).await {
            Ok(fonts) => fonts,
            Err(error) => match fallback_catalog.as_ref() {
                Some(fallback_catalog) => {
                    eprintln!(
                        "warning: failed to load fonts from firestore: {error}; using mock fonts for dev"
                    );
                    fallback_catalog.fonts.clone()
                }
                None => return Err(error),
            },
        };
        let materials = match self.load_materials(&client, &parent, locale).await {
            Ok(materials) => materials,
            Err(error) => match fallback_catalog.as_ref() {
                Some(fallback_catalog) => {
                    eprintln!(
                        "warning: failed to load materials from firestore: {error}; using mock materials for dev"
                    );
                    fallback_catalog.materials.clone()
                }
                None => return Err(error),
            },
        };
        let countries = match self.load_countries(&client, &parent, locale).await {
            Ok(countries) => countries,
            Err(error) => match fallback_catalog.as_ref() {
                Some(fallback_catalog) => {
                    eprintln!(
                        "warning: failed to load countries from firestore: {error}; using mock countries for dev"
                    );
                    fallback_catalog.countries.clone()
                }
                None => return Err(error),
            },
        };

        Ok(CatalogData {
            fonts,
            materials,
            countries,
        })
    }

    fn firestore_client_from_access_token(access_token: &str) -> Result<FirebaseFirestoreClient> {
        Ok(FirebaseFirestoreClient::new(access_token.to_owned()))
    }

    async fn load_fonts(
        &self,
        client: &FirebaseFirestoreClient,
        parent: &str,
        locale: &str,
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
                stylesheet_url = build_google_fonts_stylesheet_url(&family).map_err(|error| {
                    anyhow!(
                        "fonts/{doc_id} is missing font_stylesheet_url and URL generation failed: {error}"
                    )
                })?;
            }

            let label = resolve_font_label_field(
                &document.fields,
                locale,
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
        locale: &str,
    ) -> Result<Vec<MaterialOption>> {
        let documents = self
            .query_active_documents(client, parent, "materials")
            .await?;

        let mut materials = Vec::with_capacity(documents.len());
        for document in documents {
            let doc_id = document_id(&document)
                .ok_or_else(|| anyhow!("materials document is missing name"))?;

            let mut price_by_currency = read_int_map_field(&document.fields, "price_by_currency");
            if price_by_currency.is_empty() {
                price_by_currency =
                    read_legacy_currency_map(&document.fields, "price_usd", "price_jpy");
                if !price_by_currency.is_empty() {
                    eprintln!(
                        "warning: materials/{doc_id} uses deprecated price_usd/price_jpy; migrate to price_by_currency"
                    );
                }
            }

            let price_currency = locale_currency_code(locale);
            let Some(price) = resolve_amount_for_currency(&price_by_currency, price_currency)
            else {
                eprintln!(
                    "warning: skipping materials/{doc_id}: missing or empty price_by_currency"
                );
                continue;
            };

            let label = resolve_localized_field(
                &document.fields,
                "label_i18n",
                "label",
                locale,
                &self.default_locale,
                &doc_id,
            );
            let description = resolve_localized_field(
                &document.fields,
                "description_i18n",
                "description",
                locale,
                &self.default_locale,
                "",
            );
            let (comparison_default_texture, comparison_default_weight, comparison_default_usage) =
                material_comparison_profile(&doc_id, locale);
            let comparison_texture = fallback_text(
                if parse_supported_locale(locale) == Some("en") {
                    read_string_field(&document.fields, "comparison_texture_en")
                } else {
                    read_string_field(&document.fields, "comparison_texture_ja")
                },
                comparison_default_texture.as_str(),
            );
            let comparison_weight = fallback_text(
                if parse_supported_locale(locale) == Some("en") {
                    read_string_field(&document.fields, "comparison_weight_en")
                } else {
                    read_string_field(&document.fields, "comparison_weight_ja")
                },
                comparison_default_weight.as_str(),
            );
            let comparison_usage = fallback_text(
                if parse_supported_locale(locale) == Some("en") {
                    read_string_field(&document.fields, "comparison_usage_en")
                } else {
                    read_string_field(&document.fields, "comparison_usage_ja")
                },
                comparison_default_usage.as_str(),
            );
            let shape = normalize_material_shape(&read_string_field(&document.fields, "shape"));
            let (photo_url, photo_alt, has_photo) = resolve_material_photo(
                &document.fields,
                &self.storage_assets_bucket,
                locale,
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
                comparison_texture,
                comparison_weight,
                comparison_usage,
                price_by_currency,
                shape: shape.to_owned(),
                shape_label: material_shape_label(shape, locale).to_owned(),
                price,
                price_display: format_currency_amount(price, price_currency),
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
        locale: &str,
    ) -> Result<Vec<CountryOption>> {
        let documents = self
            .query_active_documents(client, parent, "countries")
            .await?;

        let mut countries = Vec::with_capacity(documents.len());
        for document in documents {
            let doc_id = document_id(&document)
                .ok_or_else(|| anyhow!("countries document is missing name"))?;

            let mut shipping_fee_by_currency =
                read_int_map_field(&document.fields, "shipping_fee_by_currency");
            if shipping_fee_by_currency.is_empty() {
                shipping_fee_by_currency = read_legacy_currency_map(
                    &document.fields,
                    "shipping_fee_usd",
                    "shipping_fee_jpy",
                );
                if !shipping_fee_by_currency.is_empty() {
                    eprintln!(
                        "warning: countries/{doc_id} uses deprecated shipping_fee_usd/shipping_fee_jpy; migrate to shipping_fee_by_currency"
                    );
                }
            }

            let shipping_currency = locale_currency_code(locale);
            let Some(shipping) =
                resolve_amount_for_currency(&shipping_fee_by_currency, shipping_currency)
            else {
                eprintln!(
                    "warning: skipping countries/{doc_id}: missing or empty shipping_fee_by_currency"
                );
                continue;
            };

            let label = resolve_localized_field(
                &document.fields,
                "label_i18n",
                "label",
                locale,
                &self.default_locale,
                &doc_id,
            );

            countries.push(CountryOption {
                code: doc_id,
                label,
                shipping_fee_by_currency,
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
        let documents = self
            .run_documents_query(client, parent, collection, true)
            .await?;
        if documents.is_empty() {
            bail!("no active {collection} found in firestore");
        }

        Ok(documents)
    }

    async fn run_documents_query(
        &self,
        client: &FirebaseFirestoreClient,
        parent: &str,
        collection: &str,
        active_only: bool,
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
            .run_query(parent, &query)
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
                .then_with(|| document_id(left).cmp(&document_id(right)))
        });
        Ok(documents)
    }
}

#[derive(Clone)]
struct KanjiApiClient {
    base_url: String,
    http_client: reqwest::Client,
}

#[derive(Clone)]
struct AdminProxyClient {
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

                let reading = item.reading.trim().to_owned();
                let reason = item.reason.trim().to_owned();
                if reading.is_empty() || reason.is_empty() {
                    return None;
                }

                Some(KanjiCandidate {
                    kanji: kanji.clone(),
                    line1: kanji,
                    line2: String::new(),
                    reading,
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
    admin_proxy: Arc<AdminProxyClient>,
    mode: RunMode,
    locale: String,
    default_locale: String,
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
        .route("/", get(handle_top))
        .route("/design", get(handle_design))
        .route("/terms", get(handle_terms))
        .route(
            "/commercial-transactions",
            get(handle_commercial_transactions),
        )
        .route("/payment/success", get(handle_payment_success))
        .route("/payment/failure", get(handle_payment_failure))
        .route("/kanji", post(handle_kanji_suggestions))
        .route("/purchase", post(handle_purchase))
        .route("/mock/kanji", post(handle_kanji_suggestions))
        .route("/mock/purchase", post(handle_mock_purchase))
        .route("/admin-login", any(handle_admin_proxy))
        .route("/admin", any(handle_admin_proxy))
        .route("/admin/{*path}", any(handle_admin_proxy))
        .nest_service("/static", ServeDir::new(WEB_STATIC_DIR))
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
    let admin_proxy_http_client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .context("failed to initialize admin proxy client")?;
    let admin_proxy = Arc::new(AdminProxyClient {
        base_url: cfg.admin_base_url.clone(),
        http_client: admin_proxy_http_client,
    });

    let _catalog = load_catalog_with_timeout(source.as_ref(), &cfg.locale).await?;

    Ok(AppState {
        source,
        kanji_api,
        admin_proxy,
        mode: cfg.mode,
        locale: cfg.locale.clone(),
        default_locale: cfg.default_locale.clone(),
    })
}

fn load_config() -> Result<AppConfig> {
    let mut cfg = AppConfig {
        port: env_first(&["HANKO_WEB_PORT", "PORT"]),
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
        admin_base_url: env_first(&[
            "HANKO_WEB_ADMIN_BASE_URL_PROD",
            "HANKO_WEB_ADMIN_BASE_URL",
        ]),
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

    if cfg.admin_base_url.is_empty() {
        if matches!(cfg.mode, RunMode::Prod) {
            bail!("prod web requires HANKO_WEB_ADMIN_BASE_URL[_PROD]");
        }
        cfg.admin_base_url = "http://localhost:3051".to_owned();
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
        RunMode::Mock => Ok(CatalogSource::Mock(new_mock_catalog_source(&cfg.locale))),
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
                default_locale: cfg.default_locale.clone(),
                label,
                storage_assets_bucket: cfg.storage_assets_bucket.clone().unwrap_or_default(),
                allow_mock_fallback: false,
                token_provider,
            }))
        }
    }
}

impl AdminProxyClient {
    async fn proxy(&self, request: axum::extract::Request) -> Response {
        let (parts, body) = request.into_parts();

        let path_and_query = parts
            .uri
            .path_and_query()
            .map(|value| value.as_str())
            .unwrap_or("/");
        let target = match reqwest::Url::parse(self.base_url.trim_end_matches('/'))
            .and_then(|base| base.join(path_and_query))
        {
            Ok(url) => url,
            Err(error) => {
                return plain_error(
                    StatusCode::BAD_GATEWAY,
                    format!("failed to build admin proxy URL: {error}"),
                );
            }
        };

        let body = match axum::body::to_bytes(body, ADMIN_PROXY_MAX_BODY_BYTES).await {
            Ok(body) => body,
            Err(error) => {
                return plain_error(
                    StatusCode::PAYLOAD_TOO_LARGE,
                    format!("failed to read admin proxy request body: {error}"),
                );
            }
        };

        let mut request_builder = self
            .http_client
            .request(parts.method.clone(), target)
            .body(body.to_vec());

        for (name, value) in &parts.headers {
            if should_forward_admin_request_header(name) {
                request_builder = request_builder.header(name, value);
            }
        }

        let upstream = match request_builder.send().await {
            Ok(response) => response,
            Err(error) => {
                return plain_error(
                    StatusCode::BAD_GATEWAY,
                    format!("failed to proxy admin request: {error}"),
                );
            }
        };

        let status = upstream.status();
        let upstream_headers = upstream.headers().clone();
        let body = match upstream.bytes().await {
            Ok(body) => body,
            Err(error) => {
                return plain_error(
                    StatusCode::BAD_GATEWAY,
                    format!("failed to read admin proxy response: {error}"),
                );
            }
        };

        let mut response_builder = Response::builder().status(status);
        if let Some(content_type) = upstream_headers.get(header::CONTENT_TYPE) {
            response_builder = response_builder.header(header::CONTENT_TYPE, content_type);
        }
        for (name, value) in &upstream_headers {
            if should_forward_admin_response_header(name) {
                response_builder = response_builder.header(name, value);
            }
        }

        match response_builder.body(axum::body::Body::from(body.to_vec())) {
            Ok(response) => response,
            Err(error) => plain_error(
                StatusCode::BAD_GATEWAY,
                format!("failed to build admin proxy response: {error}"),
            ),
        }
    }
}

async fn handle_admin_proxy(
    State(state): State<AppState>,
    request: axum::extract::Request,
) -> Response {
    state.admin_proxy.proxy(request).await
}

fn new_mock_catalog_source(locale: &str) -> MockCatalogSource {
    let english = parse_supported_locale(locale) == Some("en");

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
                    key: "rose_quartz".to_owned(),
                    label: if english {
                        "Rose Quartz"
                    } else {
                        "ローズクオーツ"
                    }
                    .to_owned(),
                    description: if english {
                        "A soft-toned stone with a warm, approachable presence"
                    } else {
                        "やわらかな色合いで、親しみやすい印象の石材"
                    }
                    .to_owned(),
                    comparison_texture: if english {
                        "Soft, translucent pink sheen"
                    } else {
                        "淡い桃色のやわらかな透明感"
                    }
                    .to_owned(),
                    comparison_weight: if english {
                        "Light and gentle to handle"
                    } else {
                        "やや軽やかで手になじみやすい"
                    }
                    .to_owned(),
                    comparison_usage: if english {
                        "A soft, friendly finish"
                    } else {
                        "やわらかな印象を出しやすい"
                    }
                    .to_owned(),
                    price_by_currency: HashMap::from([
                        ("USD".to_owned(), 16500),
                        ("JPY".to_owned(), 28000),
                    ]),
                    shape: "square".to_owned(),
                    shape_label: if english { "Square seal" } else { "角印" }.to_owned(),
                    price: if english { 16500 } else { 28000 },
                    price_display: if english {
                        format_usd(16500)
                    } else {
                        format_jpy(28000)
                    },
                    photo_url: "https://picsum.photos/seed/hf-rose-quartz/640/420".to_owned(),
                    photo_alt: if english {
                        "Rose quartz photo"
                    } else {
                        "ローズクオーツ材の写真"
                    }
                    .to_owned(),
                    has_photo: true,
                },
                MaterialOption {
                    key: "lapis_lazuli".to_owned(),
                    label: if english {
                        "Lapis Lazuli"
                    } else {
                        "ラピスラビリ"
                    }
                    .to_owned(),
                    description: if english {
                        "A deep-blue stone with a strong, distinctive presence"
                    } else {
                        "深い青が印象的な、存在感のある石材"
                    }
                    .to_owned(),
                    comparison_texture: if english {
                        "Deep blue stone with bright flecks"
                    } else {
                        "深い青にきらめきが入る石目"
                    }
                    .to_owned(),
                    comparison_weight: if english {
                        "Medium-heavy with a strong presence"
                    } else {
                        "ほどよい重さで存在感がある"
                    }
                    .to_owned(),
                    comparison_usage: if english {
                        "A vivid, distinctive finish"
                    } else {
                        "印象を強めやすい"
                    }
                    .to_owned(),
                    price_by_currency: HashMap::from([
                        ("USD".to_owned(), 32500),
                        ("JPY".to_owned(), 55000),
                    ]),
                    shape: "round".to_owned(),
                    shape_label: if english { "Round seal" } else { "丸印" }.to_owned(),
                    price: if english { 32500 } else { 55000 },
                    price_display: if english {
                        format_usd(32500)
                    } else {
                        format_jpy(55000)
                    },
                    photo_url: "https://picsum.photos/seed/hf-lapis-lazuli/640/420".to_owned(),
                    photo_alt: if english {
                        "Lapis lazuli photo"
                    } else {
                        "ラピスラビリ材の写真"
                    }
                    .to_owned(),
                    has_photo: true,
                },
                MaterialOption {
                    key: "jade".to_owned(),
                    label: if english { "Jade" } else { "翡翠" }.to_owned(),
                    description: if english {
                        "A dignified stone with a calm green sheen"
                    } else {
                        "落ち着いた緑の艶が映える、格調ある石材"
                    }
                    .to_owned(),
                    comparison_texture: if english {
                        "Polished green stone with a calm sheen"
                    } else {
                        "しっとりした緑石の艶感"
                    }
                    .to_owned(),
                    comparison_weight: if english {
                        "Substantial and steady"
                    } else {
                        "ほどよく重く、落ち着いた安定感"
                    }
                    .to_owned(),
                    comparison_usage: if english {
                        "A calm, dignified finish"
                    } else {
                        "落ち着いた格調を出しやすい"
                    }
                    .to_owned(),
                    price_by_currency: HashMap::from([
                        ("USD".to_owned(), 88500),
                        ("JPY".to_owned(), 150000),
                    ]),
                    shape: "square".to_owned(),
                    shape_label: if english { "Square seal" } else { "角印" }.to_owned(),
                    price: if english { 88500 } else { 150000 },
                    price_display: if english {
                        format_usd(88500)
                    } else {
                        format_jpy(150000)
                    },
                    photo_url: "https://picsum.photos/seed/hf-jade/640/420".to_owned(),
                    photo_alt: if english {
                        "Jade photo"
                    } else {
                        "翡翠材の写真"
                    }
                    .to_owned(),
                    has_photo: true,
                },
            ],
            countries: vec![
                CountryOption {
                    code: "JP".to_owned(),
                    label: if english { "Japan" } else { "日本" }.to_owned(),
                    shipping_fee_by_currency: HashMap::from([
                        ("USD".to_owned(), 600),
                        ("JPY".to_owned(), 600),
                    ]),
                    shipping: 600,
                },
                CountryOption {
                    code: "US".to_owned(),
                    label: if english { "United States" } else { "アメリカ" }.to_owned(),
                    shipping_fee_by_currency: HashMap::from([
                        ("USD".to_owned(), 1800),
                        ("JPY".to_owned(), 1800),
                    ]),
                    shipping: 1800,
                },
                CountryOption {
                    code: "CA".to_owned(),
                    label: if english { "Canada" } else { "カナダ" }.to_owned(),
                    shipping_fee_by_currency: HashMap::from([
                        ("USD".to_owned(), 1900),
                        ("JPY".to_owned(), 1900),
                    ]),
                    shipping: 1900,
                },
                CountryOption {
                    code: "GB".to_owned(),
                    label: if english { "United Kingdom" } else { "イギリス" }.to_owned(),
                    shipping_fee_by_currency: HashMap::from([
                        ("USD".to_owned(), 2000),
                        ("JPY".to_owned(), 2000),
                    ]),
                    shipping: 2000,
                },
                CountryOption {
                    code: "AU".to_owned(),
                    label: if english { "Australia" } else { "オーストラリア" }.to_owned(),
                    shipping_fee_by_currency: HashMap::from([
                        ("USD".to_owned(), 2100),
                        ("JPY".to_owned(), 2100),
                    ]),
                    shipping: 2100,
                },
                CountryOption {
                    code: "SG".to_owned(),
                    label: if english { "Singapore" } else { "シンガポール" }.to_owned(),
                    shipping_fee_by_currency: HashMap::from([
                        ("USD".to_owned(), 1300),
                        ("JPY".to_owned(), 1300),
                    ]),
                    shipping: 1300,
                },
            ],
        },
    }
}

async fn load_catalog_with_timeout(source: &CatalogSource, locale: &str) -> Result<CatalogData> {
    let catalog = tokio::time::timeout(Duration::from_secs(7), source.load_catalog(locale))
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

fn build_google_fonts_stylesheet_url(font_family: &str) -> Result<String> {
    let first_font_name = extract_primary_font_name(font_family)
        .ok_or_else(|| anyhow!("font-family does not contain a primary font name"))?;
    if is_generic_css_font_family(&first_font_name) {
        bail!("font-family primary value must be a concrete Google Fonts family name");
    }

    let mut url = reqwest::Url::parse("https://fonts.googleapis.com/css2")
        .context("failed to parse Google Fonts css2 endpoint")?;
    {
        let mut query = url.query_pairs_mut();
        query.append_pair("family", &first_font_name);
        query.append_pair("display", "swap");
    }
    Ok(url.to_string())
}

fn extract_primary_font_name(font_family: &str) -> Option<String> {
    let first = font_family.split(',').next()?.trim();
    if first.is_empty() {
        return None;
    }

    let unquoted = first
        .strip_prefix('\'')
        .and_then(|value| value.strip_suffix('\''))
        .or_else(|| {
            first
                .strip_prefix('"')
                .and_then(|value| value.strip_suffix('"'))
        })
        .unwrap_or(first)
        .trim();
    if unquoted.is_empty() {
        return None;
    }

    let normalized = unquoted.split_whitespace().collect::<Vec<_>>().join(" ");
    if normalized.is_empty() {
        None
    } else {
        Some(normalized)
    }
}

fn is_generic_css_font_family(font_name: &str) -> bool {
    let normalized = font_name.trim().to_ascii_lowercase();
    matches!(
        normalized.as_str(),
        "serif"
            | "sans-serif"
            | "monospace"
            | "cursive"
            | "fantasy"
            | "system-ui"
            | "ui-serif"
            | "ui-sans-serif"
            | "ui-monospace"
            | "ui-rounded"
            | "emoji"
            | "math"
            | "fangsong"
            | "inherit"
            | "initial"
            | "unset"
            | "revert"
            | "revert-layer"
    )
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

async fn handle_top(
    State(state): State<AppState>,
    Query(query): Query<PaymentRedirectQuery>,
) -> Response {
    let selected_locale =
        resolve_request_locale(query.lang.as_deref(), &state.locale, &state.default_locale);

    if let Some(path) = checkout_redirect_path(&query, &selected_locale) {
        return Redirect::to(&path).into_response();
    }

    let template = TopPageTemplate {
        selected_locale: selected_locale.clone(),
        top_url: top_url(&selected_locale),
        design_url: design_url(&selected_locale),
        terms_url: terms_url(&selected_locale),
        commercial_transactions_url: commercial_transactions_url(&selected_locale),
        privacy_policy_url: privacy_policy_url(&selected_locale),
    };

    match render_html(&template) {
        Ok(html) => html_response(html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render page: {error}"),
        ),
    }
}

async fn handle_design(
    State(state): State<AppState>,
    Query(query): Query<PaymentRedirectQuery>,
) -> Response {
    let selected_locale =
        resolve_request_locale(query.lang.as_deref(), &state.locale, &state.default_locale);

    if let Some(path) = checkout_redirect_path(&query, &selected_locale) {
        return Redirect::to(&path).into_response();
    }

    let catalog = match load_catalog_with_timeout(state.source.as_ref(), &selected_locale).await {
        Ok(catalog) => catalog,
        Err(error) => {
            return plain_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("failed to load catalog: {error}"),
            );
        }
    };
    let catalog = localize_catalog_prices(catalog, &selected_locale);

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
        purchase_action_path: if state.mode == RunMode::Mock {
            "/mock/purchase".to_owned()
        } else {
            "/purchase".to_owned()
        },
        purchase_note: if state.mode == RunMode::Mock {
            localized_text(
                &selected_locale,
                "モック注文を確定します。",
                "This confirms a mock order.",
            )
        } else {
            localized_text(
                &selected_locale,
                "Stripe Checkout に遷移して決済します。",
                "You will be redirected to Stripe Checkout to complete payment.",
            )
        },
        top_url: top_url(&selected_locale),
        terms_url: terms_url(&selected_locale),
        commercial_transactions_url: commercial_transactions_url(&selected_locale),
        privacy_policy_url: privacy_policy_url(&selected_locale),
        selected_locale,
    };

    match render_html(&template) {
        Ok(html) => html_response(html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render page: {error}"),
        ),
    }
}

fn checkout_redirect_path(query: &PaymentRedirectQuery, locale: &str) -> Option<String> {
    let checkout = query.checkout.as_deref()?.trim().to_lowercase();
    let base_path = match checkout.as_str() {
        "success" => "/payment/success",
        "cancel" => "/payment/failure",
        _ => return None,
    };

    let mut params = vec![format!("lang={locale}")];
    if let Some(session_id) = query
        .session_id
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
    {
        params.push(format!("session_id={session_id}"));
    }
    if let Some(order_id) = query
        .order_id
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
    {
        params.push(format!("order_id={order_id}"));
    }

    Some(format!("{base_path}?{}", params.join("&")))
}

fn payment_result_locale_url(
    base_path: &str,
    query: &PaymentRedirectQuery,
    locale: &str,
) -> String {
    let normalized = parse_supported_locale(locale).unwrap_or("ja");
    let mut params = vec![format!("lang={normalized}")];

    if let Some(checkout) = query
        .checkout
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
    {
        params.push(format!("checkout={checkout}"));
    }
    if let Some(session_id) = query
        .session_id
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
    {
        params.push(format!("session_id={session_id}"));
    }
    if let Some(order_id) = query
        .order_id
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
    {
        params.push(format!("order_id={order_id}"));
    }

    format!("{base_path}?{}", params.join("&"))
}

async fn handle_payment_success(
    State(state): State<AppState>,
    Query(query): Query<PaymentRedirectQuery>,
) -> Response {
    let session_id = query
        .session_id
        .as_deref()
        .unwrap_or_default()
        .trim()
        .to_owned();
    let selected_locale =
        resolve_request_locale(query.lang.as_deref(), &state.locale, &state.default_locale);
    let order_id = query
        .order_id
        .as_deref()
        .unwrap_or_default()
        .trim()
        .to_owned();
    let template = PaymentSuccessTemplate {
        contact_url: inquiry_url(&selected_locale),
        commercial_transactions_url: commercial_transactions_url(&selected_locale),
        has_order_id: !order_id.is_empty(),
        order_id,
        has_session_id: !session_id.is_empty(),
        session_id,
        lang_en_url: payment_result_locale_url("/payment/success", &query, "en"),
        lang_ja_url: payment_result_locale_url("/payment/success", &query, "ja"),
        top_url: top_url(&selected_locale),
        terms_url: terms_url(&selected_locale),
        privacy_policy_url: privacy_policy_url(&selected_locale),
        selected_locale,
    };

    match render_html(&template) {
        Ok(html) => html_response(html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render payment success page: {error}"),
        ),
    }
}

async fn handle_payment_failure(
    State(state): State<AppState>,
    Query(query): Query<PaymentRedirectQuery>,
) -> Response {
    let selected_locale =
        resolve_request_locale(query.lang.as_deref(), &state.locale, &state.default_locale);
    let order_id = query
        .order_id
        .as_deref()
        .unwrap_or_default()
        .trim()
        .to_owned();
    let template = PaymentFailureTemplate {
        contact_url: inquiry_url(&selected_locale),
        commercial_transactions_url: commercial_transactions_url(&selected_locale),
        has_order_id: !order_id.is_empty(),
        order_id,
        lang_en_url: payment_result_locale_url("/payment/failure", &query, "en"),
        lang_ja_url: payment_result_locale_url("/payment/failure", &query, "ja"),
        top_url: top_url(&selected_locale),
        design_url: design_url(&selected_locale),
        terms_url: terms_url(&selected_locale),
        privacy_policy_url: privacy_policy_url(&selected_locale),
        selected_locale,
    };
    match render_html(&template) {
        Ok(html) => html_response(html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render payment failure page: {error}"),
        ),
    }
}

async fn handle_commercial_transactions(
    State(state): State<AppState>,
    Query(query): Query<LocaleQuery>,
) -> Response {
    let selected_locale =
        resolve_request_locale(query.lang.as_deref(), &state.locale, &state.default_locale);
    let template = CommercialTransactionsTemplate {
        contact_url: inquiry_url(&selected_locale),
        top_url: top_url(&selected_locale),
        design_url: design_url(&selected_locale),
        commercial_transactions_url: commercial_transactions_url(&selected_locale),
        terms_url: terms_url(&selected_locale),
        privacy_policy_url: privacy_policy_url(&selected_locale),
        selected_locale,
    };

    match render_html(&template) {
        Ok(html) => html_response(html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render commercial transactions page: {error}"),
        ),
    }
}

async fn handle_terms(State(state): State<AppState>, Query(query): Query<LocaleQuery>) -> Response {
    let selected_locale =
        resolve_request_locale(query.lang.as_deref(), &state.locale, &state.default_locale);
    let template = TermsTemplate {
        design_url: design_url(&selected_locale),
        contact_url: inquiry_url(&selected_locale),
        terms_url: terms_url(&selected_locale),
        commercial_transactions_url: commercial_transactions_url(&selected_locale),
        privacy_policy_url: privacy_policy_url(&selected_locale),
        top_url: top_url(&selected_locale),
        selected_locale,
    };

    match render_html(&template) {
        Ok(html) => html_response(html),
        Err(error) => plain_error(
            StatusCode::INTERNAL_SERVER_ERROR,
            format!("failed to render terms page: {error}"),
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
    let requested_locale = form_value(&form, "locale");
    let selected_locale = resolve_request_locale(
        Some(&requested_locale),
        &state.locale,
        &state.default_locale,
    );
    let reason_language = selected_locale.clone();
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
                    localized_text(
                        &selected_locale,
                        "候補を生成できませんでした。時間をおいて再度お試しください。",
                        "Could not generate suggestions. Please try again later.",
                    ),
                )
            }
        }
    };

    let template = KanjiSuggestionsTemplate {
        real_name,
        kanji_style: kanji_style.to_owned(),
        selected_locale,
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
    handle_purchase_impl(state, form, false).await
}

async fn handle_mock_purchase(
    State(state): State<AppState>,
    form: std::result::Result<Form<HashMap<String, String>>, FormRejection>,
) -> Response {
    handle_purchase_impl(state, form, true).await
}

async fn handle_purchase_impl(
    state: AppState,
    form: std::result::Result<Form<HashMap<String, String>>, FormRejection>,
    show_mock_confirmation: bool,
) -> Response {
    let Form(form) = match form {
        Ok(form) => form,
        Err(_) => return plain_error(StatusCode::BAD_REQUEST, "invalid request".to_owned()),
    };

    let requested_locale = form_value(&form, "locale");
    let order_locale = resolve_request_locale(
        Some(&requested_locale),
        &state.locale,
        &state.default_locale,
    );

    let catalog = match load_catalog_with_timeout(state.source.as_ref(), &order_locale).await {
        Ok(catalog) => catalog,
        Err(error) => {
            return plain_error(
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("failed to load catalog: {error}"),
            );
        }
    };
    let catalog = localize_catalog_prices(catalog, &order_locale);

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

    let is_mock_confirmation = show_mock_confirmation || state.mode == RunMode::Mock;

    let mut result = PurchaseResultData {
        source_label: state.source.label().to_owned(),
        is_mock: is_mock_confirmation,
        selected_locale: order_locale.clone(),
        ..PurchaseResultData::default()
    };

    if let Err(message) = validate_seal_lines(&order_locale, &seal_line1, &seal_line2) {
        result.error = message;
        return render_purchase_result(&result);
    }

    let Some(font) = font_by_key.get(&font_key) else {
        result.error = localized_text(
            &order_locale,
            "フォントを選択してください。",
            "Please choose a font.",
        );
        return render_purchase_result(&result);
    };

    let Some(selected_shape_label) = shape_label_for_locale(&shape_key, &order_locale) else {
        result.error = localized_text(
            &order_locale,
            "印鑑の形状を選択してください。",
            "Please choose a seal shape.",
        );
        return render_purchase_result(&result);
    };

    let Some(material) = material_by_key.get(&material_key) else {
        result.error = localized_text(
            &order_locale,
            "材質を選択してください。",
            "Please choose a material.",
        );
        return render_purchase_result(&result);
    };
    if !material_supports_shape(&material.key, &material.shape, &shape_key) {
        result.error = localized_text(
            &order_locale,
            "選択した形状に対応する材質を選択してください。",
            "Please choose a material that matches the selected shape.",
        );
        return render_purchase_result(&result);
    }

    let Some(country) = country_by_code.get(&country_code) else {
        result.error = localized_text(
            &order_locale,
            "配送先の国を選択してください。",
            "Please choose a shipping country.",
        );
        return render_purchase_result(&result);
    };

    if recipient_name.is_empty() {
        result.error = localized_text(
            &order_locale,
            "購入者名を入力してください。",
            "Enter the recipient name.",
        );
        return render_purchase_result(&result);
    }

    if phone.is_empty() {
        result.error = localized_text(
            &order_locale,
            "電話番号を入力してください。",
            "Enter a phone number.",
        );
        return render_purchase_result(&result);
    }

    if postal_code.is_empty() {
        result.error = localized_text(
            &order_locale,
            "郵便番号を入力してください。",
            "Enter a postal code.",
        );
        return render_purchase_result(&result);
    }

    if state_name.is_empty() {
        result.error = localized_text(
            &order_locale,
            "都道府県 / 州を入力してください。",
            "Enter a state or prefecture.",
        );
        return render_purchase_result(&result);
    }

    if city.is_empty() {
        result.error = localized_text(
            &order_locale,
            "市区町村 / City を入力してください。",
            "Enter a city.",
        );
        return render_purchase_result(&result);
    }

    if address_line1.is_empty() {
        result.error = localized_text(
            &order_locale,
            "住所1を入力してください。",
            "Enter address line 1.",
        );
        return render_purchase_result(&result);
    }

    if email.is_empty() {
        result.error = localized_text(
            &order_locale,
            "購入確認用のメールアドレスを入力してください。",
            "Enter the confirmation email address.",
        );
        return render_purchase_result(&result);
    }

    if !terms_agreed {
        result.error = localized_text(
            &order_locale,
            "利用規約への同意が必要です。",
            "Please agree to the terms of service.",
        );
        return render_purchase_result(&result);
    }

    let subtotal = material.price;
    let shipping = country.shipping;
    let total = subtotal + shipping;
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
            preferred_locale: order_locale.clone(),
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

    if is_mock_confirmation {
        return render_purchase_result(&result);
    }

    let order = match state.kanji_api.create_order(&create_order_request).await {
        Ok(order) => order,
        Err(error) => {
            eprintln!("failed to create order for stripe checkout: {error:#}");
            result.error = localized_text(
                &order_locale,
                "注文の作成に失敗しました。時間をおいて再度お試しください。",
                "Could not create the order. Please try again later.",
            );
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
            result.error = localized_text(
                &order_locale,
                "決済画面の作成に失敗しました。時間をおいて再度お試しください。",
                "Could not create the checkout session. Please try again later.",
            );
            return render_purchase_result(&result);
        }
    };

    hx_redirect_response(&checkout_session.checkout_url)
}

fn render_purchase_result(data: &PurchaseResultData) -> Response {
    let template = PurchaseResultTemplate {
        has_error: !data.error.is_empty(),
        error: data.error.clone(),
        selected_locale: data.selected_locale.clone(),
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
        subtotal_display: format_locale_amount(data.subtotal, &data.selected_locale),
        shipping_display: format_locale_amount(data.shipping, &data.selected_locale),
        total_display: format_locale_amount(data.total, &data.selected_locale),
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

fn should_forward_admin_request_header(name: &HeaderName) -> bool {
    let name = name.as_str().to_ascii_lowercase();
    !matches!(
        name.as_str(),
        "accept-encoding"
            | "connection"
            | "content-length"
            | "host"
            | "keep-alive"
            | "proxy-authenticate"
            | "proxy-authorization"
            | "te"
            | "trailer"
            | "transfer-encoding"
            | "upgrade"
    )
}

fn should_forward_admin_response_header(name: &HeaderName) -> bool {
    let name = name.as_str().to_ascii_lowercase();
    !matches!(
        name.as_str(),
        "connection"
            | "content-type"
            | "content-length"
            | "keep-alive"
            | "proxy-authenticate"
            | "proxy-authorization"
            | "te"
            | "trailer"
            | "transfer-encoding"
            | "upgrade"
    )
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

fn resolve_request_locale(requested: Option<&str>, locale: &str, default_locale: &str) -> String {
    if let Some(value) = requested.and_then(parse_supported_locale) {
        return value.to_owned();
    }
    if let Some(value) = parse_supported_locale(locale) {
        return value.to_owned();
    }
    if let Some(value) = parse_supported_locale(default_locale) {
        return value.to_owned();
    }
    "ja".to_owned()
}

fn parse_supported_locale(raw: &str) -> Option<&'static str> {
    let normalized = raw.trim().to_lowercase();
    if normalized.starts_with("ja") {
        return Some("ja");
    }
    if normalized.starts_with("en") {
        return Some("en");
    }
    None
}

fn privacy_policy_url(locale: &str) -> String {
    let normalized = parse_supported_locale(locale).unwrap_or("ja");
    if normalized == "ja" {
        return "https://finitefield.org/privacy/".to_owned();
    }
    format!("https://finitefield.org/{normalized}/privacy/")
}

fn commercial_transactions_url(locale: &str) -> String {
    let normalized = parse_supported_locale(locale).unwrap_or("ja");
    format!("/commercial-transactions?lang={normalized}")
}

fn top_url(locale: &str) -> String {
    let normalized = parse_supported_locale(locale).unwrap_or("ja");
    format!("/?lang={normalized}")
}

fn design_url(locale: &str) -> String {
    let normalized = parse_supported_locale(locale).unwrap_or("ja");
    format!("/design?lang={normalized}")
}

fn terms_url(locale: &str) -> String {
    let normalized = parse_supported_locale(locale).unwrap_or("ja");
    format!("/terms?lang={normalized}")
}

fn inquiry_url(locale: &str) -> String {
    let normalized = parse_supported_locale(locale).unwrap_or("ja");
    if normalized == "ja" {
        return "https://finitefield.org/inquiry/".to_owned();
    }
    format!("https://finitefield.org/{normalized}/inquiry/")
}

fn localized_text(locale: &str, ja: &str, en: &str) -> String {
    if parse_supported_locale(locale) == Some("en") {
        en.to_owned()
    } else {
        ja.to_owned()
    }
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

fn material_supports_shape(material_key: &str, material_shape: &str, seal_shape: &str) -> bool {
    material_is_shape_flexible(material_key) || material_shape == seal_shape
}

fn material_is_shape_flexible(material_key: &str) -> bool {
    matches!(material_key, "rose_quartz" | "lapis_lazuli" | "jade")
}

fn material_shape_label(shape_key: &str, locale: &str) -> &'static str {
    let english = parse_supported_locale(locale) == Some("en");
    match shape_key {
        "round" => {
            if english {
                "Round seal"
            } else {
                "丸印"
            }
        }
        _ => {
            if english {
                "Square seal"
            } else {
                "角印"
            }
        }
    }
}

fn fallback_text(value: String, fallback: &str) -> String {
    if value.trim().is_empty() {
        fallback.to_owned()
    } else {
        value
    }
}

fn material_comparison_profile(material_key: &str, locale: &str) -> (String, String, String) {
    let is_english = parse_supported_locale(locale) == Some("en");

    let profile = match material_key {
        "rose_quartz" => {
            if is_english {
                (
                    "Soft, translucent pink sheen",
                    "Light and gentle to handle",
                    "A soft, friendly finish",
                )
            } else {
                (
                    "淡い桃色のやわらかな透明感",
                    "やや軽やかで手になじみやすい",
                    "やわらかな印象を出しやすい",
                )
            }
        }
        "boxwood" => {
            if is_english {
                (
                    "A simple wood grain with a gentle feel",
                    "Light and easy to handle",
                    "A dependable everyday standard",
                )
            } else {
                (
                    "木目がやわらかく見える素朴な質感",
                    "軽くて扱いやすい",
                    "日常使いしやすい定番",
                )
            }
        }
        "black_buffalo" => {
            if is_english {
                (
                    "Smooth, deep black finish",
                    "Moderately weighted and steady",
                    "Well suited to a calm, formal look",
                )
            } else {
                (
                    "深い黒のしっとりした質感",
                    "ほどよい重さで落ち着きがある",
                    "落ち着いた印象を出したいときに向く",
                )
            }
        }
        "a_maru" => {
            if is_english {
                ("Balanced, neutral texture", "Medium weight", "Versatile")
            } else {
                ("標準的な質感", "中程度の重さ", "汎用的")
            }
        }
        "lapis_lazuli" => {
            if is_english {
                (
                    "Deep blue stone with bright flecks",
                    "Medium-heavy with a strong presence",
                    "A vivid, distinctive finish",
                )
            } else {
                (
                    "深い青にきらめきが入る石目",
                    "ほどよい重さで存在感がある",
                    "印象を強めやすい",
                )
            }
        }
        "jade" => {
            if is_english {
                (
                    "Polished green stone with a calm sheen",
                    "Substantial and steady",
                    "A calm, dignified finish",
                )
            } else {
                (
                    "しっとりした緑石の艶感",
                    "ほどよく重く、落ち着いた安定感",
                    "落ち着いた格調を出しやすい",
                )
            }
        }
        _ => {
            if is_english {
                (
                    "Balanced, neutral texture",
                    "Medium weight",
                    "General-purpose use",
                )
            } else {
                ("標準的な質感", "中程度の重さ", "汎用的")
            }
        }
    };

    (
        profile.0.to_owned(),
        profile.1.to_owned(),
        profile.2.to_owned(),
    )
}

fn shape_label_for_locale(shape_key: &str, locale: &str) -> Option<&'static str> {
    let english = parse_supported_locale(locale) == Some("en");
    match shape_key {
        "square" => Some(if english { "Square seal" } else { "角印" }),
        "round" => Some(if english { "Round seal" } else { "丸印" }),
        _ => None,
    }
}

fn validate_seal_lines(locale: &str, line1: &str, line2: &str) -> std::result::Result<(), String> {
    let first = line1.trim();
    let second = line2.trim();

    if first.is_empty() {
        return Err(localized_text(
            locale,
            "お名前を入力してください。",
            "Enter your name.",
        ));
    }

    if contains_whitespace(first) {
        return Err(localized_text(
            locale,
            "1行目に空白は使えません。",
            "Line 1 cannot contain spaces.",
        ));
    }

    if !second.is_empty() && contains_whitespace(second) {
        return Err(localized_text(
            locale,
            "2行目に空白は使えません。",
            "Line 2 cannot contain spaces.",
        ));
    }

    if first.chars().count() + second.chars().count() > 2 {
        return Err(localized_text(
            locale,
            "印影テキストは1行目と2行目の合計で2文字以内で入力してください。",
            "Use up to 2 characters total across lines 1 and 2.",
        ));
    }

    Ok(())
}

fn contains_whitespace(value: &str) -> bool {
    value.chars().any(char::is_whitespace)
}

fn format_usd(amount_cents: i64) -> String {
    let sign = if amount_cents < 0 { "-" } else { "" };
    let cents = amount_cents.abs();
    let whole = cents / 100;
    let fraction = cents % 100;
    let whole_display = format_with_grouping(whole);
    format!("{sign}USD {whole_display}.{fraction:02}")
}

fn format_jpy(amount_yen: i64) -> String {
    let sign = if amount_yen < 0 { "-" } else { "" };
    let yen = amount_yen.abs();
    format!("{sign}JPY {}", format_with_grouping(yen))
}

fn format_currency_amount(amount: i64, currency: &str) -> String {
    let normalized = currency.trim().to_ascii_uppercase();
    match normalized.as_str() {
        "JPY" => format_jpy(amount),
        _ => format_usd(amount),
    }
}

fn format_locale_amount(amount: i64, locale: &str) -> String {
    format_currency_amount(amount, locale_currency_code(locale))
}

fn format_with_grouping(value: i64) -> String {
    if value == 0 {
        return "0".to_owned();
    }

    let digits = value.to_string();
    let mut out = String::with_capacity(digits.len() + digits.len() / 3);
    for (index, ch) in digits.chars().enumerate() {
        if index > 0 && (digits.len() - index) % 3 == 0 {
            out.push(',');
        }
        out.push(ch);
    }
    out
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

fn resolve_font_label_field(
    data: &BTreeMap<String, JsonValue>,
    locale: &str,
    default_locale: &str,
    fallback: &str,
) -> String {
    let label = read_string_field(data, "label");
    if !label.is_empty() {
        return label;
    }

    let localized = resolve_localized_text(
        &read_string_map_field(data, "label_i18n"),
        locale,
        default_locale,
    );
    if !localized.is_empty() {
        return localized;
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
    for (map_key, map_value) in fields {
        let mut field = BTreeMap::new();
        field.insert("amount".to_owned(), map_value.clone());
        if let Some(amount) = read_int_field(&field, "amount") {
            result.insert(map_key.trim().to_ascii_uppercase(), amount);
        }
    }

    result
}

fn read_legacy_currency_map(
    data: &BTreeMap<String, JsonValue>,
    usd_field: &str,
    jpy_field: &str,
) -> HashMap<String, i64> {
    let mut result = HashMap::new();
    if let Some(amount) = read_int_field(data, usd_field) {
        result.insert("USD".to_owned(), amount.max(0));
    }
    if let Some(amount) = read_int_field(data, jpy_field) {
        result.insert("JPY".to_owned(), amount.max(0));
    }
    result
}

fn locale_currency_code(locale: &str) -> &'static str {
    if parse_supported_locale(locale) == Some("en") {
        "USD"
    } else {
        "JPY"
    }
}

fn localize_catalog_prices(mut catalog: CatalogData, locale: &str) -> CatalogData {
    let currency = locale_currency_code(locale);

    for material in &mut catalog.materials {
        if let Some(price) = resolve_amount_for_currency(&material.price_by_currency, currency) {
            material.price = price;
            material.price_display = format_currency_amount(price, currency);
        }
    }

    for country in &mut catalog.countries {
        if let Some(shipping) =
            resolve_amount_for_currency(&country.shipping_fee_by_currency, currency)
        {
            country.shipping = shipping;
        }
    }

    catalog
}

fn resolve_amount_for_currency(values: &HashMap<String, i64>, currency: &str) -> Option<i64> {
    let code = currency.trim().to_ascii_uppercase();
    if let Some(amount) = values.get(&code).copied() {
        return Some(amount.max(0));
    }
    if let Some(amount) = values.get("USD").copied() {
        return Some(amount.max(0));
    }
    if let Some(amount) = values.get("JPY").copied() {
        return Some(amount.max(0));
    }

    let mut keys = values.keys().cloned().collect::<Vec<_>>();
    keys.sort();
    keys.into_iter()
        .find_map(|key| values.get(&key).copied())
        .map(|amount| amount.max(0))
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

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::to_bytes;
    use axum::extract::Form;
    use std::collections::HashMap;
    use std::sync::Arc;

    fn mock_state() -> AppState {
        AppState {
            source: Arc::new(CatalogSource::Mock(new_mock_catalog_source("ja"))),
            kanji_api: Arc::new(KanjiApiClient {
                base_url: "http://localhost:3050".to_owned(),
                http_client: reqwest::Client::new(),
            }),
            admin_proxy: Arc::new(AdminProxyClient {
                base_url: "http://localhost:3051".to_owned(),
                http_client: reqwest::Client::new(),
            }),
            mode: RunMode::Mock,
            locale: "ja".to_owned(),
            default_locale: "ja".to_owned(),
        }
    }

    fn valid_purchase_form() -> HashMap<String, String> {
        HashMap::from([
            ("locale".to_owned(), "ja".to_owned()),
            ("seal_line1".to_owned(), "黒".to_owned()),
            ("seal_line2".to_owned(), String::new()),
            ("font".to_owned(), "zen_maru_gothic".to_owned()),
            ("shape".to_owned(), "square".to_owned()),
            ("material".to_owned(), "rose_quartz".to_owned()),
            ("recipient_name".to_owned(), "小野光".to_owned()),
            ("phone".to_owned(), "+81 80 6242 2597".to_owned()),
            ("country".to_owned(), "JP".to_owned()),
            ("postal_code".to_owned(), "5500012".to_owned()),
            ("state".to_owned(), "大阪府".to_owned()),
            ("city".to_owned(), "大阪市西区".to_owned()),
            ("address_line1".to_owned(), "立売堀5丁目5-9".to_owned()),
            (
                "address_line2".to_owned(),
                "第二レジデンス春日井503".to_owned(),
            ),
            ("email".to_owned(), "ono@finitefield.org".to_owned()),
            ("terms_agreed".to_owned(), "on".to_owned()),
        ])
    }

    #[tokio::test]
    async fn catalog_load_uses_requested_locale_for_mock_source() {
        let source = CatalogSource::Mock(new_mock_catalog_source("ja"));
        let catalog = load_catalog_with_timeout(&source, "en")
            .await
            .expect("catalog should load");

        let rose_quartz = catalog
            .materials
            .iter()
            .find(|material| material.key == "rose_quartz")
            .expect("rose_quartz material should exist");

        assert_eq!(rose_quartz.label, "Rose Quartz");
        assert_eq!(
            rose_quartz.description,
            "A soft-toned stone with a warm, approachable presence"
        );
        assert_eq!(rose_quartz.shape_label, "Square seal");
    }

    #[tokio::test]
    async fn mock_purchase_returns_confirmation_without_api() {
        let response =
            handle_purchase_impl(mock_state(), Ok(Form(valid_purchase_form())), false).await;

        assert_eq!(response.status(), StatusCode::OK);

        let body = to_bytes(response.into_body(), usize::MAX)
            .await
            .expect("response body should be readable");
        let html = String::from_utf8(body.to_vec()).expect("response body should be utf-8");

        assert!(html.contains("注文を受け付けました（モック）"));
    }

    #[test]
    fn top_page_uses_locale_aware_privacy_policy_url() {
        let template = TopPageTemplate {
            selected_locale: "en".to_owned(),
            top_url: "/".to_owned(),
            design_url: "/design".to_owned(),
            terms_url: "/terms".to_owned(),
            commercial_transactions_url: "/commercial-transactions".to_owned(),
            privacy_policy_url: privacy_policy_url("en"),
        };

        let html = render_html(&template).expect("top page should render");

        assert!(html.contains("href=\"https://finitefield.org/en/privacy/\""));
    }
}
