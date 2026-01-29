# Web Dev Setup

This guide sets up the Go web module with chi router, html/template rendering, Tailwind CLI (installed locally via npm), local htmx asset, and dev tooling.

## Prerequisites
- Go 1.23+
- Node.js 20+ and npm (Tailwind CLI is installed locally via npm)

## Running the dev server
Two terminals recommended: one for CSS watch, one for the Go server.

Terminal A (Tailwind watch/build):
```bash
cd web
# Install Tailwind CLI once if missing.
#   npm install

make css-watch
```

Terminal B (Go server):
```bash
cd web
make dev
# or
make run
```

The Go server does not hot reload. Restart `make dev` after Go or template changes.

Then open http://localhost:3052

Environment variables:
- `HANKO_WEB_PORT`: listen port (fallback to Cloud Run `PORT`), default 8080
- `HANKO_WEB_DEV=1`: enable template re-parse on each request
- `HANKO_WEB_ENV`: environment name (e.g., `dev`, `staging`, `prod`)

## Useful commands
```bash
cd web
make htmx       # download htmx.min.js into public/assets/js
make css        # one-shot Tailwind build to public/assets/app.css
make css-watch  # watch mode; rebuild on template/CSS changes
make build      # build Go binary to web/bin
make test       # run Go tests
make tidy       # go mod tidy
```

## Structure
- `web/cmd/web`: main entry
- `web/templates`: layouts, pages, partials for html/template
- `web/public/assets`: output CSS/JS (served at `/assets/...`)
- `web/assets/css/input.css`: Tailwind source
- TailwindCSS is compiled from `assets/css/input.css` to `public/assets/app.css`.
- Run `make htmx` once to fetch `public/assets/js/htmx.min.js` locally; the base layout references `/assets/js/htmx.min.js`.

## Notes
- This scaffold uses `html/template`. If/when migrating to `templ`, maintain the same directory structure and route organization.
