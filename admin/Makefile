PORT ?= 3051
MODE ?= mock
LOCALE ?= ja
IRONFRAME ?= devbox run -- ./scripts/ironframe.sh

css:
	$(IRONFRAME) build -i admin/static/input.css -o admin/static/style.css "admin/templates/**/*.html" "admin/static/*.js"

css-watch:
	$(IRONFRAME) watch -i admin/static/input.css -o admin/static/style.css "admin/templates/**/*.html" "admin/static/*.js"

dev: css
	PATH=$${HOST_PATH:+$$HOST_PATH:}$$PATH ADMIN_HTTP_ADDR=:$(PORT) HANKO_ADMIN_MODE=$(MODE) HANKO_ADMIN_LOCALE=$(LOCALE) go run .

test:
	PATH=$${HOST_PATH:+$$HOST_PATH:}$$PATH go test ./...
