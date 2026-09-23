resource "alicloud_oss_bucket" "this" {
  for_each = lookup(lookup(var.config, "oss_bucket", {}), "buckets", {})

  bucket        = "${lower(var.config.environment)}-${var.config.application}-${each.key}"
  storage_class = "Standard"

  force_destroy = lookup(each.value, "force_destroy", false)

  versioning {
    status = "Enabled"
  }

  server_side_encryption_rule {
    sse_algorithm = "AES256"
  }

  lifecycle_rule {
    id      = "expire-noncurrent-versions"
    enabled = true

    # 非当前版本保留 15 天后过期
    noncurrent_version_expiration {
      days = try(var.config.oss_bucket.lifecycle_noncurrent_days, 15)
    }

    # 删除过期对象删除标记
    expiration {
      expired_object_delete_marker = true
    }
  }

  tags = var.tags
}

resource "alicloud_oss_bucket_acl" "this" {
  for_each = lookup(lookup(var.config, "oss_bucket", {}), "buckets", {})

  bucket = alicloud_oss_bucket.this[each.key].bucket
  acl    = "private"
}


