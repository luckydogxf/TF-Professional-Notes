locals {

  # CDN 需要纯数字 CertificateId，从 certificate_id 提取
  cdn_cert_id = data.alicloud_ssl_certificates_service_certificates.this.certificates[0].id

  referer_whitelist_config = try(var.config.referer_whitelist, null)

}


