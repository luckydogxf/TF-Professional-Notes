variable "config" {
  description = "S3 buckets configuration map"
  type        = any
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "cloudfront_oac_arns" {
  description = "Map of CloudFront OAC ARNs to grant read access to the bucket"
  type        = map(string)
  default     = {}
}

