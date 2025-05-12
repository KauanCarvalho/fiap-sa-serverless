output "api_url" {
  description = "Base URL of the deployed API Gateway"
  value       = "https://${aws_api_gateway_rest_api.payment_api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.payment_api_stage.stage_name}/webhook_events"
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.payment_webhook_lambda.function_name
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.payment_webhook_events.id
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.api.api_endpoint
}

output "user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.client.id
}