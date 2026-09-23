variable "environment" { type = string }
variable "application" { type = string }
variable "extra_tags" {
  type    = map(string)
  default = {}
}
