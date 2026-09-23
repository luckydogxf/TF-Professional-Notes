locals {
  sso_admin_arns = data.aws_iam_roles.sso_admin.arns

  generated_eks_admin_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = local.sso_admin_arns
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  raw_iam_roles = lookup(var.config, "iam_roles", {})

  iam_roles = {
    for k, v in local.raw_iam_roles : k => merge(v, {
      assume_role_policy_document = lookup(v, "assume_role_policy_document", "") == "__DYNAMIC_SSO_ADMIN_POLICY__" ? local.generated_eks_admin_policy : lookup(v, "assume_role_policy_document", "")
    })
  }

  iam_policies    = lookup(var.config, "iam_policies", {})
  custom_policies = { for k, v in local.iam_policies : k => v if can(v.policy_json) }

  role_policy_attachments = flatten([
    for role_name, role_config in local.iam_roles : concat(
      [
        for pk in lookup(role_config, "policy_keys", []) : {
          key = "${role_name}___${pk}", role = role_name, policy_key = pk, policy_arn = null
        }
      ],
      [
        for pa in lookup(role_config, "policy_arns", []) : {
          key = "${role_name}___${pa}", role = role_name, policy_key = null, policy_arn = pa
        }
      ]
    )
  ])
  role_policy_map = { for item in local.role_policy_attachments : item.key => item }
}

