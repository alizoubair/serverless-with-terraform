output "source_bucket_id" {
  value       = module.storage.src_bucket_id
  description = "ID of the source bucket created by the storage module"
}

output "destination_bucket_id" {
  value       = module.storage.dst_bucket_id
  description = "ID of the destination bucket created by the storage module"
}

output "lambda_function_arn" {
  value       = module.lambda.lambda_function_arn
  description = "The ARN of the Lambda function"
}

output "api_gateway_url" {
  value       = module.apigateway.greeting_api_endpoint
  description = "URL for API Gateway"
}