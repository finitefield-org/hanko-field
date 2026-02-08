PORT ?= 3052

css:
	ironframe build -i static/input.css -o static/style.css "templates/**/*.html" "static/*.js"

css-watch:
	ironframe watch -i static/input.css -o static/style.css "templates/**/*.html" "static/*.js"

dev: css
	HANKO_WEB_PORT=$(PORT) go run .

test:
	go test ./...
