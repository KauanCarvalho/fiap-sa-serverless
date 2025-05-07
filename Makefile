GOARCH=amd64
GOOS=linux
LAMBDA_BINARY=bootstrap
ZIP_FILE=deployment.zip
LAMBDA_FOLDER=SQSEnqueuePaymentWebhook
SOURCE_FILE=main.go

.PHONY: build zip
.DEFAULT_GOAL := help

help:
	@echo "Usage:"
	@echo "  make build   - Build the Lambda function"
	@echo "  make zip     - Zip the Lambda function for deployment"

build:
	@echo "Building the Lambda function..."
	cd $(LAMBDA_FOLDER) && \
	GOARCH=$(GOARCH) GOOS=$(GOOS) go build -o $(LAMBDA_BINARY) $(SOURCE_FILE) && \
	cd ..

zip: build
	@echo "Zipping the Lambda function..."
	zip $(LAMBDA_FOLDER)/$(ZIP_FILE) $(LAMBDA_FOLDER)/$(LAMBDA_BINARY)
