# Analytics Events (Design, Checkout, Share)

This spec defines app analytics events for core flows. Events are PII-safe: no names, addresses, or free-form user input content are sent. Event collection respects `PrivacyPreferences.analyticsAllowed`.

## Design creation flow

| Event | Parameters | Trigger |
| --- | --- | --- |
| `design_creation_started` | `persona`, `locale` | Design creation state initialized. |
| `design_input_saved` | `source_type`, `name_length`, `has_kanji`, `persona`, `locale` | User saves name input. |
| `design_style_selected` | `shape`, `size_mm`, `writing_style`, `template_ref`, `persona`, `locale` | Style selection confirmed. |
| `design_editor_started` | `layout`, `shape`, `size_mm`, `writing_style`, `template_ref`, `persona`, `locale` | Design editor state initialized. |
| `design_export_completed` | `format`, `destination`, `file_size_mb`, `include_bleed`, `include_metadata`, `transparent_background`, `watermark_on_share`, `persona`, `locale` | Export completes successfully. |
| `design_export_shared` | `format`, `target`, `include_metadata`, `watermarked`, `persona`, `locale` | Export shared successfully. |

## Checkout flow

| Event | Parameters | Trigger |
| --- | --- | --- |
| `checkout_started` | `item_count`, `subtotal_amount`, `currency`, `has_promo`, `is_international` | Checkout shipping state initialized. |
| `checkout_address_saved` | `is_new`, `is_default`, `country`, `is_international` | Address saved successfully. |
| `checkout_address_confirmed` | `country`, `is_international`, `address_count` | Address selection confirmed. |
| `checkout_shipping_selected` | `shipping_method_id`, `carrier`, `cost_amount`, `currency`, `eta_min_days`, `eta_max_days`, `is_express`, `is_international`, `focus`, `has_promo` | Shipping option selected. |
| `checkout_payment_selected` | `provider`, `method_type`, `is_default`, `is_new` | Payment method selected or added. |
| `checkout_order_placed` | `success`, `total_amount`, `currency`, `item_count`, `is_international`, `has_promo`, `shipping_method_id`, `payment_method_type` | Order placement attempt. |
| `checkout_complete_viewed` | `total_amount`, `currency`, `item_count`, `notification_status` | Checkout completion screen loaded. |

## Share flow

| Event | Parameters | Trigger |
| --- | --- | --- |
| `design_share_opened` | `background`, `watermark_enabled`, `include_hashtags`, `persona`, `locale` | Share state initialized. |
| `design_share_background_selected` | `background` | Share background updated. |
| `design_share_watermark_toggled` | `enabled` | Watermark toggle changed. |
| `design_share_hashtags_toggled` | `enabled` | Hashtag toggle changed. |
| `design_share_regenerated` | `background`, `watermark_enabled`, `include_hashtags` | Share previews regenerated. |
| `design_share_submitted` | `target`, `success`, `background`, `watermark_enabled`, `include_hashtags` | Share attempt completes. |
