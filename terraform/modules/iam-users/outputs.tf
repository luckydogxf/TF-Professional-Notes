output "user_arns" {
  description = "所有用户的 ARN"
  value       = { for k, v in aws_iam_user.this : k => v.arn }
}

output "group_arns" {
  description = "所有用户组的 ARN"
  value       = { for k, v in aws_iam_group.this : k => v.arn }
}
