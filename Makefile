VERSION ?= 0.0.1
CONTAINER_MANAGER ?= podman
# Image URL to use all building/pushing image targets
IMG ?= quay.io/ariobolo/dater:${VERSION}

# Go and compilation related variables
GOPATH ?= $(shell go env GOPATH)
BUILD_DIR ?= out
SOURCE_DIRS = cmd pkg test
# https://golang.org/cmd/link/
LDFLAGS := $(VERSION_VARIABLES) -extldflags='-static' ${GO_EXTRA_LDFLAGS}
GCFLAGS := all=-N -l

# Schemas
SCHEMAS_PKG ?= pkg/schemas

# Add default target
.PHONY: default
default: install

# Create and update the vendor directory
.PHONY: vendor
vendor:
	go mod tidy
	go mod vendor

.PHONY: check
check: build test lint

# Start of the actual build targets

.PHONY: install
install: $(SOURCES)
	go install -ldflags="$(LDFLAGS)" $(GO_EXTRA_BUILDFLAGS) ./cmd

$(BUILD_DIR)/dater: $(SOURCES)
	GOOS=linux GOARCH=amd64 go generate ./...
	GOOS=linux GOARCH=amd64 go build -gcflags="$(GCFLAGS)" -ldflags="$(LDFLAGS)" -o $(BUILD_DIR)/dater $(GO_EXTRA_BUILDFLAGS) ./cmd


 
.PHONY: build 
build: $(BUILD_DIR)/dater

.PHONY: test
test:
	go test -race --tags build -v -ldflags="$(VERSION_VARIABLES)" ./pkg/... ./cmd/...

.PHONY: clean ## Remove all build artifacts
clean:
	rm -rf $(BUILD_DIR)
	rm -f $(GOPATH)/bin/dater
# Remove generated go structs from schemas
	find $(SCHEMAS_PKG)/*/ -type f -name "*.go" -delete 
	find $(SCHEMAS_PKG) -type d -name "generated" -exec rm -rf {} +

.PHONY: fmt
fmt:
	@gofmt -l -w $(SOURCE_DIRS)

$(GOPATH)/bin/golangci-lint:
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.46.2

# Run golangci-lint against code
.PHONY: lint
lint: $(GOPATH)/bin/golangci-lint
	$(GOPATH)/bin/golangci-lint run

# Build the container image
.PHONY: container-build
container-build: test
	${CONTAINER_MANAGER} build -t ${IMG} -f images/Dockerfile .

# Push the docker image
.PHONY: container-push
container-push:
	${CONTAINER_MANAGER} push ${IMG}
	
