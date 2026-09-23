# ============================================
# 1. IAM 用户组
# ============================================
resource "aws_iam_group" "this" {
  for_each = var.groups
  name     = each.key
}

# ============================================
# 2. 组策略挂载（key 只用 group + 序号，避免依赖未知 ARN）
# ============================================
resource "aws_iam_group_policy_attachment" "this" {
  for_each = {
    for pair in flatten([
      for group_key, group_val in var.groups : [
        for idx, policy_arn in group_val.policy_arns : {
          key        = "${group_key}-${idx}"
          group_name = group_key
          policy_arn = policy_arn
        }
      ]
    ]) : pair.key => pair
  }

  group      = each.value.group_name
  policy_arn = each.value.policy_arn
}

# ============================================
# 3. IAM 用户
# ============================================
resource "aws_iam_user" "this" {
  for_each = var.users

  name          = each.key
  force_destroy = false

  tags = var.tags
}

# ============================================
# 4. 用户加入组
# ============================================
resource "aws_iam_user_group_membership" "this" {
  for_each = var.users

  user   = each.key
  groups = [for g in each.value.group_names : aws_iam_group.this[g].name]

  depends_on = [aws_iam_user.this]
}
