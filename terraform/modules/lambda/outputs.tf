output "lambda_function_arn" {
  value       = aws_lambda_function.greeting_lambda.arn
  description = "The ARN of the Lambda function"
}