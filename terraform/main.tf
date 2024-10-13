resource "random_string" "bucket_suffix" {
  length = 8
  special = false
  upper = false
  number = true
}

module "storage" {
  source = "./modules/storage"
  src_bucket_name = "src-bucket-${random_string.bucket_suffix.result}"
  dst_bucket_name = "dst-bucket${random_string.bucket_suffix.result}"
}