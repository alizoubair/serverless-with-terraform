resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
  number  = true
}

module "storage" {
  source          = "./modules/storage"
  src_bucket_name = "src-bucket-${random_string.bucket_suffix.result}"
  dst_bucket_name = "dst-bucket-${random_string.bucket_suffix.result}"
}

module "lambda" {
  source             = "./modules/lambda"
  depends_on         = [module.storage]
  src_bucket_arn     = module.storage.src_bucket_arn
  src_bucket_id      = module.storage.src_bucket_id
  dst_bucket_arn     = module.storage.dst_bucket_arn
  dst_bucket_id      = module.storage.dst_bucket_id
  lambda_memory_size = var.lambda_memory_size
  greeting_queue_arn = module.sqs.greeting_queue_arn
}

module "sqs" {
  source = "./modules/sqs"
}

module "apigateway" {
  source              = "./modules/apigateway"
  depends_on          = [module.sqs]
  greeting_queue_name = module.sqs.greeting_queue_name
  greeting_queue_arn  = module.sqs.greeting_queue_arn
}