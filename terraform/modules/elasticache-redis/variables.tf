variable "config" { type = any }
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = map(string) } # 接收全局 SG ID 映射表
variable "tags" {
  type    = map(string)
  default = {}
}

variable "redis_auth_token" {
  description = "Auth token for Redis, retrieved from Secrets Manager"
  type        = string
  default     = null
}
variable "transit_encryption_enabled" {
  type    = bool
  default = false
}
