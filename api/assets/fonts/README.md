# Seal Font Assets

These fonts are vendored for API-side programmatic seal rendering.
The renderer must use these real glyphs as the source of truth and must not
accept generated or invented kanji shapes from an image model.

## Profiles

| profile | font | file | license | intended use | coverage note |
| --- | --- | --- | --- | --- | --- |
| `formal_serif` | Noto Serif JP | `noto-serif-jp/NotoSerifJP-wght.ttf` | SIL Open Font License 1.1 | formal serif baseline and broad fallback | Japanese kana, common CJK Unified Ideographs, and sample MVP kanji verified |
| `soft_sans` | Noto Sans JP | `noto-sans-jp/NotoSansJP-wght.ttf` | SIL Open Font License 1.1 | readable soft sans profile | Japanese kana, common CJK Unified Ideographs, and sample MVP kanji verified |
| `bold_brush` | Yuji Syuku | `yuji-syuku/YujiSyuku-Regular.ttf` | SIL Open Font License 1.1 | brush-like profile | Japanese kana and common JIS kanji verified; fall back to `formal_serif` when a glyph is missing |
| `classic_seal` | Kaisei Tokumin Bold | `kaisei-tokumin/KaiseiTokumin-Bold.ttf` | SIL Open Font License 1.1 | classic high-contrast seal profile | Japanese kana and common JIS kanji verified; fall back to `formal_serif` when a glyph is missing |

## Source

All four fonts come from the Google Fonts repository:

- `https://github.com/google/fonts/tree/main/ofl/notoserifjp`
- `https://github.com/google/fonts/tree/main/ofl/notosansjp`
- `https://github.com/google/fonts/tree/main/ofl/yujisyuku`
- `https://github.com/google/fonts/tree/main/ofl/kaiseitokumin`

The `OFL.txt` file beside each font is the upstream SIL Open Font License 1.1
text for that font family.

## Checksums

| file | sha256 |
| --- | --- |
| `noto-serif-jp/NotoSerifJP-wght.ttf` | `2fd527ba12b6a44ec30d796d633360da0aeba6c5d4af1304ce12bb4dc15a7dfc` |
| `noto-sans-jp/NotoSansJP-wght.ttf` | `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f` |
| `yuji-syuku/YujiSyuku-Regular.ttf` | `82728ebafc8c97391e2dab633414a806f344b8e4e2227d307179f07b548fca61` |
| `kaisei-tokumin/KaiseiTokumin-Bold.ttf` | `4540f6b5c32724acc9c4ba77692195078de43a4ee762d436e39d32fa8d1a73c9` |

## Coverage Validation

Local validation inspected each font's cmap and confirmed these representative
characters are present in every profile:

`望`, `晃`, `脩`, `美`, `空`, `龍`, `愛`, `和`, `誠`, `鐵`, `明`, `希`

The broad fallback profiles are Noto Serif JP and Noto Sans JP. The renderer
must check glyph availability before choosing a profile and use `formal_serif`
as the final fallback before returning `seal_generation_failed`.
