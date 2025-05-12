resource "aws_cognito_user_pool" "user_pool" {
  name = "fiap-sa-auth-pool"

  auto_verified_attributes = ["email"]

  schema {
    name                     = "cpf"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = false
    required                 = false
    string_attribute_constraints {
      min_length = 11
      max_length = 11
    }
  }

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  mfa_configuration = "OFF"
}

resource "aws_cognito_user_pool_client" "client" {
  name            = "fiap-sa-client"
  user_pool_id    = aws_cognito_user_pool.user_pool.id
  generate_secret = false

  allowed_oauth_flows       = ["code"]
  allowed_oauth_scopes      = ["phone", "email", "openid"]
  callback_urls             = ["https://example.com/callback"]
  logout_urls               = ["https://example.com/logout"]

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

resource "aws_lambda_function" "signup_lambda" {
  filename         = "../../UserAuth/deployment.zip"
  function_name    = "signupLambda"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "main"
  runtime          = "provided.al2023"
  source_code_hash = filebase64sha256("../../UserAuth/deployment.zip")

  environment {
    variables = {
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.user_pool.id
      COGNITO_CLIENT_ID    = aws_cognito_user_pool_client.client.id
    }
  }
}

resource "aws_lambda_function" "login_lambda" {
  filename         = "../../UserLogin/deployment.zip"
  function_name    = "loginLambda"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "main"
  runtime          = "provided.al2023"
  source_code_hash = filebase64sha256("../../UserLogin/deployment.zip")

  environment {
    variables = {
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.user_pool.id
      COGNITO_CLIENT_ID    = aws_cognito_user_pool_client.client.id
    }
  }
}

resource "aws_apigatewayv2_api" "api" {
  name          = "signup-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "signup_lambda_integration" {
  api_id                = aws_apigatewayv2_api.api.id
  integration_type      = "AWS_PROXY"
  integration_uri       = aws_lambda_function.signup_lambda.invoke_arn
  integration_method    = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "login_lambda_integration" {
  api_id                = aws_apigatewayv2_api.api.id
  integration_type      = "AWS_PROXY"
  integration_uri       = aws_lambda_function.login_lambda.invoke_arn
  integration_method    = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "signup_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /signup"
  target    = "integrations/${aws_apigatewayv2_integration.signup_lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "login_route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /login"
  target    = "integrations/${aws_apigatewayv2_integration.login_lambda_integration.id}"
}

resource "aws_lambda_permission" "allow_signup_invoke" {
  statement_id  = "AllowSignupInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.signup_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_login_invoke" {
  statement_id  = "AllowLoginInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.login_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}
