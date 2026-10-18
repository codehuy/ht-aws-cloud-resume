# --- API ---

resource "aws_apigatewayv2_api" "visitor_count" {
  name          = "visitor-counter-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_credentials = false
    allow_methods     = ["GET"]
    allow_origins     = ["https://huy-tran.com", "https://www.huy-tran.com"]
    max_age           = 0
  }
}

# --- Integration with the Lambda ---

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.visitor_count.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.visitor_count.arn
  payload_format_version = "2.0"
}

# --- Route ---

resource "aws_apigatewayv2_route" "get_count" {
  api_id    = aws_apigatewayv2_api.visitor_count.id
  route_key = "GET /count"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# --- Stage ---

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.visitor_count.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit   = 5
    throttling_rate_limit    = 2
    detailed_metrics_enabled = false
  }
}

# --- Permission for API Gateway to invoke the Lambda ---

resource "aws_lambda_permission" "api" {
  statement_id  = "cbb559ae-8471-575a-95cb-b126adafa1f1"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_count.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_count.execution_arn}/*/*/count"
}

# --- Output ---

output "api_url" {
  value = "${aws_apigatewayv2_api.visitor_count.api_endpoint}/count"
}