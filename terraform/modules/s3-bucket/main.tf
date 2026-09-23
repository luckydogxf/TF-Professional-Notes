resource "aws_s3_bucket" "this" {

  for_each = local.buckets

  bucket        = each.key
  force_destroy = lookup(each.value, "force_destroy", false)
  tags          = var.tags


}

resource "aws_s3_bucket_versioning" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.buckets

  bucket                  = aws_s3_bucket.this[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudfront_access" {
  for_each = {
    for bucket_key, oac_arn in var.cloudfront_oac_arns : bucket_key => oac_arn
    if contains(keys(local.buckets), bucket_key)
  }

  bucket = aws_s3_bucket.this[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipalReadOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.this[each.key].arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = each.value
          }
        }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# S3 Bucket Lifecycle Configuration
# ------------------------------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    # 删除 30 天前的非当前版本
    noncurrent_version_expiration {

      noncurrent_days = try(var.config.s3_bucket.lifecycle_noncurrent_days, 30)
    }

    # 删除过期的 Delete Marker
    expiration {
      expired_object_delete_marker = true
    }
  }
}
