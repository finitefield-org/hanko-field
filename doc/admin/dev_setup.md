# Admin Dev Setup

## Prerequisites

- Go 1.23+
- Node.js 20+ and npm (Tailwind CLI is installed locally via npm)
- `templ` generator (`go install github.com/a-h/templ/cmd/templ@latest`)

Ensure `$GOPATH/bin` (where `templ` is installed) is on your `PATH`.

## Initial Setup

```bash
cd admin
make ensure-tailwind
```

Install the Tailwind CLI once if missing:

```bash
npm install
```

## Common Tasks

- `make dev` – runs `go mod tidy`, starts Tailwind watcher, then launches the Go server.
- `make templ` – regenerate templ components after editing `.templ`.
- `make css` – build a minified Tailwind bundle at `public/static/app.css`.
- `make css-watch` – run Tailwind in watch mode only.
- `make lint` – `gofmt` and `go vet`.
- `make test-ui` – execute httptest-based integration smoke tests (see `internal/admin/httpserver/server_integration_test.go`).

Go build cache is redirected to `.gocache` to remain within the repo sandbox. Static assets are embedded from `public/static`.

## Configuration

- `ADMIN_HTTP_ADDR` (default `:3051`) controls the listen address.
- `ADMIN_BASE_PATH` (default `/admin`) sets the mount point for all admin routes.
- Attach an `Authorization: Bearer <token>` header (any non-empty token accepted by the default authenticator) when exploring authenticated routes locally. Browsers without a token will be redirected to `/admin/login`.
- Set `FIREBASE_PROJECT_ID` together with `GOOGLE_APPLICATION_CREDENTIALS` to enable Firebase ID token verification. When using the Firebase Auth emulator, also provide `FIREBASE_AUTH_EMULATOR_HOST`.

## Notes

- Generated `*_templ.go` files are committed. Run `make templ` whenever templates change.
- The Go server does not hot reload; restart `make dev` after Go or template changes.
- Tailwind scans `.templ` and generated component files (`tailwind.config.js` content globs).
