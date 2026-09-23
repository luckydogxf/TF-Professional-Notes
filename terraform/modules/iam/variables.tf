variable "tags" { type = map(string) }

variable "config" {
  description = "Parsed YAML configuration object for IAM"
  type        = any
}
