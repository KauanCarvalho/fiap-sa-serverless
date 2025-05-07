terraform {
  cloud {
    organization = "fiap-sa"

    workspaces {
      name = "fiap-sa-serverless"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_sqs_queue" "payment_webhook_events" {
  name = "fiap_sa_payment_webhook_events"
}

resource "aws_lambda_function" "payment_webhook_lambda" {
  filename         = "lambda_sqs_enqueue_paymet_events.zip"
  function_name    = "paymentWebhookLambda"
  role             = var.lab_role
  handler          = "main"
  runtime          = "go1.x"
  source_code_hash = filebase64sha256("../../SQSEnqueuePaymentWebhook/lambda_sqs_enqueue_paymet_events.zip")

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.payment_webhook_events.id
    }
  }
}

resource "aws_api_gateway_rest_api" "payment_api" {
  name        = "payment-webhook-api"
  description = "API Gateway for Payment Webhook"
}

resource "aws_api_gateway_resource" "webhook_events" {
  rest_api_id = aws_api_gateway_rest_api.payment_api.id
  parent_id   = aws_api_gateway_rest_api.payment_api.root_resource_id
  path_part   = "webhook_events"
}

resource "aws_api_gateway_method" "post_webhook_events" {
  rest_api_id   = aws_api_gateway_rest_api.payment_api.id
  resource_id   = aws_api_gateway_resource.webhook_events.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.payment_api.id
  resource_id             = aws_api_gateway_resource.webhook_events.id
  http_method             = aws_api_gateway_method.post_webhook_events.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.payment_webhook_lambda.arn}/invocations"
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  function_name = aws_lambda_function.payment_webhook_lambda.arn
  source_arn    = "${aws_api_gateway_rest_api.payment_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "payment_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.payment_api.id
}
