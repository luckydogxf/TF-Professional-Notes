variable "config" {
  type = object({
    instance_name_regex   = string
    waf_alb_shared_secret = string
    waf_cert_name         = string

    waf_domains = map(object({
      alb_address = string
    }))
  })
}

variable "tags" {
  description = "Common tags"
  type        = any
}

variable "cert_region" {
  description = "证书所在地域"
  type        = string
  default     = "cn-hangzhou"
}
