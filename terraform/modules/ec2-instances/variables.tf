variable "config" { description = "Environment configuration" }
variable "vpc_id" { description = "VPC ID" }
variable "tags" { description = "Common tags" }

variable "security_group_ids" {
  description = "Map of security group IDs"
  type        = map(string)
}


variable "subnet_ids_map" {
  description = "Map of all subnet lists by type"
  type        = any
}

variable "ami_id" {

  type    = string
  default = "ami-040b6fd89b7a234a3"

}
