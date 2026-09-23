variable "vpc_id" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "sg_config" {
  description = "Parsed security groups YAML configuration object"
  type = map(object({
    description = optional(string)
    ingress_rules = optional(list(object({
      description = optional(string)
      protocol    = string
      from_port   = optional(number)
      to_port     = optional(number)
      cidr_blocks = list(string)
    })))
    egress_rules = optional(list(object({
      description = optional(string)
      protocol    = string
      from_port   = optional(number)
      to_port     = optional(number)
      cidr_blocks = list(string)
    })))
  }))
  default = {}
}
