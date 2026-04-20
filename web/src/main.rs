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
use tower_http::set_header::SetResponseHeaderLayer;
use uuid::Uuid;

const DATASTORE_SCOPE: &str = "https://www.googleapis.com/auth/datastore";
const DEFAULT_KANJI_CANDIDATE_COUNT: usize = 6;
const ADMIN_PROXY_MAX_BODY_BYTES: usize = 16 * 1024 * 1024;
const HX_REDIRECT_HEADER: &str = "hx-redirect";
const WEB_STATIC_DIR: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/static");
const EXTERNAL_LEGAL_BASE_URL: &str = "https://finitefield.org";

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
    site_base_url: String,
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
struct MaterialPhoto {
    asset_id: String,
    storage_path: String,
    alt_i18n: HashMap<String, String>,
    sort_order: i64,
    is_primary: bool,
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
    color_family: String,
    pattern_primary: String,
    stone_shape: String,
    color_tag_labels: Vec<String>,
    pattern_tag_labels: Vec<String>,
    has_color_tag_labels: bool,
    has_pattern_tag_labels: bool,
    supported_seal_shapes: Vec<String>,
    supported_seal_shapes_csv: String,
    price: i64,
    price_display: String,
    photo_url: String,
    photo_alt: String,
    has_photo: bool,
}

#[derive(Debug, Clone)]
struct MaterialCategory {
    label: String,
    description: String,
    comparison_texture: String,
    comparison_weight: String,
    comparison_usage: String,
    shape: String,
}

#[derive(Debug, Clone)]
struct MaterialFilterOption {
    value: String,
    label: String,
}

#[derive(Debug, Clone, Default)]
struct MaterialFilters {
    color_options: Vec<MaterialFilterOption>,
    pattern_options: Vec<MaterialFilterOption>,
    stone_shape_options: Vec<MaterialFilterOption>,
}

#[derive(Debug, Clone, Default)]
struct MaterialFilterState {
    color_family: String,
    pattern_primary: String,
    stone_shape: String,
}

#[derive(Debug, Clone, Default)]
struct FacetTagLabels {
    labels_by_type: HashMap<String, HashMap<String, String>>,
}

impl FacetTagLabels {
    fn insert(&mut self, facet_type: &str, key: &str, label: &str, aliases: &[String]) {
        let facet_type = normalize_facet_tag_value(facet_type);
        let key = normalize_facet_tag_value(key);
        let label = label.trim().to_owned();
        if facet_type.is_empty() || key.is_empty() || label.is_empty() {
            return;
        }

        let labels = self.labels_by_type.entry(facet_type).or_default();
        labels.insert(key, label.clone());
        for alias in aliases {
            let alias = normalize_facet_tag_value(alias);
            if !alias.is_empty() {
                labels.insert(alias, label.clone());
            }
        }
    }

    fn resolve_or_raw(&self, facet_type: &str, value: &str) -> String {
        let facet_type = normalize_facet_tag_value(facet_type);
        let value = value.trim();
        if facet_type.is_empty() || value.is_empty() {
            return String::new();
        }

        self.labels_by_type
            .get(&facet_type)
            .and_then(|labels| labels.get(&normalize_facet_tag_value(value)).cloned())
            .unwrap_or_else(|| value.to_owned())
    }

    fn resolve_list(&self, facet_type: &str, values: &[String]) -> Vec<String> {
        let mut labels = Vec::new();
        let mut seen = HashSet::new();

        for value in values {
            let label = self.resolve_or_raw(facet_type, value);
            if label.is_empty() {
                continue;
            }

            if seen.insert(normalize_facet_tag_value(&label)) {
                labels.push(label);
            }
        }

        labels
    }
}

#[derive(Debug, Clone)]
struct StoneListingRecord {
    key: String,
    material_key: String,
    title: String,
    description: String,
    price_by_currency: HashMap<String, i64>,
    supported_seal_shapes: Vec<String>,
    color_family: String,
    pattern_primary: String,
    color_tags: Vec<String>,
    pattern_tags: Vec<String>,
    stone_shape: String,
    photos: Vec<MaterialPhoto>,
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
    material_filters: MaterialFilters,
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
    listing_label: String,
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
    page_title: String,
    meta_description: String,
    robots_meta: String,
    canonical_url: String,
    lang_ja_url: String,
    lang_en_url: String,
    company_url: String,
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
    material_filters: MaterialFilters,
    selected_color_family: String,
    selected_pattern_primary: String,
    selected_stone_shape: String,
    default_font_key: String,
    default_font_label: String,
    selected_locale: String,
    page_title: String,
    meta_description: String,
    robots_meta: String,
    canonical_url: String,
    lang_ja_url: String,
    lang_en_url: String,
    company_url: String,
    purchase_action_url: String,
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
    listing_id: String,
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
    listing_label: String,
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
    page_title: String,
    meta_description: String,
    robots_meta: String,
    canonical_url: String,
    lang_ja_url: String,
    lang_en_url: String,
    company_url: String,
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
    page_title: String,
    meta_description: String,
    robots_meta: String,
    canonical_url: String,
    lang_ja_url: String,
    lang_en_url: String,
    company_url: String,
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
    page_title: String,
    meta_description: String,
    robots_meta: String,
    canonical_url: String,
    lang_ja_url: String,
    lang_en_url: String,
    company_url: String,
    top_url: String,
    terms_url: String,
    commercial_transactions_url: String,
    contact_url: String,
    privacy_policy_url: String,
}

