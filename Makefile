COMPOSE ?= docker compose
WORKSPACE_SERVICE ?= workspace

ENV ?= dev
ENV_FILE ?= .env.$(ENV)

API_PORT ?= 3050
ADMIN_PORT ?= 3051
WEB_PORT ?= 3052
MODE ?= mock
LOCALE ?= ja

.PHONY: help docker-up docker-down docker-shell docker-api docker-admin docker-web docker-dev

ifneq ($(wildcard $(ENV_FILE)),)
COMPOSE_ENV_FILE_OPT := --env-file $(ENV_FILE)
else
COMPOSE_ENV_FILE_OPT :=
endif

ENV_LOAD_CMD = if [ -f "/workspace/$(ENV_FILE)" ]; then set -a; . "/workspace/$(ENV_FILE)"; set +a; fi;

help:
	@echo "Available targets:"
	@echo "  make docker-up      # Build and start workspace container"
	@echo "  make docker-down    # Stop containers"
	@echo "  make docker-shell   # Open devbox shell in workspace container"
	@echo "  make docker-api     # Run API server in container"
	@echo "  make docker-admin   # Run Admin server in container"
	@echo "  make docker-web     # Run Web server in container"
	@echo "  make docker-dev     # Run API/Admin/Web together in container"
	@echo ""
	@echo "Options:"
	@echo "  ENV=dev|prod"
	@echo "  ENV_FILE=.env.dev|.env.prod"

docker-up:
	$(COMPOSE) $(COMPOSE_ENV_FILE_OPT) build
	$(COMPOSE) $(COMPOSE_ENV_FILE_OPT) up -d $(WORKSPACE_SERVICE)

docker-down:
	$(COMPOSE) $(COMPOSE_ENV_FILE_OPT) down

docker-shell:
	$(COMPOSE) exec $(WORKSPACE_SERVICE) sh -lc '$(ENV_LOAD_CMD) exec devbox shell'

docker-api:
	$(COMPOSE) exec $(WORKSPACE_SERVICE) sh -lc 'set -e; $(ENV_LOAD_CMD) cd /workspace && devbox run -- make -C api run PORT=$${API_SERVER_PORT:-$(API_PORT)}'

docker-admin:
	$(COMPOSE) exec $(WORKSPACE_SERVICE) sh -lc 'set -e; $(ENV_LOAD_CMD) cd /workspace && devbox run -- make -C admin dev PORT=$${ADMIN_PORT:-$(ADMIN_PORT)} MODE=$${HANKO_ADMIN_MODE:-$(MODE)} LOCALE=$${HANKO_ADMIN_LOCALE:-$(LOCALE)}'

docker-web:
	$(COMPOSE) exec $(WORKSPACE_SERVICE) sh -lc 'set -e; $(ENV_LOAD_CMD) cd /workspace && devbox run -- make -C web dev PORT=$${HANKO_WEB_PORT:-$(WEB_PORT)} MODE=$${HANKO_WEB_MODE:-$(MODE)} LOCALE=$${HANKO_WEB_LOCALE:-$(LOCALE)}'

docker-dev:
	$(COMPOSE) exec $(WORKSPACE_SERVICE) sh -lc 'set -e; $(ENV_LOAD_CMD) cd /workspace; devbox run -- sh -lc "set -e; ./scripts/ironframe.sh build -i admin/static/input.css -o admin/static/style.css \"admin/templates/**/*.html\" \"admin/static/*.js\"; ./scripts/ironframe.sh build -i web/static/input.css -o web/static/style.css \"web/templates/**/*.html\" \"web/static/*.js\"; make -C api run PORT=$${API_SERVER_PORT:-$(API_PORT)} & api_pid=\$$!; make -C admin dev PORT=$${ADMIN_PORT:-$(ADMIN_PORT)} MODE=$${HANKO_ADMIN_MODE:-$(MODE)} LOCALE=$${HANKO_ADMIN_LOCALE:-$(LOCALE)} IRONFRAME=true & admin_pid=\$$!; set +e; make -C web dev PORT=$${HANKO_WEB_PORT:-$(WEB_PORT)} MODE=$${HANKO_WEB_MODE:-$(MODE)} LOCALE=$${HANKO_WEB_LOCALE:-$(LOCALE)} IRONFRAME=true; status=\$$?; set -e; kill \$$api_pid \$$admin_pid 2>/dev/null || true; wait \$$api_pid \$$admin_pid 2>/dev/null || true; exit \$$status"'
