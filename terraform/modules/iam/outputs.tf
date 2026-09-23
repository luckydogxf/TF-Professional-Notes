output "role_arns" {
  description = "A map of all created IAM role ARNs"
  value       = { for k, r in aws_iam_role.this : k => r.arn }
}


output "pod_identity_associations" {
  description = "Pod Identity associations derived from iam_roles config"
  value = {
    for role_name, role_config in local.iam_roles : role_name => {
      namespace       = lookup(role_config, "namespace", "default")
      service_account = lookup(role_config, "service_account", role_name)
      role_arn        = aws_iam_role.this[role_name].arn
    }
    if lookup(role_config, "type", "") == "pod_identities"
  }
}
