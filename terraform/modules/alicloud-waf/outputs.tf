output "waf_instance_id" {
  value = local.instance_id
}

output "waf_cname" {
  value = { for k, v in alicloud_wafv3_domain.this : k => v.cname }
}
