locals {

  instance_id = data.alicloud_wafv3_instances.this.ids.0

  waf_cert_id = join("-",[data.alicloud_ssl_certificates_service_certificates.this.certificates[0].id,var.cert_region])

  waf_domain_ids = toset([
    for d in alicloud_wafv3_domain.this : tostring(d.domain_id)
  ])

}

