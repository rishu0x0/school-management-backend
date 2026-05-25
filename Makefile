.PHONY: run build test lint tidy migrate-up migrate-down migrate-create

# ─── Development ──────────────────────────────────────────────────────────────
run:
	set -a && source .env && set +a && go run ./cmd/server

build:
	go build -o bin/server ./cmd/server

test:
	go test ./... -v

lint:
	go vet ./...

tidy:
	go mod tidy

# ─── Schema Migrations (golang-migrate) ───────────────────────────────────────
# Requires: migrate CLI  →  brew install golang-migrate
#           or: go install github.com/golang-migrate/migrate/v4/cmd/migrate@latest
#
# DATABASE_URL must be set (or source your .env first):
#   make migrate-up
#   DATABASE_URL=postgresql://postgres:pass@10.0.0.5:5432/schoolmgmt make migrate-up

MIGRATIONS_DIR := migrations
DATABASE_URL   ?= $(shell grep '^DATABASE_URL=' .env 2>/dev/null | cut -d= -f2-)

migrate-up:
	@echo "▶ Applying all pending migrations..."
	migrate -path $(MIGRATIONS_DIR) -database "$(DATABASE_URL)" up
	@echo "✓ Migrations applied."

migrate-down:
	@echo "▼ Rolling back the last migration..."
	migrate -path $(MIGRATIONS_DIR) -database "$(DATABASE_URL)" down 1
	@echo "✓ Rollback complete."

# Usage: make migrate-create NAME=add_indexes
migrate-create:
	@[ "$(NAME)" ] || ( echo "Error: NAME is required. Usage: make migrate-create NAME=<name>"; exit 1 )
	migrate create -ext sql -dir $(MIGRATIONS_DIR) -seq $(NAME)
	@echo "✓ Created up/down files for '$(NAME)' in $(MIGRATIONS_DIR)/"
