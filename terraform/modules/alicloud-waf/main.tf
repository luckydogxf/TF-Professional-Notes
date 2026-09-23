# ============================================================
# Alibaba Cloud WAF 3.0
#
# Terraform owns infrastructure only:
#   - WAF domain
#   - TLS
#   - origin/backend
#   - base CC

# Security policies are managed by:
#   waf/waf-rules.sh
#
# ============================================================

resource "alicloud_wafv3_domain" "this" {
  for_each = var.config.waf_domains

  instance_id = local.instance_id
  domain      = each.key
  access_type = "share"

  listen {
    http_ports  = [80]
    https_ports = [443]

    cert_id = local.waf_cert_id

    # Explicit TLS configuration.
    tls_version  = "tlsv1.2"
    cipher_suite = 2
    enable_tlsv3 = false
  }

  redirect {
    # Production should point to the public AWS ALB DNS name.
    backends = [
      each.value.alb_address
    ]

    loadbalance = "iphash"

    connect_timeout = 5
    read_timeout    = 120
    write_timeout   = 120
    # WAF -> ALB shared authentication header.
    request_headers {
      key   = "X-WAF-Auth-Secret"
      value = var.config.waf_alb_shared_secret
    }
    sni_enabled = true

  }
}
# ------------------------------------------------------------
# Global HTTP Flood / CC baseline
# ------------------------------------------------------------

