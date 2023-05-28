data "aws_region" "current" {
}

resource "aws_api_gateway_rest_api" "comment_api" {
  name        = "CommentEndpoint"
  description = "API endpint for comment server"
  body = templatefile("./openapi.yaml", {
    region     = data.aws_region.current.name
    lambda_arn = aws_lambda_function.comment_function.arn
  })
}

resource "aws_api_gateway_deployment" "comment_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.comment_api.id

  triggers = {
    redeployment = sha1(file("./openapi.yaml"))
  }

  stage_name = "prod"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_method_settings" "api_settings" {
  rest_api_id = aws_api_gateway_rest_api.comment_api.id
  stage_name  = aws_api_gateway_deployment.comment_api_deployment.stage_name
  method_path = "*/*"
  settings {
    throttling_burst_limit = 2
    throttling_rate_limit  = 5
  }
}
