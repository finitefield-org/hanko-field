use std::{collections::BTreeMap, env, sync::Arc};

use anyhow::{Context, Result, anyhow, bail};
use chrono::{DateTime, SecondsFormat, Utc};
use firebase_sdk_rust::firebase_firestore::{
    CreateDocumentOptions, Document, FirebaseFirestoreClient, FirebaseFirestoreError,
    GetDocumentOptions, PatchDocumentOptions,
};
use gcp_auth::{CustomServiceAccount, TokenProvider, provider};
use serde_json::{Value as JsonValue, json};

const DATASTORE_SCOPE: &str = "https://www.googleapis.com/auth/datastore";

#[derive(Debug, Clone)]
struct SeedConfig {
    project_id: String,
    credentials_file: Option<String>,
}

#[derive(Debug, Clone, Copy)]
struct FontSeed {
    key: &'static str,
    label: &'static str,
    font_family: &'static str,
    font_stylesheet_url: &'static str,
    kanji_style: &'static str,
    sort_order: i64,
}

#[derive(Debug, Clone, Copy)]
struct MaterialSeed {
    key: &'static str,
    label_ja: &'static str,
    label_en: &'static str,
    description_ja: &'static str,
    description_en: &'static str,
    comparison_texture_ja: &'static str,
    comparison_texture_en: &'static str,
    comparison_weight_ja: &'static str,
    comparison_weight_en: &'static str,
    comparison_usage_ja: &'static str,
    comparison_usage_en: &'static str,
    photo_url: &'static str,
    photo_alt_ja: &'static str,
    photo_alt_en: &'static str,
    shape: &'static str,
    price_usd: i64,
    price_jpy: i64,
    sort_order: i64,
}

#[derive(Debug, Clone, Copy)]
struct CountrySeed {
    code: &'static str,
    label_ja: &'static str,
    label_en: &'static str,
    shipping_fee_usd: i64,
    shipping_fee_jpy: i64,
    sort_order: i64,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cfg = load_config()?;
    let client = firestore_client(cfg.credentials_file.as_deref()).await?;
    let parent = format!("projects/{}/databases/(default)/documents", cfg.project_id);
    let now = Utc::now();

    println!("seeding Firestore catalog for project {}", cfg.project_id);

    upsert_named_document(
        &client,
        &parent,
        "app_config",
        "public",
        app_config_public_document(now),
    )
    .await
    .context("failed to seed app_config/public")?;

    for font in font_seeds() {
        upsert_named_document(
            &client,
            &parent,
            "fonts",
            font.key,
            font_document(&font, now),
        )
        .await
        .with_context(|| format!("failed to seed fonts/{}", font.key))?;
    }

    for material in material_seeds() {
        upsert_named_document(
            &client,
            &parent,
            "materials",
            material.key,
            material_document(&material, now),
        )
        .await
        .with_context(|| format!("failed to seed materials/{}", material.key))?;
    }

    for country in country_seeds() {
        upsert_named_document(
            &client,
            &parent,
            "countries",
            country.code,
            country_document(&country, now),
        )
        .await
        .with_context(|| format!("failed to seed countries/{}", country.code))?;
    }

    println!("catalog seed complete");
    Ok(())
}

fn load_config() -> Result<SeedConfig> {
    let project_id = env_first(&[
        "API_FIRESTORE_PROJECT_ID",
        "FIREBASE_PROJECT_ID",
        "GOOGLE_CLOUD_PROJECT",
    ]);
    if project_id.is_empty() {
        bail!("missing Firestore project id env var");
    }

    let credentials_file = first_non_empty(&[
        env::var("API_FIREBASE_CREDENTIALS_FILE").ok(),
        env::var("GOOGLE_APPLICATION_CREDENTIALS").ok(),
    ]);

    Ok(SeedConfig {
        project_id,
        credentials_file,
    })
}

