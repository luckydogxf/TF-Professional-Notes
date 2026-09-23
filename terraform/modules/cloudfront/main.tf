# ──────────────────────────────────────────────
# 1. OAC (Origin Access Control) - 仅用于 S3 源站
# ──────────────────────────────────────────────
resource "aws_cloudfront_origin_access_control" "this" {
  for_each = {
    for origin_key, origin_val in lookup(var.config, "oac", {}) :
    origin_key => origin_val
  }
  name                              = "${local.env}-${local.app}-${each.key}-oac"
  description                       = lookup(each.value, "description", "OAC for S3 bucket")
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ──────────────────────────────────────────────
# 2. CloudFront Distribution
# ──────────────────────────────────────────────
resource "aws_cloudfront_distribution" "this" {
  for_each = lookup(var.config, "distributions", {})

  enabled             = lookup(each.value, "enabled", true)
  comment             = lookup(each.value, "comment", "Managed by Terraform")
  default_root_object = lookup(each.value, "default_root_object", null)
  aliases             = lookup(each.value, "aliases", [])
  price_class         = lookup(var.config, "price_class", "PriceClass_200")
  web_acl_id          = lookup(var.config, "web_acl_id", null)

  # ─── Origins ───
  dynamic "origin" {
    for_each = lookup(each.value, "origins", [])
    content {
      domain_name = origin.value.type == "s3" ? (
        "${origin.value.bucket_name}.s3.amazonaws.com"
      ) : origin.value.domain_name

      origin_id = origin.value.origin_id

      # S3 源站 → 关联 OAC；Custom 源站 → 不关联
      origin_access_control_id = origin.value.type == "s3" ? (
        aws_cloudfront_origin_access_control.this[origin.value.oac_key].id
      ) : null

      # Custom 源站 → 生成 custom_origin_config 块
      dynamic "custom_origin_config" {
        for_each = origin.value.type == "custom" ? [origin.value] : []
        content {
          http_port                = lookup(custom_origin_config.value, "http_port", 80)
          https_port               = lookup(custom_origin_config.value, "https_port", 443)
          origin_protocol_policy   = lookup(custom_origin_config.value, "origin_protocol_policy", "https-only")
          origin_ssl_protocols     = lookup(custom_origin_config.value, "origin_ssl_protocols", ["TLSv1.2"])
          origin_keepalive_timeout = lookup(custom_origin_config.value, "origin_keepalive_timeout", 5)
          origin_read_timeout      = lookup(custom_origin_config.value, "origin_read_timeout", 30)
        }
      }
    }
  }

  # ─── Default Cache Behavior ───
  default_cache_behavior {
    target_origin_id       = each.value.default_cache_behavior.target_origin_id
    viewer_protocol_policy = lookup(each.value.default_cache_behavior, "viewer_protocol_policy", "redirect-to-https")
    allowed_methods        = lookup(each.value.default_cache_behavior, "allowed_methods", ["GET", "HEAD", "OPTIONS"])
    cached_methods         = lookup(each.value.default_cache_behavior, "cached_methods", ["GET", "HEAD"])

    cache_policy_id            = lookup(each.value.default_cache_behavior, "cache_policy_id", null)
    origin_request_policy_id   = lookup(each.value.default_cache_behavior, "origin_request_policy_id", null)
    response_headers_policy_id = lookup(each.value.default_cache_behavior, "response_headers_policy_id", null)
  }

  # ─── Ordered Cache Behaviors (用于 API 多源站路由) ───
  dynamic "ordered_cache_behavior" {
    for_each = lookup(each.value, "cache_behaviors", [])
    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      target_origin_id       = ordered_cache_behavior.value.target_origin_id
      viewer_protocol_policy = lookup(ordered_cache_behavior.value, "viewer_protocol_policy", "redirect-to-https")
      allowed_methods        = lookup(ordered_cache_behavior.value, "allowed_methods", ["GET", "HEAD", "OPTIONS"])
      cached_methods         = lookup(ordered_cache_behavior.value, "cached_methods", ["GET", "HEAD"])

      cache_policy_id            = lookup(ordered_cache_behavior.value, "cache_policy_id", null)
      origin_request_policy_id   = lookup(ordered_cache_behavior.value, "origin_request_policy_id", null)
      response_headers_policy_id = lookup(ordered_cache_behavior.value, "response_headers_policy_id", null)
    }
  }

  # ─── Custom Error Response (SPA 支持) ───
  dynamic "custom_error_response" {
    for_each = lookup(each.value, "custom_error_response", [])
    content {
      error_code         = custom_error_response.value.error_code
      response_code      = custom_error_response.value.response_code
      response_page_path = custom_error_response.value.response_page_path
    }
  }

  # ─── Logging Config ───
  dynamic "logging_config" {
    for_each = lookup(each.value, "logging_config", null) != null ? [each.value.logging_config] : []
    content {
      bucket          = logging_config.value.bucket
      prefix          = lookup(logging_config.value, "prefix", "")
      include_cookies = lookup(logging_config.value, "include_cookies", false)
    }
  }

  # ─── Viewer Certificate ───
  viewer_certificate {
    acm_certificate_arn      = lookup(var.config, "cert_arn", null)
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # ─── Restrictions ───
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

}
