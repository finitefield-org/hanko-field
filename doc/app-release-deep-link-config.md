# App Release Deep Link Config

This checklist covers Stripe Checkout return routes for the Flutter app release.

## App Links / Universal Links

- Android package: `org.finitefield.hankofield`
- iOS bundle ID: `org.finitefield.hankofield`
- Primary app link domain: `finitefield.org`
- Secondary app link domain: `www.finitefield.org`
- Checkout return paths: `/payment/*`, `/en/payment/*`, `/ja/payment/*`
- Custom scheme fallback: `hankofield://checkout/*`

## Hosted Association Files

Before release, host the platform association files on both domains.

- Android: `https://finitefield.org/.well-known/assetlinks.json`
- Android: `https://www.finitefield.org/.well-known/assetlinks.json`
- iOS: `https://finitefield.org/.well-known/apple-app-site-association`
- iOS: `https://www.finitefield.org/.well-known/apple-app-site-association`

`assetlinks.json` must include the release signing certificate SHA-256 fingerprint for `org.finitefield.hankofield`. The Apple App Site Association file must include the App ID `<APPLE_TEAM_ID>.org.finitefield.hankofield` and allow the checkout return paths above.

## Stripe Environment

Production Stripe Checkout return URLs should use the verified app link domain:

```env
API_PSP_STRIPE_CHECKOUT_SUCCESS_URL=https://finitefield.org/payment/success?session_id={CHECKOUT_SESSION_ID}
API_PSP_STRIPE_CHECKOUT_CANCEL_URL=https://finitefield.org/payment/failure
HANKO_WEB_SITE_BASE_URL=https://finitefield.org
```

The API appends `checkout=success` or `checkout=cancel`, `order_id`, and `lang`, so the app receives enough context to show success, pending, cancel, or failure states.

## Smoke Test

1. Install a release-signed app build.
2. Verify Android App Links or iOS Universal Links for `https://finitefield.org/payment/success?checkout=success&order_id=<order>&session_id=<session>&lang=en`.
3. Start Checkout from the app, pay with Stripe test mode, and confirm the return opens the app at the payment status check screen.
4. Cancel Checkout and confirm the app opens the canceled state.
5. Open an invalid checkout route and confirm the app shows the deep link error state.
