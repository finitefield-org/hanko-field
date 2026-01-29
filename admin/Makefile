SHELL := /bin/bash

GOCACHE ?= $(PWD)/.gocache
NODE_BIN := ./node_modules/.bin
TAILWIND_BIN ?= $(NODE_BIN)/tailwindcss
TAILWIND_INPUT := ./web/styles/tailwind.css
TAILWIND_OUTPUT := ./public/static/app.css

.PHONY: dev
dev: tidy ensure-tailwind ## Start dev server with Tailwind watcher
	@set -euo pipefail; \
	echo "Starting Tailwind watcher..."; \
	$(TAILWIND_BIN) -i $(TAILWIND_INPUT) -o $(TAILWIND_OUTPUT) --watch & \
	TW_PID=$$!; \
	trap "kill $$TW_PID" EXIT; \
	echo "Starting Go server..."; \
	GOCACHE=$(GOCACHE) go run ./cmd/admin

.PHONY: run
run: ## Run the Go server without hot reload
	@mkdir -p $(GOCACHE)
	@GOCACHE=$(GOCACHE) go run ./cmd/admin

.PHONY: css
css: ensure-tailwind ## Build Tailwind assets
	@NODE_ENV=production $(TAILWIND_BIN) -i $(TAILWIND_INPUT) -o $(TAILWIND_OUTPUT) --minify

.PHONY: css-watch
css-watch: ensure-tailwind ## Watch Tailwind assets
	@$(TAILWIND_BIN) -i $(TAILWIND_INPUT) -o $(TAILWIND_OUTPUT) --watch

.PHONY: tidy
tidy: ## Run go mod tidy
	@mkdir -p $(GOCACHE)
	@GOCACHE=$(GOCACHE) go mod tidy

.PHONY: lint
lint: ## Run gofmt and go vet
	@gofmt -w $$(find . -name '*.go' -not -path "./.gocache/*")
	@mkdir -p $(GOCACHE)
	@GOCACHE=$(GOCACHE) go vet ./...

.PHONY: test-ui
test-ui: ## Run admin integration smoke tests
	@go test ./internal/admin/httpserver

.PHONY: ensure-tailwind
ensure-tailwind: ## Ensure Tailwind CLI is available on PATH
	@if [ ! -x $(TAILWIND_BIN) ]; then \
		echo "Installing admin npm deps..."; \
		npm install; \
	fi
	@$(TAILWIND_BIN) --version >/dev/null 2>&1 || ( \
		echo "Missing tailwindcss CLI. Install with:"; \
		echo "  npm install"; \
		exit 1; \
	)

.PHONY: clean
clean: ## Remove build artifacts
	@rm -rf $(GOCACHE) tmp
