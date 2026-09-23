variable "config" {
  description = "Aurora PostgreSQL specific configuration from the main config file"
  type        = any
}

variable "vpc_id" {
  description = "VPC ID where the Aurora cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group (must span at least 2 AZs)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to associate with the cluster"
  type        = list(string)
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
