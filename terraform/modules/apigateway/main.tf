data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_api_gateway_rest_api" "greetings_api" {
  name        = "SQSIntegrationAPI"
  description = "API to facilitate SQS messaging via RESTful service"
  body        = file("${path.root}/../api-specs/v1/api-definition.yaml")
}

data "aws_api_gateway_resource" "api_resource" {
  path        = "/greetings"
  rest_api_id = aws_api_gateway_rest_api.greetings_api.id
}

resource "aws_api_gateway_integration" "sqs_integration" {
  rest_api_id             = aws_api_gateway_rest_api.greetings_api.id
  resource_id             = data.aws_api_gateway_resource.api_resource.id
  http_method             = "POST"
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sqs:path/${data.aws_caller_identity.current.account_id}/${var.greeting_queue_name}"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body"
  }

  passthrough_behavior = "WHEN_NO_TEMPLATES"
}

resource "aws_api_gateway_integration_response" "sqs_integration_response" {
  resource_id = data.aws_api_gateway_resource.api_resource.id
  rest_api_id = aws_api_gateway_rest_api.greetings_api.id
  http_method = "POST"
  status_code = "200"

  response_templates = {
    "application/json" = <<EOF
      {
        "messageId": "$inputRoot.SendMessageResponse.SendMessageResult.MessageId
      }
      EOF
  }

  depends_on = [
    aws_api_gateway_integration.sqs_integration
  ]
}

resource "aws_api_gateway_deployment" "greeting_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.greetings_api.id
  stage_name  = "prod"
  depends_on = [
    aws_api_gateway_integration.sqs_integration
  ]
}

resource "aws_iam_role" "api_gateway_sqs_access_role" {
  name = "Cloud9-api_gateway_sqs_access_role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_gateway_policy" {
  role = aws_iam_role.api_gateway_sqs_access_role.id
  policy = jsonencode({
    Version : "2012-10-17",
    Statement = [
      {
        Action   = "sts:SendMessage",
        Resource = "arn:aws:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.greeting_queue_name}"
        Effect   = "Allow",
        Sid      = ""
      }
    ]
  })
}

resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "Cloud9-api_gateway_cloudwatch_role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = "sts:AssumeRole",
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch_policy" {
  role = aws_iam_role.api_gateway_cloudwatch_role.id
  policy = jsonencode({
    Version : "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ],
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"
      },
      {
        Effect = "Allow",
        Action = [
          "xray.PutTraceSegments",
          "xray:PutTelemetryRecords"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_api_gateway_account" "api_gateway_account" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
}

resource "aws_api_gateway_method_settings" "greetings_api_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.greetings_api.id
  stage_name  = aws_api_gateway_deployment.greeting_api_deployment.stage_name
  method_path = "*/*"

  settings {
    logging_level      = "INFO"
    data_trace_enabled = true
    metrics_enabled    = true
  }
  depends_on = [aws_api_gateway_account.api_gateway_account]
}
