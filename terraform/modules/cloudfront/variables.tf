variable "config" {
  description = "CloudFront and OAC configuration map"
  type        = any
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
}
