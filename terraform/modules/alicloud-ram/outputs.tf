output "access_keys" {
  description = "Alibaba Cloud RAM Access Keys by user"

  value = {
    for name, key in alicloud_ram_access_key.oss_user :
    name => {
      access_key_id     = key.id
      access_key_secret = key.secret
    }
  }

  sensitive = true
}


output "user_name" {
  description = "Alibaba Cloud RAM user names"

  value = {
    for name, user in alicloud_ram_user.oss_user :
    name => user.name
  }
}



output "policy_name" {
  description = "Alibaba Cloud RAM policy names by user and bucket"

  value = {
    for name, policy in alicloud_ram_policy.oss_user_bucket :
    name => policy.policy_name
  }
}

