variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "partition" {
  description = "AWS Partition (aws or aws-cn)"
  type        = string
  default     = "aws-cn"
}

variable "users" {
  description = "IAM 用户配置，key 为用户名"
  type = map(object({
    group_names = list(string)
  }))
  default = {}
}

variable "groups" {
  description = "IAM 用户组配置，key 为组名"
  type = map(object({
    policy_arns = list(string)
  }))
  default = {}
}

variable "tags" {
  description = "通用标签"
  type        = map(string)
  default     = {}
}
