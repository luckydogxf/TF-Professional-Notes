variable "config" {
  description = "CDN 域名配置"

  type = object({
    cdn_cert_name = string

    cdn_domains = map(object({
      source_type       = string
      source_bucket_key = optional(string)
      aws_alb_domain    = optional(string)
    }))

    referer_whitelist = optional(object({
      domains       = list(string)
      allow_list    = string
      allow_empty   = string
      ignore_scheme = string
    }))
  })
}

variable "oss_public_endpoints" {
  description = "OSS Bucket 名称到外网 Endpoint 的映射"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Common tags"
}
