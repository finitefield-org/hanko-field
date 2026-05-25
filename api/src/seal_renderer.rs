use anyhow::{Result, anyhow, bail};
use fontdue::{Font, FontSettings};

use crate::seal_fonts::{SealFontProfileAsset, seal_font_profile_assets};

use super::{SealRecipeFontProfile, is_cjk_han_character};

const DEFAULT_GLYPH_FONT_SIZE_PX: f32 = 720.0;
const MIN_GLYPH_FONT_SIZE_PX: f32 = 32.0;
const MAX_GLYPH_FONT_SIZE_PX: f32 = 1600.0;

#[derive(Debug, Clone)]
#[allow(dead_code)]
pub(crate) struct RenderedSealGlyphRun {
    pub(crate) source_text: String,
    pub(crate) requested_font_profile: &'static str,
    pub(crate) font_profile: &'static str,
    pub(crate) font_family: &'static str,
    pub(crate) glyphs: Vec<RenderedSealGlyph>,
}

#[derive(Debug, Clone)]
#[allow(dead_code)]
pub(crate) struct RenderedSealGlyph {
    pub(crate) character: char,
    pub(crate) glyph_index: u16,
    pub(crate) bitmap_width: usize,
    pub(crate) bitmap_height: usize,
    pub(crate) x_min: i32,
    pub(crate) y_min: i32,
    pub(crate) advance_width: f32,
    pub(crate) bitmap: Vec<u8>,
}

#[allow(dead_code)]
pub(crate) fn render_seal_glyphs_from_real_font(
    kanji: &str,
    requested_profile: SealRecipeFontProfile,
) -> Result<RenderedSealGlyphRun> {
    render_seal_glyphs_from_real_font_at_px(kanji, requested_profile, DEFAULT_GLYPH_FONT_SIZE_PX)
}

#[allow(dead_code)]
pub(crate) fn render_seal_glyphs_from_real_font_at_px(
    kanji: &str,
    requested_profile: SealRecipeFontProfile,
    font_size_px: f32,
) -> Result<RenderedSealGlyphRun> {
    validate_glyph_font_size(font_size_px)?;
    let selected_text = validate_selected_kanji_text(kanji)?;
    let chars = selected_text.chars().collect::<Vec<_>>();

    let mut failures = Vec::new();
    for profile_key in font_profile_fallback_order(requested_profile) {
        let asset = seal_font_profile_asset(profile_key)?;
        match render_glyph_run_with_asset(
            &selected_text,
            &chars,
            requested_profile,
            asset,
            font_size_px,
        ) {
            Ok(run) => return Ok(run),
            Err(err) => failures.push(format!("{}: {err:#}", asset.key)),
        }
    }

    bail!(
        "selected kanji could not be rendered by any approved real font: {}",
        failures.join("; ")
    )
}

fn validate_glyph_font_size(font_size_px: f32) -> Result<()> {
    if !(MIN_GLYPH_FONT_SIZE_PX..=MAX_GLYPH_FONT_SIZE_PX).contains(&font_size_px) {
        bail!(
            "font_size_px must be in range {}-{}",
            MIN_GLYPH_FONT_SIZE_PX,
            MAX_GLYPH_FONT_SIZE_PX
        );
    }
    Ok(())
}

fn validate_selected_kanji_text(kanji: &str) -> Result<String> {
    if kanji.trim() != kanji {
        bail!("selected kanji must not include surrounding whitespace");
    }
    if kanji.is_empty() {
        bail!("selected kanji is required");
    }
    if kanji.chars().any(char::is_whitespace) {
        bail!("selected kanji must not contain whitespace");
    }

    let char_count = kanji.chars().count();
    if char_count == 0 || char_count > 2 {
        bail!("selected kanji must be 1 or 2 characters");
    }
    if !kanji.chars().all(is_cjk_han_character) {
        bail!("selected kanji must contain only CJK Han characters");
    }

    Ok(kanji.to_owned())
}

fn font_profile_fallback_order(requested_profile: SealRecipeFontProfile) -> Vec<&'static str> {
    let requested = requested_profile.as_str();
    let mut profiles = Vec::new();
    for candidate in [requested, "formal_serif", "soft_sans"] {
        if !profiles.contains(&candidate) {
            profiles.push(candidate);
        }
    }
    profiles
}

fn seal_font_profile_asset(profile_key: &str) -> Result<&'static SealFontProfileAsset> {
    seal_font_profile_assets()
        .iter()
        .find(|asset| asset.key == profile_key)
        .ok_or_else(|| anyhow!("seal font profile asset not found: {profile_key}"))
}

fn load_font(asset: &SealFontProfileAsset) -> Result<Font> {
    Font::from_bytes(asset.bytes, FontSettings::default())
        .map_err(|err| anyhow!("failed to load {} font bytes: {err}", asset.key))
}

