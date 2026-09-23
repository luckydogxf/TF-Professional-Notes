# ============================================
# Redis AUTH Token - Secrets Manager
# ============================================

resource "random_password" "redis_auth" {
  length           = 40
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "redis_auth" {
  name                    = "${var.environment}/${var.application}/redis-auth"
  description             = "Redis AUTH token for ElastiCache"
  recovery_window_in_days = 30

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = random_password.redis_auth.result

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ============================================
# 阿里云 OSS 凭证 - Secrets Manager
# ============================================
# ============================================

resource "aws_secretsmanager_secret" "alicloud_oss" {

  for_each = toset(nonsensitive(keys(var.alicloud_access_keys)))

  # 每个 RAM User 创建独立的 AWS Secrets Manager Secret
  name = "${var.environment}/${var.application}/alicloud-oss-${each.key}"

  description = "Alibaba Cloud OSS credentials for ${each.key}"

  # Secret 删除后立即允许恢复名称
  recovery_window_in_days = 0

  tags = var.tags
}


resource "aws_secretsmanager_secret_version" "alicloud_oss" {
  for_each = toset(nonsensitive(keys(var.alicloud_access_keys)))

  secret_id = aws_secretsmanager_secret.alicloud_oss[
    each.key
  ].id

  secret_string = jsonencode({
    # 当前 RAM User 的 Access Key
    access_key_id = var.alicloud_access_keys[
      each.key
    ].access_key_id

    # 当前 RAM User 的 Access Key Secret
    access_key_secret = var.alicloud_access_keys[
      each.key
    ].access_key_secret

    # OSS 所在区域
    region = var.alicloud_oss_region

    # OSS Endpoint
    endpoint = var.alicloud_oss_endpoint

  })
}
