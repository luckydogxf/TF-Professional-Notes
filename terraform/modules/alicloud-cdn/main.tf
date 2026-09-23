# ===== CDN 加速域名 =====
resource "alicloud_cdn_domain_new" "this" {
  for_each = var.config.cdn_domains

  domain_name = each.key
  cdn_type    = "web"
  scope       = "domestic"

  sources {
    type     = each.value.source_type == "aws_alb" ? "domain" : "oss"
    content  = each.value.source_type == "aws_alb" ? each.value.aws_alb_domain : var.oss_public_endpoints[each.value.source_bucket_key]
    priority = "20"
    port     = 80
    weight   = "15"
  }

  certificate_config {

    server_certificate_status = "on"
    cert_type                 = "cas"
    # CDN 需要的是纯数字 CertificateId，从 cert_identifier 提取
    cert_id     = local.cdn_cert_id
    cert_region = "cn-hangzhou"

  }


}

# ===== 注入自定义回源标头 (X-CDN-Secret-Token) → 给 AWS ALB 校验用 =====
#resource "alicloud_cdn_domain_config" "header_config" {
#  for_each = var.config.cdn_domains
#
#  domain_name   = alicloud_cdn_domain_new.this[each.key].domain_name
#  function_name = "origin_request_header"
#
#  function_args {
#    arg_name  = "header_operation_type"
#    arg_value = "add"
#  }
#
#  function_args {
#    arg_name  = "header_name"
#    arg_value = "X-CDN-Secret-Token"
#  }
#
#  function_args {
#    arg_name  = "header_value"
#    arg_value = "K7gNU3sdo+OLqOkNhv4qCFX8eHZbV3yTm9pWjR5cA1s"
#  }
#
#  function_args {
#    arg_name  = "duplicate"
#    arg_value = "off"
#  }
#}

# ===== 开启 OSS 私有 Bucket 回源 → 仅对 source_type = "oss" 的域名生效 =====

resource "alicloud_cdn_domain_config" "private_oss" {
  for_each = {
    for k, v in var.config.cdn_domains :
    k => v
    if v.source_type == "oss"
  }

  domain_name = alicloud_cdn_domain_new.this[each.key].domain_name

  function_name = "l2_oss_key"

  function_args {
    arg_name  = "private_oss_auth"
    arg_value = "on"
  }
}

# oss-cdn auth
resource "alicloud_cdn_domain_config" "oss_auth" {
  for_each = {
    for k, v in var.config.cdn_domains :
    k => v
    if v.source_type == "oss"
  }

  domain_name   = alicloud_cdn_domain_new.this[each.key].domain_name
  function_name = "oss_auth"

  function_args {
    arg_name  = "oss_bucket_id"
    arg_value = var.oss_public_endpoints[each.value.source_bucket_key]
  }
}

# ===== OSS 回源 Host Header =====

resource "alicloud_cdn_domain_config" "set_req_host_header" {
  for_each = {
    for k, v in var.config.cdn_domains :
    k => v
    if v.source_type == "oss"
  }

  domain_name   = alicloud_cdn_domain_new.this[each.key].domain_name
  function_name = "set_req_host_header"

  function_args {
    arg_name  = "domain_name"
    arg_value = var.oss_public_endpoints[each.value.source_bucket_key]
  }
}

resource "alicloud_cdn_domain_config" "homepage_redirect" {
  for_each = {
    for k, v in var.config.cdn_domains :
    k => v
    if v.source_type == "oss"
  }

  domain_name   = alicloud_cdn_domain_new.this[each.key].domain_name
  function_name = "host_redirect"

  function_args {
    arg_name  = "regex"
    arg_value = "^/$"
  }

  function_args {
    arg_name  = "replacement"
    arg_value = "/index.html"
  }

  function_args {
    arg_name  = "flag"
    arg_value = "break"
  }

  function_args {
    arg_name  = "sequence"
    arg_value = "1"
  }
}

# We don't cache `index.html`
# so index.html TTL=0

resource "alicloud_cdn_domain_config" "cache_html" {
  for_each = {
    for k, v in var.config.cdn_domains :
    k => v
    if v.source_type == "oss"
  }

  domain_name   = alicloud_cdn_domain_new.this[each.key].domain_name
  function_name = "filetype_based_ttl_set"

  function_args {
    arg_name  = "file_type"
    arg_value = "html"
  }

  function_args {
    arg_name  = "ttl"
    arg_value = "0"
  }

  function_args {
    arg_name  = "weight"
    arg_value = "90"
  }

  function_args {
    arg_name  = "swift_origin_cache_high"
    arg_value = "off"
  }

  function_args {
    arg_name  = "swift_no_cache_low"
    arg_value = "off"
  }

  function_args {
    arg_name  = "swift_follow_cachetime"
    arg_value = "on"
  }

  function_args {
    arg_name  = "force_revalidate"
    arg_value = "off"
  }
}

