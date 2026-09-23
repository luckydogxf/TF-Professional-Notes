locals {
  # 读取 YAML 中的 RAM 配置
  ram_config = lookup(var.config, "alicloud_ram", {})

  # RAM User 配置
  ram_users = lookup(local.ram_config, "users", {})

  # 展开 User 下的 Bucket 和权限
  user_bucket_permissions = flatten([
    for user_key, user in local.ram_users : [
      for bucket in user.buckets : {
        user_key    = user_key
        user_name   = user.user_name
        bucket_name = bucket.name
        permissions = bucket.permissions
      }
    ]
  ])

  # 每个 User + Bucket 生成一个稳定的资源 key
  user_bucket_permission_map = {
    for item in local.user_bucket_permissions :
    "${item.user_key}-${item.bucket_name}" => item
  }
}
