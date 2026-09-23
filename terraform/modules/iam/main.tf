resource "aws_iam_role" "this" {
  for_each = local.iam_roles
  name     = "${var.tags.environment}-${var.tags.application}-${each.key}-role"

  assume_role_policy = each.value.assume_role_policy_document

  tags = var.tags
}
resource "aws_iam_policy" "custom" {
  for_each = local.custom_policies
  name     = "${var.tags.environment}-${var.tags.application}-${each.key}"
  policy   = each.value.policy_json
  tags     = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = local.role_policy_map

  role       = aws_iam_role.this[each.value.role].name
  policy_arn = each.value.policy_key != null ? aws_iam_policy.custom[each.value.policy_key].arn : each.value.policy_arn
}