async fn firestore_client(credentials_file: Option<&str>) -> Result<FirebaseFirestoreClient> {
    let token_provider: Arc<dyn TokenProvider> = if let Some(credentials_file) = credentials_file {
        Arc::new(
            CustomServiceAccount::from_file(credentials_file)
                .with_context(|| format!("failed to read credentials file: {credentials_file}"))?,
        )
    } else {
        provider()
            .await
            .context("failed to initialize default GCP auth provider")?
    };

    let access_token = token_provider
        .token(&[DATASTORE_SCOPE])
        .await
        .context("failed to acquire Firestore access token")?;

    firestore_client_from_access_token(access_token.as_str())
}

fn firestore_client_from_access_token(access_token: &str) -> Result<FirebaseFirestoreClient> {
    Ok(FirebaseFirestoreClient::new(access_token.to_owned()))
}

async fn upsert_named_document(
    client: &FirebaseFirestoreClient,
    parent: &str,
    collection: &str,
    doc_id: &str,
    document: Document,
) -> Result<()> {
    let name = format!("{}/{}/{}", parent, collection, doc_id);

    match client
        .get_document(&name, &GetDocumentOptions::default())
        .await
    {
        Ok(_) => {
            client
                .patch_document(&name, &document, &PatchDocumentOptions::default())
                .await
                .map_err(anyhow::Error::from)?;
        }
        Err(err) if is_not_found(&err) => {
            client
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
                .map_err(anyhow::Error::from)?;
        }
        Err(err) => return Err(anyhow!(err)),
    }

    println!("  upserted {collection}/{doc_id}");
    Ok(())
}

fn app_config_public_document(now: DateTime<Utc>) -> Document {
    Document {
        fields: btree_from_pairs(vec![
            (
                "supported_locales",
                fs_array(vec![fs_string("ja"), fs_string("en")]),
            ),
            ("default_locale", fs_string("ja")),
            ("default_currency", fs_string("USD")),
            (
                "currency_by_locale",
                fs_map(btree_from_pairs(vec![
                    ("ja", fs_string("JPY")),
                    ("en", fs_string("USD")),
                ])),
            ),
            ("created_at", fs_timestamp(now)),
            ("updated_at", fs_timestamp(now)),
        ]),
        ..Document::default()
    }
}

fn font_document(font: &FontSeed, now: DateTime<Utc>) -> Document {
    Document {
        fields: btree_from_pairs(vec![
            ("label", fs_string(font.label)),
            ("font_family", fs_string(font.font_family)),
            ("font_stylesheet_url", fs_string(font.font_stylesheet_url)),
            ("kanji_style", fs_string(font.kanji_style)),
            ("is_active", fs_bool(true)),
            ("sort_order", fs_int(font.sort_order)),
            ("version", fs_int(1)),
            ("created_at", fs_timestamp(now)),
            ("updated_at", fs_timestamp(now)),
        ]),
        ..Document::default()
    }
}

fn material_document(material: &MaterialSeed, now: DateTime<Utc>) -> Document {
    Document {
        fields: btree_from_pairs(vec![
            (
                "label_i18n",
                fs_string_map(&[("ja", material.label_ja), ("en", material.label_en)]),
            ),
            (
                "description_i18n",
                fs_string_map(&[
                    ("ja", material.description_ja),
                    ("en", material.description_en),
                ]),
            ),
            (
                "comparison_texture_ja",
                fs_string(material.comparison_texture_ja),
            ),
            (
                "comparison_texture_en",
                fs_string(material.comparison_texture_en),
            ),
            (
                "comparison_weight_ja",
                fs_string(material.comparison_weight_ja),
            ),
            (
                "comparison_weight_en",
                fs_string(material.comparison_weight_en),
            ),
            (
                "comparison_usage_ja",
                fs_string(material.comparison_usage_ja),
            ),
            (
                "comparison_usage_en",
                fs_string(material.comparison_usage_en),
            ),
            ("shape", fs_string(material.shape)),
            ("photo_url", fs_string(material.photo_url)),
            (
                "photo_alt_i18n",
                fs_string_map(&[("ja", material.photo_alt_ja), ("en", material.photo_alt_en)]),
            ),
            (
                "price_by_currency",
                fs_int_map(&[("USD", material.price_usd), ("JPY", material.price_jpy)]),
            ),
            ("is_active", fs_bool(true)),
            ("sort_order", fs_int(material.sort_order)),
            ("version", fs_int(1)),
            ("created_at", fs_timestamp(now)),
            ("updated_at", fs_timestamp(now)),
        ]),
        ..Document::default()
    }
}

