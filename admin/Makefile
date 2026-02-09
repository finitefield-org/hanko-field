PORT ?= 3051
MODE ?= mock
LOCALE ?= ja

css:
	ironframe build -i static/input.css -o static/style.css "templates/**/*.html" "static/*.js"

css-watch:
	ironframe watch -i static/input.css -o static/style.css "templates/**/*.html" "static/*.js"

dev: css
	ADMIN_HTTP_ADDR=:$(PORT) HANKO_ADMIN_MODE=$(MODE) HANKO_ADMIN_LOCALE=$(LOCALE) go run .

test:
	go test ./...