# assets/* TTL = 1 day

resource "alicloud_cdn_domain_config" "cache_assets" {
  for_each = {
    for k, v in var.config.cdn_domains :
    k => v
    if v.source_type == "oss"
  }

  domain_name   = alicloud_cdn_domain_new.this[each.key].domain_name
  function_name = "path_based_ttl_set"

  function_args {
    arg_name  = "path"
    arg_value = "/assets"
  }

  function_args {
    arg_name  = "weight"
    arg_value = "1"
  }

  function_args {
    arg_name  = "ttl"
    arg_value = "86400"
  }

  function_args {
    arg_name  = "swift_origin_cache_high"
    arg_value = "off"
  }

  function_args {
    arg_name  = "swift_no_cache_low"
    arg_value = "off"
  }

  function_args {
    arg_name  = "swift_follow_cachetime"
    arg_value = "on"
  }

  function_args {
    arg_name  = "force_revalidate"
    arg_value = "off"
  }
}

# Team/player, TTL =30 day
resource "alicloud_cdn_domain_config" "image_cache" {
  for_each = {
    for k, v in var.config.cdn_domains : k => v
    if v.source_type == "oss"
  }

  domain_name   = alicloud_cdn_domain_new.this[each.key].domain_name
  function_name = "filetype_based_ttl_set"

  function_args {
    arg_name  = "ttl"
    arg_value = "2592000"  # 30 days
  }

  function_args {
    arg_name  = "file_type"
    arg_value = "jpg,jpeg,png,webp,gif,svg,ico"

  }

  function_args {
    arg_name  = "weight"
    arg_value = "10"
  }
}

# ===== 开启 Gzip 压缩 =====
# 适用于 H5 静态资源：HTML、JS、CSS、JSON、SVG 等
resource "alicloud_cdn_domain_config" "gzip" {
  for_each = {
    for k, v in var.config.cdn_domains : k => v
    if v.source_type == "oss"
  }

  domain_name   = alicloud_cdn_domain_new.this[each.key].domain_name
  function_name = "gzip"

  function_args {
    arg_name  = "enable"
    arg_value = "on"
  }
}


# ===== 开启 Brotli 压缩 =====
# 支持 Brotli 的移动端浏览器优先使用 Brotli
resource "alicloud_cdn_domain_config" "brotli" {
  for_each = {
    for k, v in var.config.cdn_domains : k => v
    if v.source_type == "oss"
  }

  domain_name   = alicloud_cdn_domain_new.this[each.key].domain_name
  function_name = "brotli"

  function_args {
    arg_name  = "enable"
    arg_value = "on"
  }
}

# ========= 后端 防盗链  =========
resource "alicloud_cdn_domain_config" "referer_whitelist" {
  for_each = local.referer_whitelist_config == null ? {} : {
    for domain in local.referer_whitelist_config.domains :
    domain => domain
  }

  domain_name   = alicloud_cdn_domain_new.this[each.key].domain_name
  function_name = "referer_white_list_set"

  function_args {
    arg_name  = "refer_domain_allow_list"
    arg_value = local.referer_whitelist_config.allow_list
  }

  function_args {
    arg_name  = "allow_empty"
    arg_value = local.referer_whitelist_config.allow_empty
  }

  function_args {
    arg_name  = "ignore_scheme"
    arg_value = local.referer_whitelist_config.ignore_scheme
  }
}

# HTTP/2 + OCSP Stapling
resource "alicloud_cdn_domain_config" "https_option" {
  for_each = var.config.cdn_domains

  domain_name   = alicloud_cdn_domain_new.this[each.key].domain_name
  function_name = "https_option"

  # 开启 HTTP/2
  function_args {
    arg_name  = "http2"
    arg_value = "on"
  }

  # 开启 OCSP Stapling
  function_args {
    arg_name  = "ocsp_stapling"
    arg_value = "on"
  }
}

# ===== TLS 协议版本 =====
# 仅保留 TLS 1.2 / 1.3
resource "alicloud_cdn_domain_config" "https_tls_version" {
  for_each = var.config.cdn_domains

  domain_name   = alicloud_cdn_domain_new.this[each.key].domain_name
  function_name = "https_tls_version"

  # TLS 1.0：关闭
  function_args {
    arg_name  = "tls10"
    arg_value = "off"
  }

  # TLS 1.1：关闭
  function_args {
    arg_name  = "tls11"
    arg_value = "off"
  }

  # TLS 1.2：开启
  function_args {
    arg_name  = "tls12"
    arg_value = "on"
  }

  # TLS 1.3：开启
  function_args {
    arg_name  = "tls13"
    arg_value = "on"
  }

  function_args {
    arg_name  = "ciphersuitegroup"
    arg_value = "all"
  }
}
