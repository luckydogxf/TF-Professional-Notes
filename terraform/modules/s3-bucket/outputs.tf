output "bucket_ids" {
  description = "Map of S3 bucket IDs"
  value       = { for k, v in aws_s3_bucket.this : k => v.id }
}

output "bucket_arns" {
  description = "Map of S3 bucket ARNs"
  value       = { for k, v in aws_s3_bucket.this : k => v.arn }
}

output "bucket_domain_names" {
  description = "Map of S3 bucket regional domain names"
  value       = { for k, v in aws_s3_bucket.this : k => v.bucket_regional_domain_name }
}
