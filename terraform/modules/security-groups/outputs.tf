output "security_group_ids" {
  description = "Map of security group IDs (alias for compatibility)"
  value = {
    for k, v in aws_security_group.this : k => v.id
  }
}

output "security_group_arns" {
  description = "Map of security group ARNs"
  value = {
    for k, v in aws_security_group.this : k => v.arn
  }
}
