PORT ?= 3050

run:
	PATH=$${HOST_PATH:+$$HOST_PATH:}$$PATH API_SERVER_PORT=$(PORT) cargo run --bin hanko-field-api

seed-catalog:
	PATH=$${HOST_PATH:+$$HOST_PATH:}$$PATH cargo run --bin seed_catalog

test:
	PATH=$${HOST_PATH:+$$HOST_PATH:}$$PATH cargo test
