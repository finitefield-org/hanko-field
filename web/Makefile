GO ?= go
BIN_DIR := $(CURDIR)/bin
MAIN_PKG := ./cmd/web
BINARY := $(BIN_DIR)/hanko-web
NODE_BIN := ./node_modules/.bin
TAILWIND ?= $(NODE_BIN)/tailwindcss
HTMX_VERSION := 2.0.3
HTMX_URL := https://cdn.jsdelivr.net/npm/htmx.org@$(HTMX_VERSION)/dist/htmx.min.js

.PHONY: run dev build fmt test tidy css css-watch tools htmx assets

run:
	DEV=1 $(GO) run $(MAIN_PKG)

dev: assets
	@$(MAKE) run

build:
	@mkdir -p $(BIN_DIR)
	$(GO) build -o $(BINARY) $(MAIN_PKG)

fmt:
	@gofmt -w .

test:
	$(GO) test ./...

tidy:
	$(GO) mod tidy

.DEFAULT_GOAL := build

# --- Assets (Tailwind CLI) ---
css: tools
	@mkdir -p public/assets
	@NODE_ENV=production $(TAILWIND) -c tailwind.config.js -i assets/css/input.css -o public/assets/app.css --minify

css-watch: tools
	@mkdir -p public/assets
	@$(TAILWIND) -c tailwind.config.js -i assets/css/input.css -o public/assets/app.css --watch

tools:
	@if [ ! -x $(TAILWIND) ]; then \
		echo "Installing web npm deps..."; \
		npm install; \
	fi
	@$(TAILWIND) --version >/dev/null 2>&1 || ( \
		echo "Missing tailwindcss CLI. Install with:"; \
		echo "  npm install"; \
		exit 1; \
	)

htmx:
	@if [ ! -f public/assets/js/htmx.min.js ]; then \
		echo "Missing public/assets/js/htmx.min.js. Fetch with:"; \
		echo "  curl -fsSL \"$(HTMX_URL)\" -o public/assets/js/htmx.min.js"; \
		exit 1; \
	fi

assets: css htmx
