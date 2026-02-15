PORT ?= 3050

run:
	PATH=$${HOST_PATH:+$$HOST_PATH:}$$PATH API_SERVER_PORT=$(PORT) go run .

test:
	PATH=$${HOST_PATH:+$$HOST_PATH:}$$PATH go test ./...
