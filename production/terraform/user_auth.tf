resource "aws_cognito_user_pool" "user_pool" {
  name = "fiap-sa-user-pool"

  schema {
    name                 = "cpf"
    attribute_data_type  = "String"
    mutable              = true
  }

  schema {
    name                 = "client_id"
    attribute_data_type  = "String"
    mutable              = true
  }
}

resource "aws_cognito_user_pool_client" "app_client" {
  name            = "fiap-sa-app-client"
  user_pool_id    = aws_cognito_user_pool.user_pool.id
  generate_secret = false
}

resource "aws_lambda_function" "user_auth_lambda" {
  filename         = "../../lambdas/UserAuth/deployment.zip"
  function_name    = "userAuthLambda"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "main"
  runtime          = "provided.al2023"
  source_code_hash = filebase64sha256("../../lambdas/UserAuth/deployment.zip")

  environment {
    variables = {
      COGNITO_USER_POOL_ID   = aws_cognito_user_pool.user_pool.id
      COGNITO_CLIENT_ID      = aws_cognito_user_pool_client.app_client.id
      ORDER_SERVICE_BASE_URL = var.order_service_url
      REGION                 = var.region
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_api_gateway_rest_api" "order_api" {
  name        = "fiap-sa-api"
  description = "API for user authentication and order processing"
}

resource "aws_api_gateway_resource" "auth_resource" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  parent_id   = aws_api_gateway_rest_api.order_api.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_resource" "user_resource" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  parent_id   = aws_api_gateway_rest_api.order_api.root_resource_id
  path_part   = "user"
}

resource "aws_api_gateway_method" "auth_method" {
  rest_api_id   = aws_api_gateway_rest_api.order_api.id
  resource_id   = aws_api_gateway_resource.auth_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "user_method" {
  rest_api_id   = aws_api_gateway_rest_api.order_api.id
  resource_id   = aws_api_gateway_resource.user_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_integration" {
  rest_api_id             = aws_api_gateway_rest_api.order_api.id
  resource_id             = aws_api_gateway_resource.auth_resource.id
  http_method             = aws_api_gateway_method.auth_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.user_auth_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "user_integration" {
  rest_api_id             = aws_api_gateway_rest_api.order_api.id
  resource_id             = aws_api_gateway_resource.user_resource.id
  http_method             = aws_api_gateway_method.user_method.http_method
  integration_http_method = "GET"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.user_auth_lambda.invoke_arn
}

resource "aws_lambda_permission" "allow_api_gateway_for_user_auth" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.user_auth_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.order_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.order_api.id
  stage_name  = "prod"

  depends_on = [
    aws_api_gateway_method.auth_method,
    aws_api_gateway_method.user_method,
    aws_api_gateway_integration.auth_integration,
    aws_api_gateway_integration.user_integration,
  ]
}
