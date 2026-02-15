PORT ?= 3052
MODE ?= mock
LOCALE ?= ja

css:
	ironframe build -i static/input.css -o static/style.css "templates/**/*.html" "static/*.js"

css-watch:
	ironframe watch -i static/input.css -o static/style.css "templates/**/*.html" "static/*.js"

dev: css
	HANKO_WEB_PORT=$(PORT) HANKO_WEB_MODE=$(MODE) HANKO_WEB_LOCALE=$(LOCALE) cargo run

test:
	cargo test
