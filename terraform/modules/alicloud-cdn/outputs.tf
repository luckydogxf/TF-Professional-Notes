output "cname" {
  value = { for k, v in alicloud_cdn_domain_new.this : k => v.cname }
}