fn country_document(country: &CountrySeed, now: DateTime<Utc>) -> Document {
    Document {
        fields: btree_from_pairs(vec![
            (
                "label_i18n",
                fs_string_map(&[("ja", country.label_ja), ("en", country.label_en)]),
            ),
            (
                "shipping_fee_by_currency",
                fs_int_map(&[
                    ("USD", country.shipping_fee_usd),
                    ("JPY", country.shipping_fee_jpy),
                ]),
            ),
            ("is_active", fs_bool(true)),
            ("sort_order", fs_int(country.sort_order)),
            ("version", fs_int(1)),
            ("created_at", fs_timestamp(now)),
            ("updated_at", fs_timestamp(now)),
        ]),
        ..Document::default()
    }
}

fn font_seeds() -> Vec<FontSeed> {
    vec![
        FontSeed {
            key: "zen_maru_gothic",
            label: "Zen Maru Gothic",
            font_family: "'Zen Maru Gothic', sans-serif",
            font_stylesheet_url: "https://fonts.googleapis.com/css2?family=Zen+Maru+Gothic:wght@400;700&display=swap",
            kanji_style: "japanese",
            sort_order: 10,
        },
        FontSeed {
            key: "kosugi_maru",
            label: "Kosugi Maru",
            font_family: "'Kosugi Maru', sans-serif",
            font_stylesheet_url: "https://fonts.googleapis.com/css2?family=Kosugi+Maru&display=swap",
            kanji_style: "chinese",
            sort_order: 20,
        },
        FontSeed {
            key: "potta_one",
            label: "Potta One",
            font_family: "'Potta One', sans-serif",
            font_stylesheet_url: "https://fonts.googleapis.com/css2?family=Potta+One&display=swap",
            kanji_style: "taiwanese",
            sort_order: 30,
        },
        FontSeed {
            key: "kiwi_maru",
            label: "Kiwi Maru",
            font_family: "'Kiwi Maru', sans-serif",
            font_stylesheet_url: "https://fonts.googleapis.com/css2?family=Kiwi+Maru:wght@400;700&display=swap",
            kanji_style: "japanese",
            sort_order: 40,
        },
        FontSeed {
            key: "wdxl_lubrifont_jp_n",
            label: "WDXL Lubrifont JP N",
            font_family: "'WDXL Lubrifont JP N', sans-serif",
            font_stylesheet_url: "https://fonts.googleapis.com/css2?family=WDXL+Lubrifont+JP+N&display=swap",
            kanji_style: "chinese",
            sort_order: 50,
        },
    ]
}

