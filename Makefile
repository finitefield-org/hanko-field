SHELL := /bin/bash

.PHONY: help dev admin-dev api-run web-dev admin api web docker-up docker-down docker-build docker-shell docker-up-workspace docker-up-firebase docker-down-workspace docker-down-firebase docker-api docker-admin docker-web docker-dev

help:
	@echo "Targets:"
	@echo "  admin-dev  - run admin dev server (tailwind + go run)"
	@echo "  api-run    - run API server"
	@echo "  web-dev    - run web dev server"
	@echo "  dev        - run admin, api, and web servers in parallel"
	@echo "  docker-up  - docker compose up -d --build"
	@echo "  docker-down- docker compose down"
	@echo "  docker-shell - docker compose exec workspace devbox shell"
	@echo "  docker-api   - run API inside workspace container (docker already up)"
	@echo "  docker-admin - run Admin inside workspace container (docker already up)"
	@echo "  docker-web   - run Web inside workspace container (docker already up)"
	@echo "  docker-dev   - run API/Admin/Web inside workspace container (docker already up)"
	@echo "  docker-up-workspace   - docker compose up -d --build workspace"
	@echo "  docker-up-firebase    - docker compose up -d --build firebase"
	@echo "  docker-down-workspace - docker compose stop workspace"
	@echo "  docker-down-firebase  - docker compose stop firebase"

admin-dev:
	@$(MAKE) -C admin dev

api-run:
	@$(MAKE) -C api run

web-dev:
	@$(MAKE) -C web dev

admin: admin-dev

api: api-run

web: web-dev

dev:
	@$(MAKE) -j 3 admin-dev api-run web-dev

docker-build:
	@docker compose build

docker-up:
	@docker compose up -d --build

docker-down:
	@docker compose down

docker-shell:
	@docker compose exec workspace devbox shell

docker-up-workspace:
	@docker compose up -d --build workspace

docker-up-firebase:
	@docker compose up -d --build firebase

docker-down-workspace:
	@docker compose stop workspace

docker-down-firebase:
	@docker compose stop firebase

docker-api:
	@docker compose exec workspace devbox run -- make -C api run

docker-admin:
	@docker compose exec workspace devbox run -- make -C admin dev

docker-web:
	@docker compose exec workspace devbox run -- make -C web dev

docker-dev:
	@docker compose exec workspace devbox run -- make -j 3 -C /workspace dev

.DEFAULT_GOAL := help
