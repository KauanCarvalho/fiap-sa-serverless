output "api_url" {
  value = "https://${aws_api_gateway_rest_api.payment_api.id}.execute-api.${var.region}.amazonaws.com/prod/webhook_events"
}
