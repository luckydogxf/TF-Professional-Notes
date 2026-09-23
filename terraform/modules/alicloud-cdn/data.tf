data "alicloud_ssl_certificates_service_certificates" "this" {

  name_regex = "^${var.config.cdn_cert_name}$"
}
