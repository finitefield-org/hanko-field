SHELL := /bin/bash

GOCACHE ?= $(PWD)/.gocache
BIN_DIR ?= $(PWD)/bin
TAILWIND_VERSION ?= 3.4.14
TAILWIND_INPUT := ./web/styles/tailwind.css
TAILWIND_OUTPUT := ./public/static/app.css

UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

ifeq ($(UNAME_S),Darwin)
  TAILWIND_OS := macos
else ifeq ($(UNAME_S),Linux)
  TAILWIND_OS := linux
else
  $(error Unsupported OS $(UNAME_S). Please install Tailwind manually.)
endif

ifeq ($(UNAME_M),x86_64)
  TAILWIND_ARCH := x64
else ifeq ($(UNAME_M),amd64)
  TAILWIND_ARCH := x64
else ifeq ($(UNAME_M),arm64)
  TAILWIND_ARCH := arm64
else ifeq ($(UNAME_M),aarch64)
  TAILWIND_ARCH := arm64
else
  $(error Unsupported architecture $(UNAME_M). Please install Tailwind manually.)
endif

TAILWIND_TARGET := $(BIN_DIR)/tailwindcss-v$(TAILWIND_VERSION)
TAILWIND_BIN := $(BIN_DIR)/tailwindcss
TAILWIND_URL := https://github.com/tailwindlabs/tailwindcss/releases/download/v$(TAILWIND_VERSION)/tailwindcss-$(TAILWIND_OS)-$(TAILWIND_ARCH)

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
ensure-tailwind: ## Download Tailwind standalone binary if required version missing
	@mkdir -p $(BIN_DIR)
	@REQUIRED="v$(TAILWIND_VERSION)"; \
	NEED_DOWNLOAD=0; \
	if [ -x $(TAILWIND_TARGET) ]; then \
		CURRENT=$$($(TAILWIND_TARGET) --help 2>/dev/null | awk 'NF{print $$2; exit}'); \
		if [ -z "$$CURRENT" ] || [ "$$CURRENT" != "$$REQUIRED" ]; then \
			NEED_DOWNLOAD=1; \
		fi; \
	else \
		NEED_DOWNLOAD=1; \
	fi; \
	if [ "$$NEED_DOWNLOAD" -eq 1 ]; then \
		echo "Downloading tailwindcss $$REQUIRED ($(TAILWIND_OS)-$(TAILWIND_ARCH))..."; \
		rm -f $(TAILWIND_TARGET); \
		curl -sSL -o $(TAILWIND_TARGET) $(TAILWIND_URL); \
		chmod +x $(TAILWIND_TARGET); \
	fi; \
	ln -sf $$(basename $(TAILWIND_TARGET)) $(TAILWIND_BIN); \
	$(TAILWIND_TARGET) --help >/dev/null 2>&1

.PHONY: clean
clean: ## Remove build artifacts
	@rm -rf $(GOCACHE) tmp
