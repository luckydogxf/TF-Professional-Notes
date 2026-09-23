variable "config" {
  description = "Entire environment config object loaded from YAML"
  type        = any
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
