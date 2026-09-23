variable "config" {
  description = "Environment configuration"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "subnet_ids" {
  description = "EKS private subnets"
}

variable "tags" {
  description = "Common tags"
}

variable "admin_role_arn" {
  type        = string
  description = "allow role ARN to access EKS"
}

variable "pod_identity_associations" {
  description = "Map of EKS Pod Identity associations to create"
  type = map(object({
    namespace       = string
    service_account = string
    role_arn        = string
  }))
  default = {}
}