fn render_glyph_run_with_asset(
    selected_text: &str,
    chars: &[char],
    requested_profile: SealRecipeFontProfile,
    asset: &'static SealFontProfileAsset,
    font_size_px: f32,
) -> Result<RenderedSealGlyphRun> {
    let font = load_font(asset)?;
    let mut glyphs = Vec::with_capacity(chars.len());

    for character in chars {
        let glyph_index = font.lookup_glyph_index(*character);
        if glyph_index == 0 {
            bail!(
                "font profile {} does not contain selected glyph {}",
                asset.key,
                format_unicode_scalar(*character)
            );
        }

        let (metrics, bitmap) = font.rasterize(*character, font_size_px);
        if metrics.width == 0 || metrics.height == 0 || bitmap.iter().all(|alpha| *alpha == 0) {
            bail!(
                "font profile {} produced empty glyph bitmap for {}",
                asset.key,
                format_unicode_scalar(*character)
            );
        }

        glyphs.push(RenderedSealGlyph {
            character: *character,
            glyph_index,
            bitmap_width: metrics.width,
            bitmap_height: metrics.height,
            x_min: metrics.xmin,
            y_min: metrics.ymin,
            advance_width: metrics.advance_width,
            bitmap,
        });
    }

    Ok(RenderedSealGlyphRun {
        source_text: selected_text.to_owned(),
        requested_font_profile: requested_profile.as_str(),
        font_profile: asset.key,
        font_family: asset.font_family,
        glyphs,
    })
}

fn format_unicode_scalar(character: char) -> String {
    format!("U+{:04X}", character as u32)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn m14_t04_renders_exact_selected_unicode_kanji_from_real_font() {
        let run = render_seal_glyphs_from_real_font_at_px(
            "美空",
            SealRecipeFontProfile::FormalSerif,
            192.0,
        )
        .expect("selected kanji should render");

        assert_eq!(run.source_text, "美空");
        assert_eq!(run.requested_font_profile, "formal_serif");
        assert_eq!(run.font_profile, "formal_serif");
        assert_eq!(run.font_family, "Noto Serif JP");
        assert_eq!(
            run.glyphs
                .iter()
                .map(|glyph| glyph.character)
                .collect::<String>(),
            "美空"
        );
        for glyph in run.glyphs {
            assert_ne!(glyph.glyph_index, 0);
            assert!(glyph.bitmap_width > 0);
            assert!(glyph.bitmap_height > 0);
            assert_eq!(glyph.bitmap.len(), glyph.bitmap_width * glyph.bitmap_height);
            assert!(glyph.bitmap.iter().any(|alpha| *alpha > 0));
            assert!(glyph.advance_width > 0.0);
            let _bounds_origin = (glyph.x_min, glyph.y_min);
        }
    }

    #[test]
    fn m14_t04_rejects_non_kanji_text_before_font_rendering() {
        let err =
            render_seal_glyphs_from_real_font_at_px("美A", SealRecipeFontProfile::SoftSans, 192.0)
                .expect_err("non-kanji text must fail");

        assert!(
            err.to_string()
                .contains("selected kanji must contain only CJK Han characters"),
            "unexpected error: {err:#}"
        );
    }

    #[test]
    fn m14_t04_falls_back_to_approved_font_when_profile_lacks_selected_glyph() {
        let fallback_char = find_character_missing_from_primary_but_present_in_fallback(
            "bold_brush",
            "formal_serif",
        )
        .expect("test fonts should expose a fallback-only kanji");
        let selected = fallback_char.to_string();

        let run = render_seal_glyphs_from_real_font_at_px(
            &selected,
            SealRecipeFontProfile::BoldBrush,
            192.0,
        )
        .expect("fallback font should render selected kanji");

        assert_eq!(run.source_text, selected);
        assert_eq!(run.requested_font_profile, "bold_brush");
        assert_eq!(run.font_profile, "formal_serif");
        assert_eq!(run.glyphs.len(), 1);
        assert_eq!(run.glyphs[0].character, fallback_char);
        assert_ne!(run.glyphs[0].glyph_index, 0);
    }

    #[test]
    fn m14_t04_rejects_selected_kanji_missing_from_all_approved_fonts() {
        let missing_char = find_character_missing_from_all_fonts()
            .expect("test candidate set should include one unsupported CJK character");
        let selected = missing_char.to_string();

        let err = render_seal_glyphs_from_real_font_at_px(
            &selected,
            SealRecipeFontProfile::ClassicSeal,
            192.0,
        )
        .expect_err("unsupported selected kanji must fail");

        assert!(
            err.to_string()
                .contains("selected kanji could not be rendered by any approved real font"),
            "unexpected error: {err:#}"
        );
    }

    fn find_character_missing_from_primary_but_present_in_fallback(
        primary_key: &str,
        fallback_key: &str,
    ) -> Option<char> {
        let primary = load_font(seal_font_profile_asset(primary_key).ok()?).ok()?;
        let fallback = load_font(seal_font_profile_asset(fallback_key).ok()?).ok()?;
        fallback_test_candidates().into_iter().find(|character| {
            primary.lookup_glyph_index(*character) == 0
                && fallback.lookup_glyph_index(*character) != 0
        })
    }

    fn find_character_missing_from_all_fonts() -> Option<char> {
        let fonts = seal_font_profile_assets()
            .iter()
            .map(load_font)
            .collect::<Result<Vec<_>>>()
            .ok()?;
        unsupported_test_candidates().into_iter().find(|character| {
            fonts
                .iter()
                .all(|font| font.lookup_glyph_index(*character) == 0)
        })
    }

    fn fallback_test_candidates() -> Vec<char> {
        vec![
            '龘', '麤', '鱻', '灩', '靐', '齉', '纛', '爨', '齾', '鬱', '髙', '﨑', '㐂', '㐀',
            '㐁', '㐄',
        ]
    }

    fn unsupported_test_candidates() -> Vec<char> {
        vec!['㐀', '㐁', '㐄', '㐅', '㐆', '㐇', '㐈', '㐉', '䶵', '䶴']
    }
}
