SHELL := /bin/bash

.PHONY: help dev admin-dev api-run web-dev admin api web

help:
	@echo "Targets:"
	@echo "  admin-dev  - run admin dev server (templ + tailwind + air)"
	@echo "  api-run    - run API server"
	@echo "  web-dev    - run web dev server"
	@echo "  dev        - run admin, api, and web servers in parallel"

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

.DEFAULT_GOAL := help
