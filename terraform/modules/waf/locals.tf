locals {
  waf  = lookup(var.config, "waf", {})
  name = lookup(local.waf, "name", "default-waf")
  # CloudFront 专属的 WAF 必须将 scope 声明为 CLOUDFRONT 才能成功绑定
  scope = lookup(local.waf, "scope", "REGIONAL")

  default_action    = lookup(local.waf, "default_action", "ALLOW")
  aws_managed_rules = lookup(local.waf, "aws_managed_rules", [])
  custom_rules      = lookup(local.waf, "custom_rules", [])
}

