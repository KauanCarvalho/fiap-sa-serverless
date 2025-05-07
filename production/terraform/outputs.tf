output "api_url" {
  description = "Base URL of the deployed API Gateway"
  value       = "${aws_api_gateway_rest_api.payment_api.execution_arn}/${aws_api_gateway_stage.prod.stage_name}/webhook_events"
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.payment_webhook_lambda.function_name
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.payment_webhook_events.id
}
