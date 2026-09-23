output "redis_auth_token" {
  description = "The Redis auth token string"
  value       = aws_secretsmanager_secret_version.redis_auth.secret_string
  sensitive   = true # 关键：标记为敏感信息，防止在日志中明文显示
}

output "redis_auth_secret_arn" {
  description = "ARN of Redis AUTH token Secrets Manager"
  value       = aws_secretsmanager_secret.redis_auth.arn
}

output "redis_auth_secret_name" {
  description = "Name of Redis AUTH token Secrets Manager"
  value       = aws_secretsmanager_secret.redis_auth.name
}

output "alicloud_oss_secret_arn" {
  description = "Alibaba Cloud OSS Secrets Manager ARNs by uploader"

  value = {
    for name, secret in aws_secretsmanager_secret.alicloud_oss :
    name => secret.arn
  }
}

output "alicloud_oss_secret_name" {
  description = "Alibaba Cloud OSS Secrets Manager names by uploader"

  value = {
    for name, secret in aws_secretsmanager_secret.alicloud_oss :
    name => secret.name
  }
}
