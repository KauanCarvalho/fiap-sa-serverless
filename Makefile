GOARCH=amd64
GOOS=linux
LAMBDA_BINARY=bootstrap
ZIP_FILE=deployment.zip
WEBHOOK_LAMBDA_FOLDER=SQSEnqueuePaymentWebhook
SOURCE_FILE=main.go

.PHONY: help build-webhook zip-webhook test-webhook-api-gateway
.DEFAULT_GOAL := help

help:
	@echo ""
	@echo "Available targets:"
	@echo "  make help                      # Show this help message"
	@echo "  make build-webhook             # Build the Webhook Lambda function"
	@echo "  make zip-webhook               # Zip the Webhook Lambda function for deployment"
	@echo "  make test-webhook-api-gateway  # Run tests against the Webhook API in production"
	@echo ""

build-webhook:
	@echo "Building the Lambda function..."
	cd $(WEBHOOK_LAMBDA_FOLDER) && \
	GOARCH=$(GOARCH) GOOS=$(GOOS) go build -o $(LAMBDA_BINARY) $(SOURCE_FILE) && \
	cd ..

zip-webhook: build-webhook
	@echo "Zipping the Webhook Lambda function..."
	zip $(WEBHOOK_LAMBDA_FOLDER)/$(ZIP_FILE) $(WEBHOOK_LAMBDA_FOLDER)/$(LAMBDA_BINARY)

test-webhook-api-gateway:
	@echo "Testing the Webhook API..."
	./test/test-webhook.sh $(filter-out $@,$(MAKECMDGOALS))
