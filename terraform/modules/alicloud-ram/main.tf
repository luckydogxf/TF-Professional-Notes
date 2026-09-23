resource "alicloud_ram_user" "oss_user" {
  for_each = local.ram_users

  # RAM User 名称来自 YAML
  name = each.value.user_name

  display_name = each.value.display_name
  comments     = each.value.comments
}


resource "alicloud_ram_policy" "oss_user_bucket" {
  for_each = local.user_bucket_permission_map

  # Policy 名称包含 User 和 Bucket，便于识别
  policy_name = "ask-${each.value.user_key}-${each.value.bucket_name}"

  policy_document = jsonencode({
    Version = "1"

    Statement = [
      {
        Effect = "Allow"

        # 权限来自当前 User 下当前 Bucket 的配置
        Action = each.value.permissions

        # 仅允许访问当前 Bucket
        Resource = [
          "acs:oss:*:*:${each.value.bucket_name}",
          "acs:oss:*:*:${each.value.bucket_name}/*"
        ]
      }
    ]
  })

  description = "OSS access policy for ${each.value.user_key}"

  lifecycle {
    # 防止产生空的 User、Bucket 或权限配置
    precondition {
      condition = (
        trimspace(each.value.user_name) != "" &&
        trimspace(each.value.bucket_name) != "" &&
        length(each.value.permissions) > 0
      )

      error_message = "RAM User, Bucket name and permissions must not be empty."
    }
  }
}


resource "alicloud_ram_user_policy_attachment" "oss_user_bucket" {
  for_each = local.user_bucket_permission_map

  # Policy 只关联到它所属的 RAM User
  user_name = alicloud_ram_user.oss_user[
    each.value.user_key
  ].name

  policy_name = alicloud_ram_policy.oss_user_bucket[
    each.key
  ].policy_name

  policy_type = "Custom"
}


resource "alicloud_ram_access_key" "oss_user" {
  for_each = local.ram_users

  # Access Key 属于当前 YAML 中定义的 RAM User
  user_name = alicloud_ram_user.oss_user[
    each.key
  ].name

  status = "Active"
}
