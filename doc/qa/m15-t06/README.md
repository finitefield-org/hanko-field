# M15-T06 Representative Seal Visual QA

Date: 2026-05-26 JST

Scope: representative visual confirmation for generated seal images across one-character and two-character kanji, low/medium/high stroke complexity, and square/round frames.

Source: local dev API `POST /v1/seal-designs/generate`, first returned variant for each case. The downloaded PNGs are stored under `doc/qa/m15-t06/screenshots/`.

## Result

PASS. All six representative images satisfy the M15-T06 visual contract:

- Red kanji text.
- One red outer frame.
- White background.
- Centered seal mark.
- Legible selected kanji.
- No clipped kanji or extra inner frame.

## Cases

| Case | Kanji | Characters | Stroke complexity | Shape | Image | Result |
| --- | --- | ---: | --- | --- | --- | --- |
| low-1-square | 一 | 1 | low | square | `screenshots/low-1-square.png` | PASS |
| medium-1-round | 明 | 1 | medium | round | `screenshots/medium-1-round.png` | PASS |
| high-1-square | 龍 | 1 | high | square | `screenshots/high-1-square.png` | PASS |
| low-2-round | 大山 | 2 | low | round | `screenshots/low-2-round.png` | PASS |
| medium-2-square | 美空 | 2 | medium | square | `screenshots/medium-2-square.png` | PASS |
| high-2-round | 龍華 | 2 | high | round | `screenshots/high-2-round.png` | PASS |

## Automated Checks

The generated `visual-qa-results.json` records these checks for each image:

- PNG dimensions are `1024x1024`.
- White background is present at all four corners and the center.
- Pixels are limited to red/white with anti-aliased edge colors.
- The outer frame is a single red frame.
- Inner kanji ink is centered within 24px of the canvas center.

For round frames, the single-frame check validates the outer ring samples and ignores internal kanji strokes that naturally cross the center row or column.

## Visual Evidence

The contact sheet `m15-t06-contact-sheet.png` contains the six checked images in task order.

## Validation Commands

- `flutter test` in `app/` passed: `00:18 +102: All tests passed!`
- `cargo test --manifest-path api/Cargo.toml m14_t09_generated_images_match_fixed_visual_contract` passed.
- `docker compose --env-file .env.dev up -d workspace` passed.
- `make docker-api ENV=dev` started the dev API at `http://localhost:3050`.
- `sips -g pixelWidth -g pixelHeight doc/qa/m15-t06/screenshots/*.png` confirmed every screenshot is `1024x1024`.
- `magick identify doc/qa/m15-t06/m15-t06-contact-sheet.png` confirmed the contact sheet is a valid PNG.
