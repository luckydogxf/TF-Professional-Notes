# ──────────────────────────────────────────────
# CloudFront Distribution Outputs
# ──────────────────────────────────────────────

output "distribution_domain_names" {
  description = "Map of CloudFront distribution domain names (e.g., d123.cloudfront.net)"
  value       = { for k, v in aws_cloudfront_distribution.this : k => v.domain_name }
}

output "distribution_arns" {
  description = "Map of CloudFront distribution ARNs"
  value       = { for k, v in aws_cloudfront_distribution.this : k => v.arn }
}

output "distribution_ids" {
  description = "Map of CloudFront distribution IDs (用于 invalidation 等操作)"
  value       = { for k, v in aws_cloudfront_distribution.this : k => v.id }
}

output "distribution_hosted_zone_id" {
  description = "CloudFront 的 Route 53 Hosted Zone ID (用于 alias 记录)"
  value       = { for k, v in aws_cloudfront_distribution.this : k => v.hosted_zone_id }
}


# ──────────────────────────────────────────────
# OAC Outputs
# ──────────────────────────────────────────────

output "oac_ids" {
  description = "Map of CloudFront OAC IDs"
  value       = { for k, v in aws_cloudfront_origin_access_control.this : k => v.id }
}

output "oac_arns" {
  description = "Map of CloudFront OAC ARNs"
  value       = { for k, v in aws_cloudfront_origin_access_control.this : k => v.arn }
}