fn material_seeds() -> Vec<MaterialSeed> {
    vec![
        MaterialSeed {
            key: "rose_quartz",
            label_ja: "ローズクオーツ",
            label_en: "Rose Quartz",
            description_ja: "やわらかな色合いで、親しみやすい印象の石材",
            description_en: "A soft-toned stone with a warm, approachable presence",
            comparison_texture_ja: "淡い桃色のやわらかな透明感",
            comparison_texture_en: "Soft, translucent pink sheen",
            comparison_weight_ja: "やや軽やかで手になじみやすい",
            comparison_weight_en: "Light and gentle to handle",
            comparison_usage_ja: "やわらかな印象を出しやすい",
            comparison_usage_en: "A soft, friendly finish",
            photo_url: "https://picsum.photos/seed/hf-rose-quartz/640/420",
            photo_alt_ja: "ローズクオーツ材の写真",
            photo_alt_en: "Rose quartz photo",
            shape: "square",
            price_usd: 16_500,
            price_jpy: 28_000,
            sort_order: 10,
        },
        MaterialSeed {
            key: "lapis_lazuli",
            label_ja: "ラピスラビリ",
            label_en: "Lapis Lazuli",
            description_ja: "深い青が印象的な、存在感のある石材",
            description_en: "A deep-blue stone with a strong, distinctive presence",
            comparison_texture_ja: "深い青にきらめきが入る石目",
            comparison_texture_en: "Deep blue stone with bright flecks",
            comparison_weight_ja: "ほどよい重さで存在感がある",
            comparison_weight_en: "Medium-heavy with a strong presence",
            comparison_usage_ja: "印象を強めやすい",
            comparison_usage_en: "A vivid, distinctive finish",
            photo_url: "https://picsum.photos/seed/hf-lapis-lazuli/640/420",
            photo_alt_ja: "ラピスラビリ材の写真",
            photo_alt_en: "Lapis lazuli photo",
            shape: "round",
            price_usd: 32_500,
            price_jpy: 55_000,
            sort_order: 20,
        },
        MaterialSeed {
            key: "jade",
            label_ja: "翡翠",
            label_en: "Jade",
            description_ja: "落ち着いた緑の艶が映える、格調ある石材",
            description_en: "A dignified stone with a calm green sheen",
            comparison_texture_ja: "しっとりした緑石の艶感",
            comparison_texture_en: "Polished green stone with a calm sheen",
            comparison_weight_ja: "ほどよく重く、落ち着いた安定感",
            comparison_weight_en: "Substantial and steady",
            comparison_usage_ja: "落ち着いた格調を出しやすい",
            comparison_usage_en: "A calm, dignified finish",
            photo_url: "https://picsum.photos/seed/hf-jade/640/420",
            photo_alt_ja: "翡翠材の写真",
            photo_alt_en: "Jade photo",
            shape: "square",
            price_usd: 88_500,
            price_jpy: 150_000,
            sort_order: 30,
        },
    ]
}

fn country_seeds() -> Vec<CountrySeed> {
    vec![
        CountrySeed {
            code: "JP",
            label_ja: "日本",
            label_en: "Japan",
            shipping_fee_usd: 600,
            shipping_fee_jpy: 600,
            sort_order: 10,
        },
        CountrySeed {
            code: "US",
            label_ja: "アメリカ",
            label_en: "United States",
            shipping_fee_usd: 1_800,
            shipping_fee_jpy: 1_800,
            sort_order: 20,
        },
        CountrySeed {
            code: "CA",
            label_ja: "カナダ",
            label_en: "Canada",
            shipping_fee_usd: 1_900,
            shipping_fee_jpy: 1_900,
            sort_order: 30,
        },
        CountrySeed {
            code: "GB",
            label_ja: "イギリス",
            label_en: "United Kingdom",
            shipping_fee_usd: 2_000,
            shipping_fee_jpy: 2_000,
            sort_order: 40,
        },
        CountrySeed {
            code: "AU",
            label_ja: "オーストラリア",
            label_en: "Australia",
            shipping_fee_usd: 2_100,
            shipping_fee_jpy: 2_100,
            sort_order: 50,
        },
        CountrySeed {
            code: "SG",
            label_ja: "シンガポール",
            label_en: "Singapore",
            shipping_fee_usd: 1_300,
            shipping_fee_jpy: 1_300,
            sort_order: 60,
        },
    ]
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

fn first_non_empty(values: &[Option<String>]) -> Option<String> {
    values
        .iter()
        .filter_map(|value| value.as_deref())
        .map(str::trim)
        .find(|value| !value.is_empty())
        .map(ToOwned::to_owned)
}

fn is_not_found(error: &FirebaseFirestoreError) -> bool {
    matches!(
        error,
        FirebaseFirestoreError::UnexpectedStatus { status, .. } if status.as_u16() == 404
    )
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

fn fs_string_map(values: &[(&str, &str)]) -> JsonValue {
    let mut fields = BTreeMap::new();
    for (key, value) in values {
        fields.insert((*key).to_owned(), fs_string(*value));
    }
    fs_map(fields)
}

fn fs_int_map(values: &[(&str, i64)]) -> JsonValue {
    let mut fields = BTreeMap::new();
    for (key, value) in values {
        fields.insert((*key).to_owned(), fs_int(*value));
    }
    fs_map(fields)
}

fn btree_from_pairs(pairs: Vec<(&str, JsonValue)>) -> BTreeMap<String, JsonValue> {
    pairs
        .into_iter()
        .map(|(key, value)| (key.to_owned(), value))
        .collect::<BTreeMap<_, _>>()
}
