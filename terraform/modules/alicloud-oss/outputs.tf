output "region" {
  description = "Alibaba Cloud OSS region"

  # OSS Region 位于 oss_bucket.region
  value = var.config.oss_bucket.region
}

output "endpoint" {
  description = "Alibaba Cloud OSS endpoint"

  # 根据 OSS Region 生成访问端点
  value = "oss-${var.config.oss_bucket.region}.aliyuncs.com"
}
output "bucket_names" {
  description = "Alibaba Cloud OSS bucket names"

  value = {
    for k, v in alicloud_oss_bucket.this : k => v.bucket
  }
}

output "bucket_public_endpoints" {
  value = { for k, v in alicloud_oss_bucket.this : k => "${v.bucket}.${v.extranet_endpoint}" }

}