#[derive(Template)]
#[template(path = "terms.html")]
struct TermsTemplate {
    contact_url: String,
    selected_locale: String,
    page_title: String,
    meta_description: String,
    robots_meta: String,
    canonical_url: String,
    lang_ja_url: String,
    lang_en_url: String,
    company_url: String,
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
    color_family: Option<String>,
    pattern_primary: Option<String>,
    stone_shape: Option<String>,
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
                let mut catalog = new_mock_catalog_source(locale).catalog;
                catalog.material_filters = build_material_filters(
                    &catalog.materials,
                    &mock_facet_tag_labels(locale),
                    locale,
                );
                Ok(catalog)
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
        let facet_tag_labels = match self.load_facet_tag_labels(&client, &parent, locale).await {
            Ok(labels) => labels,
            Err(error) => match fallback_catalog.as_ref() {
                Some(_) => {
                    eprintln!(
                        "warning: failed to load facet_tags from firestore: {error}; using empty facet labels for dev"
                    );
                    FacetTagLabels::default()
                }
                None => return Err(error),
            },
        };

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
        let materials = match self
            .load_materials(&client, &parent, locale, &facet_tag_labels)
            .await
        {
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
        let material_filters = build_material_filters(&materials, &facet_tag_labels, locale);

        Ok(CatalogData {
            fonts,
            materials,
            countries,
            material_filters,
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
            let family = read_string_field(&document.fields, "font_family");
            if family.is_empty() {
                bail!("fonts/{doc_id} is missing font_family");
            }
            let mut stylesheet_url = read_string_field(&document.fields, "font_stylesheet_url");
            if stylesheet_url.is_empty() {
                stylesheet_url = build_google_fonts_stylesheet_url(&family).map_err(|error| {
                    anyhow!(
                        "fonts/{doc_id} is missing font_stylesheet_url and URL generation failed: {error}"
                    )
                })?;
            }

            let label =
                resolve_font_label_field(&document.fields, locale, &self.default_locale, &doc_id);
            let kanji_style = read_string_field(&document.fields, "kanji_style");
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
        facet_tag_labels: &FacetTagLabels,
    ) -> Result<Vec<MaterialOption>> {
        let categories = self
            .load_material_categories(client, parent, locale)
            .await?;
        let listings = self.load_stone_listings(client, parent, locale).await?;

        let mut materials = Vec::with_capacity(listings.len());
        for listing in listings {
            let Some(category) = categories.get(&listing.material_key) else {
                eprintln!(
                    "warning: skipping stone_listings/{}: missing materials/{} category",
                    listing.key, listing.material_key
                );
                continue;
            };

            materials.push(build_material_option_from_listing(
                category,
                &listing,
                &facet_tag_labels,
                locale,
                &self.default_locale,
                &self.storage_assets_bucket,
            ));
        }

        if materials.is_empty() {
            bail!("no active materials found in firestore");
        }

        Ok(materials)
    }

    async fn load_material_categories(
        &self,
        client: &FirebaseFirestoreClient,
        parent: &str,
        locale: &str,
    ) -> Result<HashMap<String, MaterialCategory>> {
        let documents = self
            .query_active_documents(client, parent, "materials")
            .await?;

        let mut categories = HashMap::with_capacity(documents.len());
        for document in documents {
            let doc_id = document_id(&document)
                .ok_or_else(|| anyhow!("materials document is missing name"))?;

            let label = resolve_localized_field(
                &document.fields,
                "label_i18n",
                locale,
                &self.default_locale,
                &doc_id,
            );
            let description = resolve_localized_field(
                &document.fields,
                "description_i18n",
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

            categories.insert(
                doc_id.clone(),
                MaterialCategory {
                    label,
                    description,
                    comparison_texture,
                    comparison_weight,
                    comparison_usage,
                    shape: shape.to_owned(),
                },
            );
        }

        if categories.is_empty() {
            bail!("no active materials found in firestore");
        }

        Ok(categories)
    }

    async fn load_facet_tag_labels(
        &self,
        client: &FirebaseFirestoreClient,
        parent: &str,
        locale: &str,
    ) -> Result<FacetTagLabels> {
        let documents = match self
            .run_documents_query(client, parent, "facet_tags", false, false)
            .await
        {
            Ok(documents) => documents,
            Err(error) => {
                eprintln!("warning: failed to load facet_tags from firestore: {error:#}");
                return Ok(FacetTagLabels::default());
            }
        };

        let mut labels = FacetTagLabels::default();
        for document in documents {
            if matches!(read_bool_field(&document.fields, "is_active"), Some(false)) {
                continue;
            }

            let Some(doc_id) = document_id(&document) else {
                eprintln!("warning: skipping facet_tags document with missing name");
                continue;
            };
            let facet_type = normalize_facet_tag_value(
                &first_non_empty(&[
                    Some(read_string_field(&document.fields, "facet_type")),
                    doc_id.split_once(':').map(|(prefix, _)| prefix.to_owned()),
                ])
                .unwrap_or_default(),
            );
            let key = first_non_empty(&[
                Some(read_string_field(&document.fields, "key")),
                doc_id.split_once(':').map(|(_, key)| key.to_owned()),
                Some(doc_id.clone()),
            ])
            .unwrap_or_default();
            if facet_type.is_empty() || key.is_empty() {
                continue;
            }

            let label = resolve_localized_field(
                &document.fields,
                "label_i18n",
                locale,
                &self.default_locale,
                &key,
            );
            let aliases = read_string_array_field(&document.fields, "aliases");
            labels.insert(&facet_type, &key, &label, &aliases);
        }

        Ok(labels)
    }

    async fn load_stone_listings(
        &self,
        client: &FirebaseFirestoreClient,
        parent: &str,
        locale: &str,
    ) -> Result<Vec<StoneListingRecord>> {
        let documents = self
            .run_documents_query(client, parent, "stone_listings", false, true)
            .await?;

        let mut listings = Vec::with_capacity(documents.len());
        for document in documents {
            let doc_id = document_id(&document)
                .ok_or_else(|| anyhow!("stone_listings document is missing name"))?;
            let is_active = read_bool_field(&document.fields, "is_active").unwrap_or(true);
            let status = read_string_field(&document.fields, "status");
            if !stone_listing_is_catalog_visible(is_active, &status) {
                continue;
            }

            let price_by_currency = read_int_map_field(&document.fields, "price_by_currency");
            let price_currency = locale_currency_code(locale);
            if resolve_amount_for_currency(&price_by_currency, price_currency).is_none() {
                eprintln!(
                    "warning: skipping stone_listings/{doc_id}: missing or empty price_by_currency"
                );
                continue;
            }

            let title = resolve_localized_field(
                &document.fields,
                "title_i18n",
                locale,
                &self.default_locale,
                &doc_id,
            );
            let description = resolve_localized_field(
                &document.fields,
                "description_i18n",
                locale,
                &self.default_locale,
                "",
            );
            let facets = read_map_field(&document.fields, "facets");
            let color_family = resolve_localized_field(
                &facets,
                "color_family_i18n",
                locale,
                &self.default_locale,
                "",
            );
            let pattern_primary = read_string_field(&facets, "pattern_primary");
            let stone_shape =
                normalize_stone_shape(&read_string_field(&facets, "stone_shape")).to_owned();
            let color_tags = read_string_array_field(&facets, "color_tags");
            let pattern_tags = read_string_array_field(&facets, "pattern_tags");
            let supported_seal_shapes =
                read_string_array_field(&document.fields, "supported_seal_shapes");
            let photos = read_material_photos(&document.fields);

            listings.push(StoneListingRecord {
                key: doc_id.clone(),
                material_key: read_string_field(&document.fields, "material_key"),
                title,
                description,
                price_by_currency,
                supported_seal_shapes,
                color_family,
                pattern_primary,
                color_tags,
                pattern_tags,
                stone_shape,
                photos,
            });
        }

        if listings.is_empty() {
            bail!("no active stone listings found in firestore");
        }

        Ok(listings)
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

            let shipping_fee_by_currency =
                read_int_map_field(&document.fields, "shipping_fee_by_currency");

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
            .run_documents_query(client, parent, collection, true, false)
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
            left_sort_order.cmp(&right_sort_order).then_with(|| {
                if sort_by_published_at {
                    let left_published_at =
                        read_timestamp_field(&left.fields, "published_at").unwrap_or_default();
                    let right_published_at =
                        read_timestamp_field(&right.fields, "published_at").unwrap_or_default();
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
    site_base_url: String,
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
        .route("/robots.txt", get(handle_robots_txt))
        .route("/sitemap.xml", get(handle_sitemap_xml))
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
        .layer(SetResponseHeaderLayer::if_not_present(
            header::CACHE_CONTROL,
            HeaderValue::from_static("no-cache, no-store, must-revalidate"),
        ))
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
        site_base_url: cfg.site_base_url.clone(),
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
        site_base_url: env::var("HANKO_WEB_SITE_BASE_URL")
            .unwrap_or_default()
            .trim()
            .to_owned(),
        api_base_url: env::var("HANKO_WEB_API_BASE_URL")
            .unwrap_or_default()
            .trim()
            .to_owned(),
        admin_base_url: env_first(&["HANKO_WEB_ADMIN_BASE_URL_PROD", "HANKO_WEB_ADMIN_BASE_URL"]),
        firestore_project_id: None,
        credentials_file: None,
        storage_assets_bucket: None,
    };

    if cfg.port.is_empty() {
        cfg.port = "3052".to_owned();
    }

    if cfg.locale.is_empty() {
        cfg.locale = "en".to_owned();
    }

    if cfg.default_locale.is_empty() {
        cfg.default_locale = "en".to_owned();
    }

    if cfg.site_base_url.is_empty() {
        if matches!(cfg.mode, RunMode::Prod) {
            bail!("prod web requires HANKO_WEB_SITE_BASE_URL");
        }
        cfg.site_base_url = "http://127.0.0.1:3052".to_owned();
    }
    cfg.site_base_url = normalize_site_base_url(&cfg.site_base_url)?;

    if cfg.api_base_url.is_empty() {
        cfg.api_base_url = "http://127.0.0.1:3050".to_owned();
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
    } else if matches!(cfg.mode, RunMode::Dev) {
        cfg.storage_assets_bucket = Some("hanko-field-dev".to_owned());
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
                    color_family: "pink".to_owned(),
                    pattern_primary: "cloud".to_owned(),
                    stone_shape: "oval".to_owned(),
                    color_tag_labels: if english {
                        vec!["Soft Pink".to_owned()]
                    } else {
                        vec!["淡桃".to_owned()]
                    },
                    pattern_tag_labels: if english {
                        vec!["Cloud".to_owned()]
                    } else {
                        vec!["雲状".to_owned()]
                    },
                    has_color_tag_labels: true,
                    has_pattern_tag_labels: true,
                    supported_seal_shapes: vec!["square".to_owned()],
                    supported_seal_shapes_csv: "square".to_owned(),
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
                    color_family: "blue".to_owned(),
                    pattern_primary: "speckled".to_owned(),
                    stone_shape: "square".to_owned(),
                    color_tag_labels: if english {
                        vec!["Deep Blue".to_owned()]
                    } else {
                        vec!["深青".to_owned()]
                    },
                    pattern_tag_labels: if english {
                        vec!["Speckled".to_owned()]
                    } else {
                        vec!["点状".to_owned()]
                    },
                    has_color_tag_labels: true,
                    has_pattern_tag_labels: true,
                    supported_seal_shapes: vec!["round".to_owned()],
                    supported_seal_shapes_csv: "round".to_owned(),
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
                    color_family: "green".to_owned(),
                    pattern_primary: "marble".to_owned(),
                    stone_shape: "round".to_owned(),
                    color_tag_labels: if english {
                        vec!["Deep Green".to_owned()]
                    } else {
                        vec!["濃緑".to_owned()]
                    },
                    pattern_tag_labels: if english {
                        vec!["Banded".to_owned()]
                    } else {
                        vec!["縞".to_owned()]
                    },
                    has_color_tag_labels: true,
                    has_pattern_tag_labels: true,
                    supported_seal_shapes: vec!["square".to_owned()],
                    supported_seal_shapes_csv: "square".to_owned(),
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
            material_filters: MaterialFilters::default(),
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
    let site_base_url = state.site_base_url.as_str();

    if let Some(path) = checkout_redirect_path(site_base_url, &query, &selected_locale) {
        return Redirect::to(&path).into_response();
    }

    let template = TopPageTemplate {
        page_title: localized_text(
            &selected_locale,
            "宝石印鑑をオンラインでデザイン | STONE SIGNATURE",
            "Custom gemstone seals | STONE SIGNATURE",
        ),
        meta_description: localized_text(
            &selected_locale,
            "宝石印鑑をオンラインでデザインして、日本語または英語で注文できます。",
            "Design custom hand-carved gemstone seals online and order in English or Japanese.",
        ),
        robots_meta: "index,follow".to_owned(),
        canonical_url: top_url(site_base_url, "en"),
        lang_ja_url: top_url(site_base_url, "ja"),
        lang_en_url: top_url(site_base_url, "en"),
        company_url: company_url(site_base_url),
        selected_locale: selected_locale.clone(),
        top_url: localized_navigation_page_url(site_base_url, "/", &selected_locale),
        design_url: localized_navigation_page_url(site_base_url, "/design", &selected_locale),
        terms_url: localized_navigation_page_url(site_base_url, "/terms", &selected_locale),
        commercial_transactions_url: localized_navigation_page_url(
            site_base_url,
            "/commercial-transactions",
            &selected_locale,
        ),
        privacy_policy_url: privacy_policy_url(site_base_url, &selected_locale),
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
    let site_base_url = state.site_base_url.as_str();

    if let Some(path) = checkout_redirect_path(site_base_url, &query, &selected_locale) {
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
    let material_filter_state = material_filter_state_from_query(&query);

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
    let materials = catalog.materials;

    let template = PageTemplate {
        font_stylesheet_urls: collect_font_stylesheet_urls(&catalog.fonts),
        default_font_key: default_font.key.clone(),
        default_font_label: default_font.label.clone(),
        fonts: catalog.fonts,
        materials,
        countries: catalog.countries,
        material_filters: catalog.material_filters,
        selected_color_family: material_filter_state.color_family.clone(),
        selected_pattern_primary: material_filter_state.pattern_primary.clone(),
        selected_stone_shape: material_filter_state.stone_shape.clone(),
        page_title: localized_text(
            &selected_locale,
            "デザイン作成 | STONE SIGNATURE",
            "Design your seal | STONE SIGNATURE",
        ),
        meta_description: localized_text(
            &selected_locale,
            "印影、出品個体、お届け先を順に選んで、そのまま購入まで進めます。",
            "Choose the seal text, listing, and shipping details, then continue to checkout.",
        ),
        robots_meta: "index,follow".to_owned(),
        purchase_action_url: if state.mode == RunMode::Mock {
            site_url(site_base_url, "/mock/purchase")
        } else {
            site_url(site_base_url, "/purchase")
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
        canonical_url: design_url(site_base_url, "en"),
        lang_ja_url: design_url_with_filters(site_base_url, "ja", &material_filter_state),
        lang_en_url: design_url_with_filters(site_base_url, "en", &material_filter_state),
        company_url: company_url(site_base_url),
        top_url: localized_navigation_page_url(site_base_url, "/", &selected_locale),
        terms_url: localized_navigation_page_url(site_base_url, "/terms", &selected_locale),
        commercial_transactions_url: localized_navigation_page_url(
            site_base_url,
            "/commercial-transactions",
            &selected_locale,
        ),
        privacy_policy_url: privacy_policy_url(site_base_url, &selected_locale),
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

fn material_filter_state_from_query(query: &PaymentRedirectQuery) -> MaterialFilterState {
    MaterialFilterState {
        color_family: normalize_facet_tag_value(query.color_family.as_deref().unwrap_or_default()),
        pattern_primary: normalize_facet_tag_value(
            query.pattern_primary.as_deref().unwrap_or_default(),
        ),
        stone_shape: normalize_stone_shape_optional(
            query.stone_shape.as_deref().unwrap_or_default(),
        )
        .unwrap_or_default()
        .to_owned(),
    }
}

fn checkout_redirect_path(
    base_url: &str,
    query: &PaymentRedirectQuery,
    locale: &str,
) -> Option<String> {
    let checkout = query.checkout.as_deref()?.trim().to_lowercase();
    let base_path = match checkout.as_str() {
        "success" => "/payment/success",
        "cancel" => "/payment/failure",
        _ => return None,
    };

    let mut params = locale_query_params(locale);
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

    let query = if params.is_empty() {
        String::new()
    } else {
        format!("?{}", params.join("&"))
    };

    Some(site_url(base_url, &format!("{base_path}{query}")))
}

fn payment_result_locale_url(
    base_url: &str,
    base_path: &str,
    query: &PaymentRedirectQuery,
    locale: &str,
) -> String {
    let normalized = parse_supported_locale(locale).unwrap_or("en");
    let mut params = locale_query_params(normalized);

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

    let query = if params.is_empty() {
        String::new()
    } else {
        format!("?{}", params.join("&"))
    };

    site_url(base_url, &format!("{base_path}{query}"))
}

#[cfg(test)]
fn payment_result_navigation_url(
    base_url: &str,
    base_path: &str,
    query: &PaymentRedirectQuery,
    locale: &str,
) -> String {
    let normalized = parse_supported_locale(locale).unwrap_or("en");
    let mut params = localized_navigation_query_params(normalized);

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

    let query = if params.is_empty() {
        String::new()
    } else {
        format!("?{}", params.join("&"))
    };

    site_url(base_url, &format!("{base_path}{query}"))
}

async fn handle_robots_txt(State(state): State<AppState>) -> Response {
    (
        [(header::CONTENT_TYPE, "text/plain; charset=utf-8")],
        build_robots_txt(&state.site_base_url),
    )
        .into_response()
}

async fn handle_sitemap_xml(State(state): State<AppState>) -> Response {
    (
        [(header::CONTENT_TYPE, "application/xml; charset=utf-8")],
        build_sitemap_xml(&state.site_base_url),
    )
        .into_response()
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
    let site_base_url = state.site_base_url.as_str();
    let order_id = query
        .order_id
        .as_deref()
        .unwrap_or_default()
        .trim()
        .to_owned();
    let template = PaymentSuccessTemplate {
        contact_url: inquiry_url(site_base_url, &selected_locale),
        commercial_transactions_url: localized_navigation_page_url(
            site_base_url,
            "/commercial-transactions",
            &selected_locale,
        ),
        page_title: localized_text(
            &selected_locale,
            "支払い完了 | STONE SIGNATURE",
            "Payment complete | STONE SIGNATURE",
        ),
        meta_description: localized_text(
            &selected_locale,
            "ご注文の支払いが完了しました。確認メールをご確認ください。",
            "Your payment was received. Check your confirmation email for order details and next steps.",
        ),
        robots_meta: "noindex,follow".to_owned(),
        canonical_url: payment_result_locale_url(site_base_url, "/payment/success", &query, "en"),
        has_order_id: !order_id.is_empty(),
        order_id,
        has_session_id: !session_id.is_empty(),
        session_id,
        lang_en_url: payment_result_locale_url(site_base_url, "/payment/success", &query, "en"),
        lang_ja_url: payment_result_locale_url(site_base_url, "/payment/success", &query, "ja"),
        company_url: company_url(site_base_url),
        top_url: localized_navigation_page_url(site_base_url, "/", &selected_locale),
        terms_url: localized_navigation_page_url(site_base_url, "/terms", &selected_locale),
        privacy_policy_url: privacy_policy_url(site_base_url, &selected_locale),
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
    let site_base_url = state.site_base_url.as_str();
    let order_id = query
        .order_id
        .as_deref()
        .unwrap_or_default()
        .trim()
        .to_owned();
    let template = PaymentFailureTemplate {
        contact_url: inquiry_url(site_base_url, &selected_locale),
        commercial_transactions_url: localized_navigation_page_url(
            site_base_url,
            "/commercial-transactions",
            &selected_locale,
        ),
        page_title: localized_text(
            &selected_locale,
            "支払い未完了 | STONE SIGNATURE",
            "Payment incomplete | STONE SIGNATURE",
        ),
        meta_description: localized_text(
            &selected_locale,
            "お支払いが完了しませんでした。カード情報をご確認のうえ、購入画面から再度お試しください。",
            "Payment did not complete. Check your card details and return to the purchase page to try again.",
        ),
        robots_meta: "noindex,follow".to_owned(),
        canonical_url: payment_result_locale_url(site_base_url, "/payment/failure", &query, "en"),
        has_order_id: !order_id.is_empty(),
        order_id,
        lang_en_url: payment_result_locale_url(site_base_url, "/payment/failure", &query, "en"),
        lang_ja_url: payment_result_locale_url(site_base_url, "/payment/failure", &query, "ja"),
        company_url: company_url(site_base_url),
        top_url: localized_navigation_page_url(site_base_url, "/", &selected_locale),
        design_url: localized_navigation_page_url(site_base_url, "/design", &selected_locale),
        terms_url: localized_navigation_page_url(site_base_url, "/terms", &selected_locale),
        privacy_policy_url: privacy_policy_url(site_base_url, &selected_locale),
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
    let site_base_url = state.site_base_url.as_str();
    let lang_ja_url = commercial_transactions_url(site_base_url, "ja");
    let lang_en_url = commercial_transactions_url(site_base_url, "en");
    let template = CommercialTransactionsTemplate {
        contact_url: inquiry_url(site_base_url, &selected_locale),
        page_title: localized_text(
            &selected_locale,
            "特定商取引法に基づく表記 | STONE SIGNATURE",
            "Legal Notice | STONE SIGNATURE",
        ),
        meta_description: localized_text(
            &selected_locale,
            "販売業者情報、支払い方法、配送、返品など、特定商取引法に基づく表記をご確認ください。",
            "Read the legal notice for STONE SIGNATURE, including seller information, payment methods, delivery, and returns.",
        ),
        robots_meta: "index,follow".to_owned(),
        canonical_url: lang_en_url.clone(),
        lang_ja_url,
        lang_en_url,
        company_url: company_url(site_base_url),
        top_url: localized_navigation_page_url(site_base_url, "/", &selected_locale),
        commercial_transactions_url: localized_navigation_page_url(
            site_base_url,
            "/commercial-transactions",
            &selected_locale,
        ),
        terms_url: localized_navigation_page_url(site_base_url, "/terms", &selected_locale),
        privacy_policy_url: privacy_policy_url(site_base_url, &selected_locale),
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
    let site_base_url = state.site_base_url.as_str();
    let lang_ja_url = terms_url(site_base_url, "ja");
    let lang_en_url = terms_url(site_base_url, "en");
    let template = TermsTemplate {
        contact_url: inquiry_url(site_base_url, &selected_locale),
        page_title: localized_text(
            &selected_locale,
            "利用規約 | STONE SIGNATURE",
            "Terms of Service | STONE SIGNATURE",
        ),
        meta_description: localized_text(
            &selected_locale,
            "注文、支払い、配送、返品、準拠法など、STONE SIGNATURE の利用規約をご確認ください。",
            "Read the STONE SIGNATURE terms of service, including order formation, payment, delivery, returns, and governing law.",
        ),
        robots_meta: "index,follow".to_owned(),
        canonical_url: lang_en_url.clone(),
        lang_ja_url,
        lang_en_url,
        company_url: company_url(site_base_url),
        terms_url: localized_navigation_page_url(site_base_url, "/terms", &selected_locale),
        commercial_transactions_url: localized_navigation_page_url(
            site_base_url,
            "/commercial-transactions",
            &selected_locale,
        ),
        privacy_policy_url: privacy_policy_url(site_base_url, &selected_locale),
        top_url: localized_navigation_page_url(site_base_url, "/", &selected_locale),
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
    let listing_by_key = catalog
        .materials
        .iter()
        .cloned()
        .map(|listing| (listing.key.clone(), listing))
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
    let listing_id = form_value(&form, "listing_id");
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

    let Some(listing) = listing_by_key.get(&listing_id) else {
        result.error = localized_text(
            &order_locale,
            "出品個体を選択してください。",
            "Please choose a listing.",
        );
        return render_purchase_result(&result);
    };
    if !listing.supported_seal_shapes.is_empty()
        && !listing
            .supported_seal_shapes
            .iter()
            .any(|supported_shape| supported_shape.eq_ignore_ascii_case(&shape_key))
    {
        result.error = localized_text(
            &order_locale,
            "選択した形状に対応する出品個体を選択してください。",
            "Please choose a listing that matches the selected shape.",
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

    let subtotal = listing.price;
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
        listing_id: listing.key.clone(),
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
    result.listing_label = listing.label.clone();
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
        listing_label: data.listing_label.clone(),
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
    "en".to_owned()
}

fn parse_supported_locale(raw: &str) -> Option<&'static str> {
    let normalized = raw.trim().to_lowercase();
    if normalized.starts_with("ja") || normalized == "jp" {
        return Some("ja");
    }
    if normalized.starts_with("en") {
        return Some("en");
    }
    None
}

fn site_url(base_url: &str, path: &str) -> String {
    let base = reqwest::Url::parse(base_url.trim_end_matches('/'))
        .expect("site base URL must be a valid absolute URL");
    base.join(path)
        .expect("failed to join site base URL with path")
        .to_string()
}

fn normalize_site_base_url(raw: &str) -> Result<String> {
    let trimmed = raw.trim().trim_end_matches('/');
    let url = reqwest::Url::parse(trimmed)
        .with_context(|| format!("invalid HANKO_WEB_SITE_BASE_URL {trimmed:?}"))?;
    if url.scheme() != "http" && url.scheme() != "https" {
        bail!("HANKO_WEB_SITE_BASE_URL must use http or https");
    }
    Ok(url.as_str().trim_end_matches('/').to_owned())
}

fn locale_query_params(locale: &str) -> Vec<String> {
    let normalized = parse_supported_locale(locale).unwrap_or("en");
    if normalized == "ja" {
        vec!["lang=ja".to_owned()]
    } else {
        Vec::new()
    }
}

fn localized_page_path(path: &str, locale: &str) -> String {
    let normalized = parse_supported_locale(locale).unwrap_or("en");
    if normalized == "ja" {
        format!("{path}?lang=ja")
    } else {
        path.to_owned()
    }
}

fn localized_page_url(base_url: &str, path: &str, locale: &str) -> String {
    site_url(base_url, &localized_page_path(path, locale))
}

fn localized_navigation_query_params(locale: &str) -> Vec<String> {
    let normalized = parse_supported_locale(locale).unwrap_or("en");
    if normalized == "ja" || normalized == "en" {
        vec![format!("lang={normalized}")]
    } else {
        Vec::new()
    }
}

fn localized_navigation_page_path(path: &str, locale: &str) -> String {
    let params = localized_navigation_query_params(locale);
    if params.is_empty() {
        path.to_owned()
    } else {
        format!("{path}?{}", params.join("&"))
    }
}

fn localized_navigation_page_url(base_url: &str, path: &str, locale: &str) -> String {
    site_url(base_url, &localized_navigation_page_path(path, locale))
}

fn privacy_policy_url(_base_url: &str, locale: &str) -> String {
    let normalized = parse_supported_locale(locale).unwrap_or("en");
    if normalized == "ja" {
        return site_url(EXTERNAL_LEGAL_BASE_URL, "/privacy/");
    }
    site_url(EXTERNAL_LEGAL_BASE_URL, &format!("/{normalized}/privacy/"))
}

fn commercial_transactions_url(base_url: &str, locale: &str) -> String {
    localized_page_url(base_url, "/commercial-transactions", locale)
}

fn top_url(base_url: &str, locale: &str) -> String {
    localized_page_url(base_url, "/", locale)
}

fn design_url(base_url: &str, locale: &str) -> String {
    localized_page_url(base_url, "/design", locale)
}

fn design_url_with_filters(base_url: &str, locale: &str, filters: &MaterialFilterState) -> String {
    let base = reqwest::Url::parse(base_url.trim_end_matches('/'))
        .expect("site base URL must be a valid absolute URL");
    let mut url = base
        .join(&localized_page_path("/design", locale))
        .expect("failed to join site base URL with path");

    {
        let mut query_pairs = url.query_pairs_mut();
        if !filters.color_family.is_empty() {
            query_pairs.append_pair("color_family", &filters.color_family);
        }
        if !filters.pattern_primary.is_empty() {
            query_pairs.append_pair("pattern_primary", &filters.pattern_primary);
        }
        if !filters.stone_shape.is_empty() {
            query_pairs.append_pair("stone_shape", &filters.stone_shape);
        }
    }

    url.to_string()
}

fn terms_url(base_url: &str, locale: &str) -> String {
    localized_page_url(base_url, "/terms", locale)
}

fn inquiry_url(_base_url: &str, locale: &str) -> String {
    let normalized = parse_supported_locale(locale).unwrap_or("en");
    if normalized == "ja" {
        return site_url(EXTERNAL_LEGAL_BASE_URL, "/contact/");
    }
    site_url(EXTERNAL_LEGAL_BASE_URL, &format!("/{normalized}/contact/"))
}

fn company_url(_base_url: &str) -> String {
    site_url(EXTERNAL_LEGAL_BASE_URL, "/company/")
}

fn build_robots_txt(base_url: &str) -> String {
    let sitemap_url = site_url(base_url, "/sitemap.xml");
    format!(
        "User-agent: *\nDisallow: /admin\nDisallow: /mock\nDisallow: /kanji\nDisallow: /purchase\nDisallow: /payment/\nSitemap: {sitemap_url}\n"
    )
}

fn sitemap_url_entry(base_url: &str, path: &str) -> String {
    let en_url = localized_page_url(base_url, path, "en");
    let ja_url = localized_page_url(base_url, path, "ja");
    format!(
        "  <url>\n    <loc>{en_url}</loc>\n    <xhtml:link rel=\"alternate\" hreflang=\"en\" href=\"{en_url}\" />\n    <xhtml:link rel=\"alternate\" hreflang=\"ja\" href=\"{ja_url}\" />\n    <xhtml:link rel=\"alternate\" hreflang=\"x-default\" href=\"{en_url}\" />\n  </url>\n"
    )
}

fn build_sitemap_xml(base_url: &str) -> String {
    let mut sitemap = String::from(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\" xmlns:xhtml=\"http://www.w3.org/1999/xhtml\">\n",
    );
    for path in ["/", "/design", "/terms", "/commercial-transactions"] {
        sitemap.push_str(&sitemap_url_entry(base_url, path));
    }
    sitemap.push_str("</urlset>\n");
    sitemap
}

fn localized_text(locale: &str, ja: &str, en: &str) -> String {
    if parse_supported_locale(locale) == Some("en") {
        en.to_owned()
    } else {
        ja.to_owned()
    }
}

fn first_non_empty(values: &[Option<String>]) -> Option<String> {
    values
        .iter()
        .filter_map(|value| value.as_deref())
        .map(str::trim)
        .find(|value| !value.is_empty())
        .map(ToOwned::to_owned)
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

fn normalize_stone_shape(raw: &str) -> &'static str {
    normalize_stone_shape_optional(raw).unwrap_or("square")
}

fn normalize_stone_shape_optional(raw: &str) -> Option<&'static str> {
    match raw.trim().to_ascii_lowercase().as_str() {
        "round" => Some("round"),
        "square" => Some("square"),
        "oval" | "ellipse" | "elliptical" => Some("oval"),
        _ => None,
    }
}

fn stone_listing_is_published(status: &str) -> bool {
    status.trim().eq_ignore_ascii_case("published")
}

fn stone_listing_is_catalog_visible(is_active: bool, status: &str) -> bool {
    is_active && stone_listing_is_published(status)
}

fn normalize_facet_tag_value(raw: &str) -> String {
    raw.trim().to_ascii_lowercase()
}

fn join_filter_values(values: &[String]) -> String {
    values
        .iter()
        .map(|value| value.trim())
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
        .collect::<Vec<_>>()
        .join("|")
}

fn stone_shape_filter_label(stone_shape: &str, locale: &str) -> &'static str {
    let english = parse_supported_locale(locale) == Some("en");
    match normalize_stone_shape(stone_shape) {
        "round" => {
            if english {
                "Round"
            } else {
                "丸"
            }
        }
        "oval" => {
            if english {
                "Oval"
            } else {
                "楕円"
            }
        }
        _ => {
            if english {
                "Square"
            } else {
                "四角"
            }
        }
    }
}

fn mock_facet_tag_labels(locale: &str) -> FacetTagLabels {
    let english = parse_supported_locale(locale) == Some("en");
    let mut labels = FacetTagLabels::default();

    if english {
        labels.insert("color", "pink", "Soft Pink", &[]);
        labels.insert("color", "blue", "Deep Blue", &[]);
        labels.insert("color", "green", "Deep Green", &[]);
        labels.insert("pattern", "cloud", "Cloud", &[]);
        labels.insert("pattern", "speckled", "Speckled", &[]);
        labels.insert("pattern", "marble", "Banded", &[]);
    } else {
        labels.insert("color", "pink", "淡桃", &[]);
        labels.insert("color", "blue", "深青", &[]);
        labels.insert("color", "green", "濃緑", &[]);
        labels.insert("pattern", "cloud", "雲状", &[]);
        labels.insert("pattern", "speckled", "点状", &[]);
        labels.insert("pattern", "marble", "縞", &[]);
    }

    labels
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
        "oval" => {
            if english {
                "Oval seal"
            } else {
                "楕円印"
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

fn material_supported_shape_label(shapes: &[String], locale: &str) -> String {
    let mut labels = Vec::new();
    for shape_key in ["square", "round"] {
        if shapes
            .iter()
            .any(|shape| normalize_material_shape(shape) == shape_key)
        {
            labels.push(material_shape_label(shape_key, locale));
        }
    }
    labels.join(" / ")
}

fn build_material_option_from_listing(
    category: &MaterialCategory,
    listing: &StoneListingRecord,
    facet_tag_labels: &FacetTagLabels,
    locale: &str,
    default_locale: &str,
    storage_assets_bucket: &str,
) -> MaterialOption {
    let price_currency = locale_currency_code(locale);
    let price =
        resolve_amount_for_currency(&listing.price_by_currency, price_currency).unwrap_or_default();
    let title = if listing.title.is_empty() {
        category.label.clone()
    } else {
        listing.title.clone()
    };
    let description = if listing.description.is_empty() {
        category.description.clone()
    } else {
        listing.description.clone()
    };
    let shape = listing
        .supported_seal_shapes
        .first()
        .map(|shape| normalize_material_shape(shape).to_owned())
        .unwrap_or_else(|| category.shape.clone());
    let shape_label = if listing.supported_seal_shapes.is_empty() {
        material_shape_label(&shape, locale).to_owned()
    } else {
        let label = material_supported_shape_label(&listing.supported_seal_shapes, locale);
        if label.is_empty() {
            material_shape_label(&shape, locale).to_owned()
        } else {
            label
        }
    };

    let (photo_url, photo_alt, has_photo) = resolve_listing_photo(
        &listing.photos,
        storage_assets_bucket,
        locale,
        default_locale,
    );
    let photo_alt = if has_photo && photo_alt.is_empty() {
        localized_text(locale, &format!("{title}の写真"), &format!("{title} photo"))
    } else {
        photo_alt
    };
    let color_tag_labels = facet_tag_labels.resolve_list("color", &listing.color_tags);
    let pattern_tag_labels = facet_tag_labels.resolve_list("pattern", &listing.pattern_tags);
    let has_color_tag_labels = !color_tag_labels.is_empty();
    let has_pattern_tag_labels = !pattern_tag_labels.is_empty();
    let supported_seal_shapes_csv = join_filter_values(&listing.supported_seal_shapes);

    MaterialOption {
        key: listing.key.clone(),
        label: title,
        description,
        comparison_texture: category.comparison_texture.clone(),
        comparison_weight: category.comparison_weight.clone(),
        comparison_usage: category.comparison_usage.clone(),
        price_by_currency: listing.price_by_currency.clone(),
        shape,
        shape_label,
        color_family: listing.color_family.clone(),
        pattern_primary: listing.pattern_primary.clone(),
        stone_shape: listing.stone_shape.clone(),
        color_tag_labels,
        pattern_tag_labels,
        has_color_tag_labels,
        has_pattern_tag_labels,
        supported_seal_shapes: listing.supported_seal_shapes.clone(),
        supported_seal_shapes_csv,
        price,
        price_display: format_currency_amount(price, price_currency),
        photo_url,
        photo_alt,
        has_photo,
    }
}

fn build_material_filters(
    materials: &[MaterialOption],
    facet_tag_labels: &FacetTagLabels,
    locale: &str,
) -> MaterialFilters {
    let color_options = collect_canonical_filter_options(
        materials,
        "color",
        |material| material.color_family.as_str(),
        facet_tag_labels,
    );
    let pattern_options = collect_canonical_filter_options(
        materials,
        "pattern",
        |material| material.pattern_primary.as_str(),
        facet_tag_labels,
    );
    let stone_shape_options = collect_stone_shape_filter_options(materials, locale);

    MaterialFilters {
        color_options,
        pattern_options,
        stone_shape_options,
    }
}

fn collect_canonical_filter_options(
    materials: &[MaterialOption],
    facet_type: &str,
    value_fn: impl Fn(&MaterialOption) -> &str,
    facet_tag_labels: &FacetTagLabels,
) -> Vec<MaterialFilterOption> {
    let mut seen = HashSet::new();
    let mut options = Vec::new();

    for material in materials {
        let value = normalize_facet_tag_value(value_fn(material));
        if value.is_empty() || !seen.insert(value.clone()) {
            continue;
        }

        options.push(MaterialFilterOption {
            value: value.clone(),
            label: facet_tag_labels.resolve_or_raw(facet_type, &value),
        });
    }

    options
}

fn collect_stone_shape_filter_options(
    materials: &[MaterialOption],
    locale: &str,
) -> Vec<MaterialFilterOption> {
    let mut seen = HashSet::new();
    let mut options = Vec::new();

    for material in materials {
        let value = normalize_stone_shape(&material.stone_shape).to_owned();
        if value.is_empty() || !seen.insert(value.clone()) {
            continue;
        }

        options.push(MaterialFilterOption {
            label: stone_shape_filter_label(&value, locale).to_owned(),
            value,
        });
    }

    options.sort_by(|left, right| {
        material_shape_sort_order(&left.value).cmp(&material_shape_sort_order(&right.value))
    });
    options
}

#[allow(dead_code)]
fn filter_materials_by_facets(
    materials: &[MaterialOption],
    filter_state: &MaterialFilterState,
) -> Vec<MaterialOption> {
    materials
        .iter()
        .filter(|material| {
            let matches_color_family = filter_state.color_family.is_empty()
                || normalize_facet_tag_value(&material.color_family) == filter_state.color_family;
            let matches_pattern_primary = filter_state.pattern_primary.is_empty()
                || normalize_facet_tag_value(&material.pattern_primary)
                    == filter_state.pattern_primary;
            let matches_stone_shape = filter_state.stone_shape.is_empty()
                || normalize_stone_shape(&material.stone_shape) == filter_state.stone_shape;

            matches_color_family && matches_pattern_primary && matches_stone_shape
        })
        .cloned()
        .collect()
}

fn material_shape_sort_order(shape: &str) -> i32 {
    match normalize_stone_shape(shape) {
        "square" => 0,
        "round" => 1,
        "oval" => 2,
        _ => 3,
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
        "oval" => Some(if english { "Oval seal" } else { "楕円印" }),
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
    locale: &str,
    default_locale: &str,
    fallback: &str,
) -> String {
    let values = read_string_map_field(data, i18n_field);
    let localized = resolve_localized_text(&values, locale, default_locale);
    if !localized.is_empty() {
        return localized;
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

fn read_timestamp_field(data: &BTreeMap<String, JsonValue>, key: &str) -> Option<String> {
    let value = data.get(key)?;
    let raw = value
        .get("timestampValue")
        .and_then(JsonValue::as_str)
        .or_else(|| value.as_str())?;

    let trimmed = raw.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_owned())
    }
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

#[cfg(test)]
fn resolve_material_photo(
    data: &BTreeMap<String, JsonValue>,
    storage_assets_bucket: &str,
    locale: &str,
    default_locale: &str,
) -> (String, String, bool) {
    if let Some((storage_path, storage_alt)) =
        select_primary_material_photo(data, locale, default_locale)
    {
        let photo_url = build_storage_media_url(storage_assets_bucket, &storage_path);
        if !photo_url.is_empty() {
            let photo_alt = if storage_alt.is_empty() {
                resolve_localized_field(data, "photo_alt_i18n", locale, default_locale, "")
            } else {
                storage_alt
            };
            return (photo_url, photo_alt, true);
        }
    }

    let photo_alt = resolve_localized_field(data, "photo_alt_i18n", locale, default_locale, "");
    (String::new(), photo_alt, false)
}

fn resolve_listing_photo(
    photos: &[MaterialPhoto],
    storage_assets_bucket: &str,
    locale: &str,
    default_locale: &str,
) -> (String, String, bool) {
    let Some(photo) = select_primary_listing_photo(photos) else {
        return (String::new(), String::new(), false);
    };

    let photo_url = build_storage_media_url(storage_assets_bucket, &photo.storage_path);
    let photo_alt = resolve_localized_text(&photo.alt_i18n, locale, default_locale);
    let has_photo = !photo_url.is_empty();
    (photo_url, photo_alt, has_photo)
}

fn select_primary_listing_photo(photos: &[MaterialPhoto]) -> Option<&MaterialPhoto> {
    let mut selected: Option<&MaterialPhoto> = None;
    for photo in photos {
        if photo.storage_path.trim().is_empty() {
            continue;
        }
        let replace = match selected {
            Some(current) => {
                if photo.is_primary != current.is_primary {
                    photo.is_primary && !current.is_primary
                } else if photo.sort_order != current.sort_order {
                    photo.sort_order < current.sort_order
                } else {
                    photo.asset_id < current.asset_id
                }
            }
            None => true,
        };
        if replace {
            selected = Some(photo);
        }
    }
    selected
}

#[cfg(test)]
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

    format!(
        "https://storage.googleapis.com/{}/{}",
        normalized_bucket, normalized_path
    )
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
    use serde_json::json;
    use std::collections::{BTreeMap, HashMap};
    use std::sync::Arc;

    const TEST_SITE_BASE_URL: &str = "https://finitefield.org";
    const TEST_ALT_SITE_BASE_URL: &str = "https://inkanfield.org";

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
            site_base_url: TEST_SITE_BASE_URL.to_owned(),
        }
    }

    fn valid_purchase_form() -> HashMap<String, String> {
        HashMap::from([
            ("locale".to_owned(), "ja".to_owned()),
            ("seal_line1".to_owned(), "黒".to_owned()),
            ("seal_line2".to_owned(), String::new()),
            ("font".to_owned(), "zen_maru_gothic".to_owned()),
            ("shape".to_owned(), "square".to_owned()),
            ("listing_id".to_owned(), "rose_quartz".to_owned()),
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
        assert_eq!(rose_quartz.color_tag_labels, vec!["Soft Pink"]);
        assert_eq!(rose_quartz.pattern_tag_labels, vec!["Cloud"]);
        assert!(rose_quartz.has_color_tag_labels);
        assert!(rose_quartz.has_pattern_tag_labels);

        let color_filters = catalog
            .material_filters
            .color_options
            .iter()
            .map(|option| (option.value.as_str(), option.label.as_str()))
            .collect::<Vec<_>>();
        assert!(color_filters.contains(&("pink", "Soft Pink")));

        let stone_shape_filters = catalog
            .material_filters
            .stone_shape_options
            .iter()
            .map(|option| option.label.as_str())
            .collect::<Vec<_>>();
        assert_eq!(stone_shape_filters, vec!["Square", "Round", "Oval"]);
    }

    #[test]
    fn stone_listing_status_helper_requires_published() {
        assert!(stone_listing_is_published("published"));
        assert!(stone_listing_is_published(" Published "));
        assert!(!stone_listing_is_published("draft"));
    }

    #[test]
    fn stone_listing_catalog_visibility_requires_active_and_published() {
        assert!(stone_listing_is_catalog_visible(true, "published"));
        assert!(stone_listing_is_catalog_visible(true, " Published "));
        assert!(!stone_listing_is_catalog_visible(false, "published"));
        assert!(!stone_listing_is_catalog_visible(true, "draft"));
    }

    #[test]
    fn material_filter_state_omits_missing_or_invalid_stone_shape() {
        let missing = material_filter_state_from_query(&PaymentRedirectQuery {
            color_family: Some("Green".to_owned()),
            pattern_primary: Some("Cloud".to_owned()),
            ..PaymentRedirectQuery::default()
        });
        assert_eq!(missing.color_family, "green");
        assert_eq!(missing.pattern_primary, "cloud");
        assert!(missing.stone_shape.is_empty());
        assert_eq!(
            design_url_with_filters(TEST_SITE_BASE_URL, "ja", &missing),
            "https://finitefield.org/design?lang=ja&color_family=green&pattern_primary=cloud"
        );

        let invalid = material_filter_state_from_query(&PaymentRedirectQuery {
            stone_shape: Some("triangle".to_owned()),
            ..PaymentRedirectQuery::default()
        });
        assert!(invalid.stone_shape.is_empty());
    }

    #[test]
    fn stone_listing_tag_labels_use_facet_tag_master() {
        let facet_tag_labels = {
            let mut labels = FacetTagLabels::default();
            labels.insert(
                "color",
                "deep_green",
                "濃緑",
                &["forest_green".to_owned(), "dark_green".to_owned()],
            );
            labels.insert("pattern", "cloud", "雲状", &["cloudy".to_owned()]);
            labels
        };

        let category = MaterialCategory {
            label: "翡翠".to_owned(),
            description: "落ち着いた緑の石材".to_owned(),
            comparison_texture: "texture".to_owned(),
            comparison_weight: "weight".to_owned(),
            comparison_usage: "usage".to_owned(),
            shape: "square".to_owned(),
        };
        let listing = StoneListingRecord {
            key: "listing-1".to_owned(),
            material_key: "jade".to_owned(),
            title: "翡翠の一点物".to_owned(),
            description: "個体説明".to_owned(),
            price_by_currency: HashMap::from([("JPY".to_owned(), 150000)]),
            supported_seal_shapes: vec!["square".to_owned()],
            color_family: "green".to_owned(),
            pattern_primary: "cloud".to_owned(),
            color_tags: vec!["forest_green".to_owned()],
            pattern_tags: vec!["cloudy".to_owned(), "cloud".to_owned()],
            stone_shape: "oval".to_owned(),
            photos: vec![],
        };

        let option = build_material_option_from_listing(
            &category,
            &listing,
            &facet_tag_labels,
            "ja",
            "ja",
            "bucket",
        );

        assert_eq!(option.color_tag_labels, vec!["濃緑"]);
        assert_eq!(option.pattern_tag_labels, vec!["雲状"]);
        assert!(option.has_color_tag_labels);
        assert!(option.has_pattern_tag_labels);
    }

    #[test]
    fn material_option_shows_all_supported_seal_shapes() {
        let category = MaterialCategory {
            label: "翡翠".to_owned(),
            description: "落ち着いた緑の石材".to_owned(),
            comparison_texture: "texture".to_owned(),
            comparison_weight: "weight".to_owned(),
            comparison_usage: "usage".to_owned(),
            shape: "square".to_owned(),
        };
        let listing = StoneListingRecord {
            key: "listing-1".to_owned(),
            material_key: "jade".to_owned(),
            title: "翡翠の一点物".to_owned(),
            description: "個体説明".to_owned(),
            price_by_currency: HashMap::from([("JPY".to_owned(), 150000)]),
            supported_seal_shapes: vec!["round".to_owned(), "square".to_owned()],
            color_family: "green".to_owned(),
            pattern_primary: "cloud".to_owned(),
            color_tags: vec![],
            pattern_tags: vec![],
            stone_shape: "oval".to_owned(),
            photos: vec![],
        };

        let option = build_material_option_from_listing(
            &category,
            &listing,
            &FacetTagLabels::default(),
            "ja",
            "ja",
            "bucket",
        );

        assert_eq!(option.shape_label, "角印 / 丸印");
    }

    #[test]
    fn material_option_uses_english_photo_alt_fallback() {
        let category = MaterialCategory {
            label: "翡翠".to_owned(),
            description: "落ち着いた緑の石材".to_owned(),
            comparison_texture: "texture".to_owned(),
            comparison_weight: "weight".to_owned(),
            comparison_usage: "usage".to_owned(),
            shape: "square".to_owned(),
        };
        let listing = StoneListingRecord {
            key: "listing-1".to_owned(),
            material_key: "jade".to_owned(),
            title: "One-of-a-kind Jade 101".to_owned(),
            description: "A refined piece with calm green flowing patterns.".to_owned(),
            price_by_currency: HashMap::from([("USD".to_owned(), 92800)]),
            supported_seal_shapes: vec!["square".to_owned()],
            color_family: "green".to_owned(),
            pattern_primary: "cloud".to_owned(),
            color_tags: vec![],
            pattern_tags: vec![],
            stone_shape: "oval".to_owned(),
            photos: vec![MaterialPhoto {
                asset_id: "mat_jade_01".to_owned(),
                storage_path: "materials/jade/mat_jade_01.webp".to_owned(),
                alt_i18n: HashMap::new(),
                sort_order: 0,
                is_primary: true,
            }],
        };

        let option = build_material_option_from_listing(
            &category,
            &listing,
            &FacetTagLabels::default(),
            "en",
            "ja",
            "bucket",
        );

        assert_eq!(option.photo_alt, "One-of-a-kind Jade 101 photo");
        assert!(option.has_photo);
    }

    #[test]
    fn material_photo_uses_firestore_photos() {
        let mut data = BTreeMap::new();
        data.insert(
            "photos".to_owned(),
            json!({
                "arrayValue": {
                    "values": [
                        {
                            "mapValue": {
                                "fields": {
                                    "asset_id": { "stringValue": "mat_rose_quartz_01" },
                                    "storage_path": {
                                        "stringValue": "materials/rose_quartz/mat_rose_quartz_01.webp"
                                    },
                                    "alt_i18n": {
                                        "mapValue": {
                                            "fields": {
                                                "ja": { "stringValue": "ローズクオーツの出品個体サンプル" }
                                            }
                                        }
                                    },
                                    "sort_order": { "integerValue": "0" },
                                    "is_primary": { "booleanValue": true },
                                    "width": { "integerValue": "1200" },
                                    "height": { "integerValue": "1200" }
                                }
                            }
                        }
                    ]
                }
            }),
        );

        let (photo_url, photo_alt, has_photo) =
            resolve_material_photo(&data, "hanko-field-prod", "ja", "ja");

        assert_eq!(
            photo_url,
            "https://storage.googleapis.com/hanko-field-prod/materials/rose_quartz/mat_rose_quartz_01.webp"
        );
        assert_eq!(photo_alt, "ローズクオーツの出品個体サンプル");
        assert!(has_photo);
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
            page_title: "Custom gemstone seals | STONE SIGNATURE".to_owned(),
            meta_description:
                "Design custom hand-carved gemstone seals online and order in English or Japanese."
                    .to_owned(),
            robots_meta: "index,follow".to_owned(),
            canonical_url: top_url(TEST_SITE_BASE_URL, "en"),
            lang_ja_url: top_url(TEST_SITE_BASE_URL, "ja"),
            lang_en_url: top_url(TEST_SITE_BASE_URL, "en"),
            company_url: company_url(TEST_SITE_BASE_URL),
            top_url: top_url(TEST_SITE_BASE_URL, "en"),
            design_url: design_url(TEST_SITE_BASE_URL, "en"),
            terms_url: terms_url(TEST_SITE_BASE_URL, "en"),
            commercial_transactions_url: commercial_transactions_url(TEST_SITE_BASE_URL, "en"),
            privacy_policy_url: privacy_policy_url(TEST_SITE_BASE_URL, "en"),
        };

        let html = render_html(&template).expect("top page should render");

        assert!(html.contains(r#"<link rel="canonical" href="https://finitefield.org/">"#));
        assert!(html.contains(r#"<title>Custom gemstone seals | STONE SIGNATURE</title>"#));
        assert!(html.contains(
            r#"<meta name="description" content="Design custom hand-carved gemstone seals online and order in English or Japanese.">"#
        ));
        assert!(html.contains(r#"<meta name="robots" content="index,follow">"#));
        assert!(html.contains(
            r#"<link rel="alternate" hreflang="ja" href="https://finitefield.org/?lang=ja">"#
        ));
        assert!(
            html.contains(
                r#"<link rel="alternate" hreflang="en" href="https://finitefield.org/">"#
            )
        );
        assert!(html.contains(
            r#"<link rel="alternate" hreflang="x-default" href="https://finitefield.org/">"#
        ));
        assert!(html.contains("href=\"https://finitefield.org/en/privacy/\""));
        assert!(html.contains("href=\"https://finitefield.org/company/\""));
    }

    #[test]
    fn top_page_uses_logo_image_left_of_title() {
        let template = TopPageTemplate {
            selected_locale: "ja".to_owned(),
            page_title: "宝石印鑑をオンラインでデザイン | STONE SIGNATURE".to_owned(),
            meta_description:
                "宝石印鑑をオンラインでデザインして、日本語または英語で注文できます。".to_owned(),
            robots_meta: "index,follow".to_owned(),
            canonical_url: top_url(TEST_SITE_BASE_URL, "en"),
            lang_ja_url: top_url(TEST_SITE_BASE_URL, "ja"),
            lang_en_url: top_url(TEST_SITE_BASE_URL, "en"),
            company_url: company_url(TEST_SITE_BASE_URL),
            top_url: top_url(TEST_SITE_BASE_URL, "ja"),
            design_url: design_url(TEST_SITE_BASE_URL, "ja"),
            terms_url: terms_url(TEST_SITE_BASE_URL, "ja"),
            commercial_transactions_url: commercial_transactions_url(TEST_SITE_BASE_URL, "ja"),
            privacy_policy_url: privacy_policy_url(TEST_SITE_BASE_URL, "ja"),
        };

        let html = render_html(&template).expect("top page should render");

        assert!(html.contains(r#"<link rel="icon" type="image/png" href="/static/favicon.png">"#));

        let header_logo = html
            .find(r#"<img class="top-brand__logo" src="/static/site-logo.png" alt="" aria-hidden="true">"#)
            .expect("header logo should be rendered");
        let header_title = html
            .find(r#"<h1 class="top-brand__title">STONE SIGNATURE</h1>"#)
            .expect("header title should be rendered");
        assert!(header_logo < header_title);

        let footer_logo = html
            .find(r#"<img class="top-footer__brand-logo" src="/static/site-logo.png" alt="" aria-hidden="true">"#)
            .expect("footer logo should be rendered");
        let footer_title = html
            .find(r#"<div class="top-footer__brand-title">STONE SIGNATURE</div>"#)
            .expect("footer title should be rendered");
        assert!(footer_logo < footer_title);
    }

    #[test]
    fn seo_metadata_marks_payment_pages_noindex() {
        let success_template = PaymentSuccessTemplate {
            has_session_id: true,
            session_id: "sess_123".to_owned(),
            has_order_id: true,
            order_id: "ord_456".to_owned(),
            selected_locale: "en".to_owned(),
            page_title: "Payment complete | STONE SIGNATURE".to_owned(),
            meta_description: "Your payment was received. Check your confirmation email for order details and next steps.".to_owned(),
            robots_meta: "noindex,follow".to_owned(),
            canonical_url: payment_result_locale_url(
                TEST_SITE_BASE_URL,
                "/payment/success",
                &PaymentRedirectQuery::default(),
                "en",
            ),
            lang_ja_url: payment_result_locale_url(
                TEST_SITE_BASE_URL,
                "/payment/success",
                &PaymentRedirectQuery::default(),
                "ja",
            ),
            lang_en_url: payment_result_locale_url(
                TEST_SITE_BASE_URL,
                "/payment/success",
                &PaymentRedirectQuery::default(),
                "en",
            ),
            company_url: company_url(TEST_SITE_BASE_URL),
            top_url: top_url(TEST_SITE_BASE_URL, "en"),
            terms_url: terms_url(TEST_SITE_BASE_URL, "en"),
            commercial_transactions_url: commercial_transactions_url(TEST_SITE_BASE_URL, "en"),
            contact_url: inquiry_url(TEST_SITE_BASE_URL, "en"),
            privacy_policy_url: privacy_policy_url(TEST_SITE_BASE_URL, "en"),
        };

        let success_html = render_html(&success_template).expect("payment success should render");
        assert!(success_html.contains(r#"<title>Payment complete | STONE SIGNATURE</title>"#));
        assert!(success_html.contains(r#"<meta name="robots" content="noindex,follow">"#));

        let failure_template = PaymentFailureTemplate {
            has_order_id: true,
            order_id: "ord_456".to_owned(),
            selected_locale: "en".to_owned(),
            page_title: "Payment incomplete | STONE SIGNATURE".to_owned(),
            meta_description: "Payment did not complete. Check your card details and return to the purchase page to try again.".to_owned(),
            robots_meta: "noindex,follow".to_owned(),
            canonical_url: payment_result_locale_url(
                TEST_SITE_BASE_URL,
                "/payment/failure",
                &PaymentRedirectQuery::default(),
                "en",
            ),
            lang_ja_url: payment_result_locale_url(
                TEST_SITE_BASE_URL,
                "/payment/failure",
                &PaymentRedirectQuery::default(),
                "ja",
            ),
            lang_en_url: payment_result_locale_url(
                TEST_SITE_BASE_URL,
                "/payment/failure",
                &PaymentRedirectQuery::default(),
                "en",
            ),
            company_url: company_url(TEST_SITE_BASE_URL),
            top_url: top_url(TEST_SITE_BASE_URL, "en"),
            design_url: design_url(TEST_SITE_BASE_URL, "en"),
            terms_url: terms_url(TEST_SITE_BASE_URL, "en"),
            commercial_transactions_url: commercial_transactions_url(TEST_SITE_BASE_URL, "en"),
            contact_url: inquiry_url(TEST_SITE_BASE_URL, "en"),
            privacy_policy_url: privacy_policy_url(TEST_SITE_BASE_URL, "en"),
        };

        let failure_html = render_html(&failure_template).expect("payment failure should render");
        assert!(failure_html.contains(r#"<title>Payment incomplete | STONE SIGNATURE</title>"#));
        assert!(failure_html.contains(r#"<meta name="robots" content="noindex,follow">"#));
    }

    #[test]
    fn locale_urls_use_english_as_the_main_variant() {
        assert_eq!(
            top_url(TEST_SITE_BASE_URL, "en"),
            "https://finitefield.org/"
        );
        assert_eq!(
            top_url(TEST_SITE_BASE_URL, "ja"),
            "https://finitefield.org/?lang=ja"
        );
        assert_eq!(
            top_url(TEST_SITE_BASE_URL, "jp"),
            "https://finitefield.org/?lang=ja"
        );
        assert_eq!(
            design_url(TEST_SITE_BASE_URL, "en"),
            "https://finitefield.org/design"
        );
        assert_eq!(
            design_url(TEST_SITE_BASE_URL, "ja"),
            "https://finitefield.org/design?lang=ja"
        );
        assert_eq!(
            terms_url(TEST_SITE_BASE_URL, "en"),
            "https://finitefield.org/terms"
        );
        assert_eq!(
            commercial_transactions_url(TEST_SITE_BASE_URL, "en"),
            "https://finitefield.org/commercial-transactions"
        );
        assert_eq!(
            privacy_policy_url(TEST_SITE_BASE_URL, "en"),
            "https://finitefield.org/en/privacy/"
        );
        assert_eq!(
            inquiry_url(TEST_SITE_BASE_URL, "en"),
            "https://finitefield.org/en/contact/"
        );
        assert_eq!(
            company_url(TEST_SITE_BASE_URL),
            "https://finitefield.org/company/"
        );
    }

    #[test]
    fn design_url_with_filters_preserves_selected_facets() {
        let filters = MaterialFilterState {
            color_family: "green".to_owned(),
            pattern_primary: "cloud".to_owned(),
            stone_shape: "oval".to_owned(),
        };

        assert_eq!(
            design_url_with_filters(TEST_SITE_BASE_URL, "en", &filters),
            "https://finitefield.org/design?color_family=green&pattern_primary=cloud&stone_shape=oval"
        );
        assert_eq!(
            design_url_with_filters(TEST_SITE_BASE_URL, "ja", &filters),
            "https://finitefield.org/design?lang=ja&color_family=green&pattern_primary=cloud&stone_shape=oval"
        );
    }

    #[test]
    fn navigation_urls_preserve_the_selected_locale() {
        assert_eq!(
            localized_navigation_page_url(TEST_SITE_BASE_URL, "/", "en"),
            "https://finitefield.org/?lang=en"
        );
        assert_eq!(
            localized_navigation_page_url(TEST_SITE_BASE_URL, "/design", "en"),
            "https://finitefield.org/design?lang=en"
        );
        assert_eq!(
            localized_navigation_page_url(TEST_SITE_BASE_URL, "/terms", "en"),
            "https://finitefield.org/terms?lang=en"
        );
        assert_eq!(
            localized_navigation_page_url(TEST_SITE_BASE_URL, "/commercial-transactions", "en"),
            "https://finitefield.org/commercial-transactions?lang=en"
        );

        let query = PaymentRedirectQuery {
            checkout: Some("success".to_owned()),
            session_id: Some("sess_123".to_owned()),
            order_id: Some("ord_456".to_owned()),
            ..PaymentRedirectQuery::default()
        };
        assert_eq!(
            payment_result_navigation_url(TEST_SITE_BASE_URL, "/payment/success", &query, "en",),
            "https://finitefield.org/payment/success?lang=en&checkout=success&session_id=sess_123&order_id=ord_456"
        );
    }

    #[test]
    fn legal_urls_still_point_to_finitefield_org_on_other_hosts() {
        assert_eq!(
            privacy_policy_url(TEST_ALT_SITE_BASE_URL, "ja"),
            "https://finitefield.org/privacy/"
        );
        assert_eq!(
            privacy_policy_url(TEST_ALT_SITE_BASE_URL, "en"),
            "https://finitefield.org/en/privacy/"
        );
        assert_eq!(
            inquiry_url(TEST_ALT_SITE_BASE_URL, "ja"),
            "https://finitefield.org/contact/"
        );
        assert_eq!(
            inquiry_url(TEST_ALT_SITE_BASE_URL, "en"),
            "https://finitefield.org/en/contact/"
        );
        assert_eq!(
            company_url(TEST_ALT_SITE_BASE_URL),
            "https://finitefield.org/company/"
        );
    }

    #[tokio::test]
    async fn legal_pages_back_buttons_point_to_top() {
        let commercial_response = handle_commercial_transactions(
            State(mock_state()),
            Query(LocaleQuery {
                lang: Some("en".to_owned()),
            }),
        )
        .await;
        let commercial_html = String::from_utf8(
            to_bytes(commercial_response.into_body(), usize::MAX)
                .await
                .expect("commercial transactions body should be readable")
                .to_vec(),
        )
        .expect("commercial transactions body should be utf-8");

        assert!(commercial_html.contains("Back to TOP"));
        assert!(
            commercial_html.contains("window.location.href='https://finitefield.org/?lang=en'")
        );

        let terms_response = handle_terms(
            State(mock_state()),
            Query(LocaleQuery {
                lang: Some("en".to_owned()),
            }),
        )
        .await;
        let terms_html = String::from_utf8(
            to_bytes(terms_response.into_body(), usize::MAX)
                .await
                .expect("terms body should be readable")
                .to_vec(),
        )
        .expect("terms body should be utf-8");

        assert!(terms_html.contains("Back to TOP"));
        assert!(terms_html.contains("window.location.href='https://finitefield.org/?lang=en'"));
    }

    #[test]
    fn payment_result_locale_url_uses_clean_english_urls() {
        let query = PaymentRedirectQuery {
            checkout: Some("success".to_owned()),
            session_id: Some("sess_123".to_owned()),
            order_id: Some("ord_456".to_owned()),
            ..PaymentRedirectQuery::default()
        };

        assert_eq!(
            payment_result_locale_url(TEST_SITE_BASE_URL, "/payment/success", &query, "en"),
            "https://finitefield.org/payment/success?checkout=success&session_id=sess_123&order_id=ord_456"
        );
        assert_eq!(
            payment_result_locale_url(TEST_SITE_BASE_URL, "/payment/success", &query, "ja"),
            "https://finitefield.org/payment/success?lang=ja&checkout=success&session_id=sess_123&order_id=ord_456"
        );
    }

    #[tokio::test]
    async fn robots_txt_is_served_as_plain_text() {
        let response = handle_robots_txt(State(mock_state())).await;

        assert_eq!(response.status(), StatusCode::OK);
        assert_eq!(
            response
                .headers()
                .get("content-type")
                .and_then(|value| value.to_str().ok()),
            Some("text/plain; charset=utf-8")
        );

        let body = to_bytes(response.into_body(), usize::MAX)
            .await
            .expect("response body should be readable");
        let robots_txt = String::from_utf8(body.to_vec()).expect("response body should be utf-8");

        assert!(robots_txt.contains("User-agent: *"));
        assert!(robots_txt.contains("Disallow: /admin"));
        assert!(robots_txt.contains("Disallow: /mock"));
        assert!(robots_txt.contains("Disallow: /kanji"));
        assert!(robots_txt.contains("Disallow: /purchase"));
        assert!(robots_txt.contains("Disallow: /payment/"));
        assert!(robots_txt.contains("Sitemap: https://finitefield.org/sitemap.xml"));
    }

    #[tokio::test]
    async fn sitemap_xml_is_served_as_xml() {
        let response = handle_sitemap_xml(State(mock_state())).await;

        assert_eq!(response.status(), StatusCode::OK);
        assert_eq!(
            response
                .headers()
                .get("content-type")
                .and_then(|value| value.to_str().ok()),
            Some("application/xml; charset=utf-8")
        );

        let body = to_bytes(response.into_body(), usize::MAX)
            .await
            .expect("response body should be readable");
        let sitemap_xml = String::from_utf8(body.to_vec()).expect("response body should be utf-8");

        assert!(sitemap_xml.contains("<loc>https://finitefield.org/</loc>"));
        assert!(sitemap_xml.contains(
            r#"<xhtml:link rel="alternate" hreflang="en" href="https://finitefield.org/" />"#
        ));
        assert!(sitemap_xml.contains(
            r#"<xhtml:link rel="alternate" hreflang="ja" href="https://finitefield.org/?lang=ja" />"#
        ));
        assert!(sitemap_xml.contains(
            r#"<xhtml:link rel="alternate" hreflang="x-default" href="https://finitefield.org/" />"#
        ));
        assert!(sitemap_xml.contains("<loc>https://finitefield.org/design</loc>"));
        assert!(sitemap_xml.contains(
            r#"<xhtml:link rel="alternate" hreflang="en" href="https://finitefield.org/design" />"#
        ));
        assert!(sitemap_xml.contains(
            r#"<xhtml:link rel="alternate" hreflang="ja" href="https://finitefield.org/design?lang=ja" />"#
        ));
        assert!(sitemap_xml.contains(
            r#"<xhtml:link rel="alternate" hreflang="x-default" href="https://finitefield.org/design" />"#
        ));
        assert!(sitemap_xml.contains("<loc>https://finitefield.org/terms</loc>"));
        assert!(sitemap_xml.contains(
            r#"<xhtml:link rel="alternate" hreflang="en" href="https://finitefield.org/terms" />"#
        ));
        assert!(sitemap_xml.contains(
            r#"<xhtml:link rel="alternate" hreflang="ja" href="https://finitefield.org/terms?lang=ja" />"#
        ));
        assert!(sitemap_xml.contains(
            r#"<xhtml:link rel="alternate" hreflang="x-default" href="https://finitefield.org/terms" />"#
        ));
        assert!(sitemap_xml.contains("<loc>https://finitefield.org/commercial-transactions</loc>"));
        assert!(
            sitemap_xml
                .contains(r#"<xhtml:link rel="alternate" hreflang="en" href="https://finitefield.org/commercial-transactions" />"#)
        );
        assert!(
            sitemap_xml
                .contains(r#"<xhtml:link rel="alternate" hreflang="ja" href="https://finitefield.org/commercial-transactions?lang=ja" />"#)
        );
        assert!(
            sitemap_xml
                .contains(r#"<xhtml:link rel="alternate" hreflang="x-default" href="https://finitefield.org/commercial-transactions" />"#)
        );
    }
}
