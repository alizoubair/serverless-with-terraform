resource "aws_iam_role" "greeting_lambda_execution_role" {
  name = "Cloud9-greeting_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_policy" "greeting_lambda_s3_policy" {
  name        = "greeting_lambda_s3_policy"
  description = "Grants access to source and destination buckets"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = ["s3:GetObject"],
        Effect = "Allow",
        Resource = [
          "${var.src_bucket_arn}/*"
        ]
      },
      {
        Action = ["s3:PutObject"],
        Effect = "Allow",
        Resource = [
          "${var.dst_bucket_arn}/*"
        ]
      }
    ]
  })
}

locals {
  policy_arns = [
    aws_iam_policy.greeting_lambda_s3_policy.arn,
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  ]
}

resource "aws_iam_role_policy_attachment" "greeting_lambda_policy_attachments" {
  count      = length(local.policy_arns)
  policy_arn = local.policy_arns[count.index]
  role       = aws_iam_role.greeting_lambda_execution_role.name
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/src"
  output_path = "lambda.zip"
}

resource "aws_lambda_function" "greeting_lambda" {
  function_name = "greeting_lambda"

  handler     = "index.handler"
  runtime     = "nodejs20.x"
  memory_size = var.lambda_memory_size
  role        = aws_iam_role.greeting_lambda_execution_role.arn

  environment {
    variables = {
      SRC_BUCKET = var.src_bucket_id,
      DIST_BUCKET = var.dst_bucket_id
    }
  }

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_iam_policy" "greeting_lambda_sqs_policy" {
  name        = "greeting_lambda_sqs_policy"
  description = "Grant access to red messages from SQS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
        Effect = "Allow",
        Resource = [
          var.greeting_queue_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "greeting_lambda_sqs_policy_attachment" {
  policy_arn = aws_iam_policy.greeting_lambda_sqs_policy.arn
  role       = aws_iam_role.greeting_lambda_execution_role.name
}

resource "aws_lambda_event_source_mapping" "greeting_sqs_mapping" {
  event_source_arn = var.greeting_queue_arn
  function_name    = aws_lambda_function.greeting_lambda.function_name
  batch_size       = 1
  depends_on       = [aws_iam_role_policy_attachment.greeting_lambda_sqs_policy_attachment]
}