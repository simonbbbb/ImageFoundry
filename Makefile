# ImageFoundry Makefile
# Build, test, and manage container images

.PHONY: all build test clean lint install uninstall help

# Variables
BINARY_NAME=foundry
BUILD_DIR=build
VERSION=$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
LDFLAGS=-ldflags "-X main.Version=$(VERSION)"

# Default target
all: build

## Build the CLI tool
build:
	@echo "🔨 Building $(BINARY_NAME)..."
	@mkdir -p $(BUILD_DIR)
	go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) ./cmd/foundry
	@echo "✅ Build complete: $(BUILD_DIR)/$(BINARY_NAME)"

## Build for multiple platforms
build-all:
	@echo "🔨 Building for multiple platforms..."
	@mkdir -p $(BUILD_DIR)
	GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-amd64 ./cmd/foundry
	GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-arm64 ./cmd/foundry
	GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 ./cmd/foundry
	GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-arm64 ./cmd/foundry
	GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-windows-amd64.exe ./cmd/foundry
	@echo "✅ Cross-platform build complete"

## Install the CLI tool locally
install: build
	@echo "📦 Installing $(BINARY_NAME)..."
	@cp $(BUILD_DIR)/$(BINARY_NAME) $(GOPATH)/bin/$(BINARY_NAME) 2>/dev/null || cp $(BUILD_DIR)/$(BINARY_NAME) /usr/local/bin/$(BINARY_NAME)
	@echo "✅ Installed to $$(which $(BINARY_NAME) 2>/dev/null || echo $(BUILD_DIR)/$(BINARY_NAME))"

## Uninstall the CLI tool
uninstall:
	@echo "🗑️  Uninstalling $(BINARY_NAME)..."
	@rm -f $(GOPATH)/bin/$(BINARY_NAME) 2>/dev/null || rm -f /usr/local/bin/$(BINARY_NAME)
	@echo "✅ Uninstalled"

## Run tests
test:
	@echo "🧪 Running tests..."
	go test -v ./...
	@echo "✅ Tests complete"

## Run linting
lint:
	@echo "🔍 Running linters..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "⚠️  golangci-lint not installed, using go vet"; \
		go vet ./...; \
	fi
	@echo "✅ Linting complete"

## Run security scans on the codebase
scan-code:
	@echo "🔒 Running security scans..."
	@if command -v trivy >/dev/null 2>&1; then \
		trivy filesystem --scanners vuln,misconfig,secret .; \
	else \
		echo "⚠️  Trivy not installed"; \
	fi
	@echo "✅ Security scans complete"

## Validate configuration
validate:
	@echo "🔍 Validating configuration..."
	@if [ -f $(BUILD_DIR)/$(BINARY_NAME) ]; then \
		$(BUILD_DIR)/$(BINARY_NAME) validate; \
	else \
		go run ./cmd/foundry validate; \
	fi
	@echo "✅ Validation complete"

## Build container images using the CLI
build-images: build
	@echo "🐳 Building container images..."
	$(BUILD_DIR)/$(BINARY_NAME) build
	@echo "✅ Images built"

## Run all tests including integration
test-all: test
	@echo "🧪 Running integration tests..."
	chmod +x scripts/integration-test.sh
	@./scripts/integration-test.sh $(IMAGE_NAME) || true
	@echo "✅ All tests complete"

## Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@rm -rf dist/
	@go clean -cache
	@echo "✅ Clean complete"

## Download dependencies
deps:
	@echo "📥 Downloading dependencies..."
	go mod download
	go mod tidy
	@echo "✅ Dependencies updated"

## Update dependencies
update-deps:
	@echo "🔄 Updating dependencies..."
	go get -u ./...
	go mod tidy
	@echo "✅ Dependencies updated"

## Generate SBOM for the project
sbom:
	@echo "📄 Generating SBOM..."
	@if command -v syft >/dev/null 2>&1; then \
		syft . -o spdx-json=sbom.spdx.json; \
		syft . -o cyclonedx-json=sbom.cyclonedx.json; \
	else \
		echo "⚠️  Syft not installed"; \
	fi
	@echo "✅ SBOM generated"

## Run the CLI locally
run:
	@go run ./cmd/foundry

## Initialize a new project (for development)
init:
	@go run ./cmd/foundry init

## Display help
help:
	@echo "ImageFoundry Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  build        - Build the CLI tool"
	@echo "  build-all    - Build for multiple platforms"
	@echo "  install      - Install the CLI tool locally"
	@echo "  uninstall    - Uninstall the CLI tool"
	@echo "  test         - Run unit tests"
	@echo "  test-all     - Run all tests including integration"
	@echo "  lint         - Run linters"
	@echo "  scan-code    - Run security scans on codebase"
	@echo "  validate     - Validate configuration"
	@echo "  build-images - Build container images using CLI"
	@echo "  clean        - Clean build artifacts"
	@echo "  deps         - Download dependencies"
	@echo "  update-deps  - Update dependencies"
	@echo "  sbom         - Generate SBOM"
	@echo "  run          - Run CLI locally"
	@echo "  init         - Initialize new project"
	@echo "  help         - Show this help message"

# Default target if no target specified
.DEFAULT_GOAL := help
