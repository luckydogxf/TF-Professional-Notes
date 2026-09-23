module "common_tags" {
  source      = "../../modules/tags"
  environment = local.config.environment
  application = local.config.application
}

module "waf" {
  source = "../../modules/waf"
  config = local.config
  tags   = module.common_tags.tags

  providers = {
    aws = aws.us_east_1 #  关键：强制让这个模块在美东一区实例化
  }
}

# 3. 调用 CloudFront 模块（传入 WAF 算出来的真实 ARN）
module "cloudfront" {
  source = "../../modules/cloudfront"
  tags   = module.common_tags.tags

  #  关键：将当前 config 深度组装，把 waf 模块算出的 arn 动态塞进去
  config = merge(local.config, {
    web_acl_id = module.waf.web_acl_arn
  })
}

# 4. 调用 S3 存储桶模块（传入 CloudFront 算出来的真实 OAC ARN 建立闭环）
module "s3_bucket" {
  source = "../../modules/s3-bucket"
  config = local.config
  tags   = module.common_tags.tags

  #  关键：将 CloudFront 算出来的 OAC 真实 ARNs 传给 S3，用于渲染 Bucket Policy 隔离直接访问
  cloudfront_oac_arns = module.cloudfront.oac_arns
}

