PORT ?= 3051

css:
	ironframe build -i static/input.css -o static/style.css "templates/**/*.html" "static/*.js"

css-watch:
	ironframe watch -i static/input.css -o static/style.css "templates/**/*.html" "static/*.js"

dev: css
	ADMIN_HTTP_ADDR=:$(PORT) go run .

test:
	go test ./...
