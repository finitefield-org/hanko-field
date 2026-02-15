PORT ?= 3052
MODE ?= mock
LOCALE ?= ja
IRONFRAME ?= devbox run -- ./scripts/ironframe.sh

css:
	$(IRONFRAME) build -i web/static/input.css -o web/static/style.css "web/templates/**/*.html" "web/static/*.js"

css-watch:
	$(IRONFRAME) watch -i web/static/input.css -o web/static/style.css "web/templates/**/*.html" "web/static/*.js"

dev: css
	PATH=$${HOST_PATH:+$$HOST_PATH:}$$PATH HANKO_WEB_PORT=$(PORT) HANKO_WEB_MODE=$(MODE) HANKO_WEB_LOCALE=$(LOCALE) cargo run

test:
	PATH=$${HOST_PATH:+$$HOST_PATH:}$$PATH cargo test
