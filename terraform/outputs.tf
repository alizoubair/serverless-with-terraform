output "source_bucket_id" {
  value = module.storage.src_bucket_id
  description = "ID of the source bucket created by the storage module"
}

output "destination_bucket_id" {
  value = module.storage.dst_bucket_id
  description = "ID of the destination bucket created by the storage module"
}