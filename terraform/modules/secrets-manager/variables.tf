variable "environment" {
  description = "Environment name"
  type        = string
}

variable "application" {
  description = "Application name"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "alicloud_access_keys" {
  description = "Alibaba Cloud RAM AK/SK"
  type = map(object({
    access_key_id     = string
    access_key_secret = string
  }))
  sensitive = true
}


variable "alicloud_oss_endpoint" {
  description = "Alibaba Cloud OSS endpoint "
  type        = string
}


variable "alicloud_oss_region" {
  description = "Alibaba Cloud OSS region"
  type        = string
}
