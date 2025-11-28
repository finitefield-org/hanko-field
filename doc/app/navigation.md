# Navigation map and deep links
Source: `doc/app/app_design.md` (routes), personas: `doc/customer_journey/persona.md`

## Navigator structure
- Root: `ProviderScope` + `MaterialApp.router`.
- Shell: bottom tabs (5): `作成` (`/design`), `ショップ` (`/shop`), `注文` (`/orders`), `マイ印鑑` (`/library`), `プロフィール` (`/profile`).
- Each tab owns its own navigator stack and keeps state when backgrounded; tab switch restores previous stack.
- Global overlays accessible from any tab: notification bell, search, help; they open on top of current tab stack.
- Modal flows (sheet/fullscreen): auth, locale/persona selection, permissions prompts.

## Navigation guards
- `authGuard`: required for checkout, orders, library exports/shares, profile edits; guest allowed for browse/design until checkout confirm.
- `onboardingGuard`: splash → onboarding → locale/persona → auth; deep links reroute to onboarding if incomplete.
- `appUpdateGuard`: blocks app usage when remote config requires update (`/app-update`).
- `persona/locale guard`: adjusts downstream UI; if missing, prompt `/locale` + `/persona` before proceeding.

## Route table (key screens)
| Route ID | Path | Tab/Stack | Args | Guard | Deep link | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| splash | /splash | root | - | - | hanko://splash | version/feature flag check |
| onboarding | /onboarding | root | - | onboardingGuard | hanko://onboarding | tutorial |
| locale | /locale | root | - | onboardingGuard | hanko://locale | language/region |
| persona | /persona | root | - | onboardingGuard | hanko://persona | JP/EN persona |
| auth | /auth | modal | redirect | onboardingGuard | hanko://auth | Apple/Google/Email/guest |
| home | /home | creation tab | - | auth optional | hanko://home | featured content |
| notifications | /notifications | overlay | - | authGuard | hanko://notifications | list + push entry |
| search | /search | overlay | q? | - | hanko://search?q= | segmented results |
| design new | /design/new | creation tab | type? | - | hanko://design/new | entry: text/upload/logo |
| design input | /design/input | creation tab | type? | - | hanko://design/input | name input |
| kanji map | /design/input/kanji-map | creation tab | name | persona=foreign | hanko://design/input/kanji-map | meanings list |
| design style | /design/style | creation tab | type | - | hanko://design/style | script/shape/template |
| design editor | /design/editor | creation tab | designId? | auth optional | hanko://design/editor | canvas controls |
| design AI | /design/ai | creation tab | designId | auth optional | hanko://design/ai | suggestions |
| design check | /design/check | creation tab | designId | persona=jp | hanko://design/check | registrability |
| design preview | /design/preview | creation tab | designId | - | hanko://design/preview | actual size, share |
| design export | /design/export | creation tab | designId | authGuard for download | hanko://design/export | PNG/SVG |
| design versions | /design/versions | creation tab | designId | authGuard | hanko://design/versions | diff/rollback |
| design share | /design/share | creation tab | designId | authGuard | hanko://design/share | mocked social posts |
| shop home | /shop | shop tab | - | - | hanko://shop | categories/promos |
| material detail | /materials/:materialId | shop tab | materialId | - | hanko://materials/{id} | specs/gallery |
| product detail | /products/:productId | shop tab | productId | - | hanko://products/{id} | variants/pricing |
| add-ons | /products/:productId/addons | shop tab | productId | - | hanko://products/{id}/addons | upsells |
| cart | /cart | shop tab | - | auth optional | hanko://cart | line edit/promo |
| checkout address | /checkout/address | shop tab | - | authGuard | hanko://checkout/address | JP/int’l formats |
| checkout shipping | /checkout/shipping | shop tab | - | authGuard | hanko://checkout/shipping | domestic/international |
| checkout payment | /checkout/payment | shop tab | - | authGuard | hanko://checkout/payment | tokenized refs |
| checkout review | /checkout/review | shop tab | - | authGuard | hanko://checkout/review | snapshot/terms |
| checkout complete | /checkout/complete | shop tab | orderId | authGuard | hanko://checkout/complete?orderId= | confirmation |
| orders list | /orders | orders tab | filter? | authGuard | hanko://orders | infinite scroll |
| order detail | /orders/:orderId | orders tab | orderId | authGuard | hanko://orders/{id} | snapshot/totals |
| production timeline | /orders/:orderId/production | orders tab | orderId | authGuard | hanko://orders/{id}/production | stages |
| shipment tracking | /orders/:orderId/tracking | orders tab | orderId | authGuard | hanko://orders/{id}/tracking | carrier events |
| invoice | /orders/:orderId/invoice | orders tab | orderId | authGuard | hanko://orders/{id}/invoice | PDF |
| reorder | /orders/:orderId/reorder | orders tab | orderId | authGuard | hanko://orders/{id}/reorder | clones cart |
| library list | /library | library tab | sort/filter? | authGuard | hanko://library | grid/list |
| design detail | /library/:designId | library tab | designId | authGuard | hanko://library/{id} | metadata/usage |
| library versions | /library/:designId/versions | library tab | designId | authGuard | hanko://library/{id}/versions | reuse diff |
| library duplicate | /library/:designId/duplicate | library tab | designId | authGuard | hanko://library/{id}/duplicate | new draft |
| library export | /library/:designId/export | library tab | designId | authGuard | hanko://library/{id}/export | permissions |
| library shares | /library/:designId/shares | library tab | designId | authGuard | hanko://library/{id}/shares | manage links |
| guides list | /guides | profile tab | - | auth optional | hanko://guides | cultural content |
| guide detail | /guides/:slug | profile tab | slug | auth optional | hanko://guides/{slug} | markdown/HTML |
| kanji dictionary | /kanji/dictionary | profile tab | query? | auth optional | hanko://kanji/dictionary | search/favorites |
| how-to | /howto | profile tab | - | auth optional | hanko://howto | tutorials/videos |
| profile home | /profile | profile tab | - | authGuard for edits | hanko://profile | persona toggle/quick links |
| addresses | /profile/addresses | profile tab | - | authGuard | hanko://profile/addresses | CRUD/defaults |
| payments | /profile/payments | profile tab | - | authGuard | hanko://profile/payments | PSP tokens |
| notifications settings | /profile/notifications | profile tab | - | authGuard | hanko://profile/notifications | categories/schedule |
| locale settings | /profile/locale | profile tab | - | authGuard | hanko://profile/locale | overrides |
| legal | /profile/legal | profile tab | - | - | hanko://profile/legal | static/ offline |
| support | /profile/support | profile tab | - | auth optional | hanko://profile/support | links |
| linked accounts | /profile/linked-accounts | profile tab | - | authGuard | hanko://profile/linked-accounts | social auth |
| data export | /profile/export | profile tab | - | authGuard | hanko://profile/export | archive |
| account delete | /profile/delete | profile tab | - | authGuard | hanko://profile/delete | confirm |
| faq | /support/faq | overlay | category? | auth optional | hanko://support/faq | categories/search |
| contact | /support/contact | overlay | ticketId? | auth optional | hanko://support/contact | form/upload |
| chat | /support/chat | overlay | threadId? | authGuard | hanko://support/chat | bot→live |
| status | /status | overlay | - | - | hanko://status | system status |
| permissions | /permissions | modal | - | - | hanko://permissions | photo/storage/notifications |
| changelog | /updates/changelog | overlay | - | - | hanko://updates/changelog | version history |
| app update | /app-update | modal | - | appUpdateGuard | hanko://app-update | forced update |
| offline | /offline | modal | - | - | hanko://offline | cached content |
| error | /error | modal | code? | - | hanko://error?code= | generic error |

## Deep link handling
- URI schemes: `hanko://` (app), `https://hanko.app/*` (universal links). Both map to the same route table.
- Entry sequence: splash → appUpdateGuard → onboarding/locale/persona → auth (if required) → target route.
- Unknown/deleted resources: route to `/error` with code + toast, then offer fallback (e.g., orders list).
- Push notifications map to deep links (orders, chat, notifications). Respect current tab stack; push onto its navigator.
- Web share targets (design preview/share) should support “view-only” for unauthenticated users; prompt to sign in for actions.

## Back behavior
- Android system back: pop current tab stack; if at root of a tab, exit app after confirmation. Deep links should preserve ability to back to previous in-app location where applicable.
- iOS swipe-back: allowed within tab stack; modal sheets dismissible unless blocked by critical flows (payment in progress).
- Tab reselection: when tapping active tab, pop to that tab’s root.

## State retention
- Each tab’s navigator retains scroll positions and filters when switching tabs.
- Modal/auth flows return to the originating route/deep link target on completion.
