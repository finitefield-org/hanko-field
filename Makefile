SHELL := /bin/bash

.PHONY: help dev admin-dev api-run web-dev admin api web docker-up docker-down docker-build docker-shell

help:
	@echo "Targets:"
	@echo "  admin-dev  - run admin dev server (tailwind + go run)"
	@echo "  api-run    - run API server"
	@echo "  web-dev    - run web dev server"
	@echo "  dev        - run admin, api, and web servers in parallel"
	@echo "  docker-up  - docker compose up -d --build"
	@echo "  docker-down- docker compose down"
	@echo "  docker-shell - docker compose exec workspace devbox shell"

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

.DEFAULT_GOAL := help
