## 动态查询 WAF 实例 ID
data "alicloud_wafv3_instances" "this" {
  #ids = ["waf_v2_public_cn-exo4yj6mh02"]
}

## 动态查询证书 ID
data "alicloud_ssl_certificates_service_certificates" "this" {

  name_regex = "^${var.config.waf_cert_name}$"


}


