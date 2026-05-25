#[allow(dead_code)]
#[derive(Debug)]
pub(crate) struct SealFontProfileAsset {
    pub(crate) key: &'static str,
    pub(crate) font_family: &'static str,
    pub(crate) asset_path: &'static str,
    pub(crate) license: &'static str,
    pub(crate) coverage: &'static str,
    pub(crate) sha256: &'static str,
    pub(crate) bytes: &'static [u8],
}

#[allow(dead_code)]
const SEAL_FONT_PROFILE_ASSETS: &[SealFontProfileAsset] = &[
    SealFontProfileAsset {
        key: "formal_serif",
        font_family: "Noto Serif JP",
        asset_path: "api/assets/fonts/noto-serif-jp/NotoSerifJP-wght.ttf",
        license: "SIL Open Font License 1.1",
        coverage: "Japanese kana and common CJK Unified Ideographs; preferred fallback for broad CJK coverage.",
        sha256: "2fd527ba12b6a44ec30d796d633360da0aeba6c5d4af1304ce12bb4dc15a7dfc",
        bytes: include_bytes!("../assets/fonts/noto-serif-jp/NotoSerifJP-wght.ttf"),
    },
    SealFontProfileAsset {
        key: "soft_sans",
        font_family: "Noto Sans JP",
        asset_path: "api/assets/fonts/noto-sans-jp/NotoSansJP-wght.ttf",
        license: "SIL Open Font License 1.1",
        coverage: "Japanese kana and common CJK Unified Ideographs; preferred readable sans profile.",
        sha256: "c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f",
        bytes: include_bytes!("../assets/fonts/noto-sans-jp/NotoSansJP-wght.ttf"),
    },
    SealFontProfileAsset {
        key: "bold_brush",
        font_family: "Yuji Syuku",
        asset_path: "api/assets/fonts/yuji-syuku/YujiSyuku-Regular.ttf",
        license: "SIL Open Font License 1.1",
        coverage: "Japanese kana and common JIS kanji; brush-like profile with Noto Serif JP fallback when a glyph is missing.",
        sha256: "82728ebafc8c97391e2dab633414a806f344b8e4e2227d307179f07b548fca61",
        bytes: include_bytes!("../assets/fonts/yuji-syuku/YujiSyuku-Regular.ttf"),
    },
    SealFontProfileAsset {
        key: "classic_seal",
        font_family: "Kaisei Tokumin",
        asset_path: "api/assets/fonts/kaisei-tokumin/KaiseiTokumin-Bold.ttf",
        license: "SIL Open Font License 1.1",
        coverage: "Japanese kana and common JIS kanji; classic high-contrast profile with Noto Serif JP fallback when a glyph is missing.",
        sha256: "4540f6b5c32724acc9c4ba77692195078de43a4ee762d436e39d32fa8d1a73c9",
        bytes: include_bytes!("../assets/fonts/kaisei-tokumin/KaiseiTokumin-Bold.ttf"),
    },
];

#[allow(dead_code)]
pub(crate) fn seal_font_profile_assets() -> &'static [SealFontProfileAsset] {
    SEAL_FONT_PROFILE_ASSETS
}

#[cfg(test)]
mod tests {
    use super::*;
    use sha2::{Digest, Sha256};

    #[test]
    fn m14_t01_seal_font_profiles_are_bundled_and_documented() {
        let profiles = seal_font_profile_assets();
        assert_eq!(profiles.len(), 4);
        assert_eq!(
            profiles
                .iter()
                .map(|profile| profile.key)
                .collect::<Vec<_>>(),
            vec!["formal_serif", "soft_sans", "bold_brush", "classic_seal"]
        );

        for profile in profiles {
            assert!(
                profile.asset_path.starts_with("api/assets/fonts/"),
                "{} must be vendored under api/assets/fonts",
                profile.key
            );
            assert_eq!(profile.license, "SIL Open Font License 1.1");
            assert!(
                profile.coverage.contains("CJK") || profile.coverage.contains("JIS"),
                "{} must document kanji coverage",
                profile.key
            );
            assert!(
                profile.bytes.len() > 1_000_000,
                "{} must embed a real font file",
                profile.key
            );
            assert_eq!(hex::encode(Sha256::digest(profile.bytes)), profile.sha256);
        }
    }
}
