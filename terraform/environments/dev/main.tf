module "common_tags" {
  source      = "../../modules/tags"
  environment = local.config.environment
  application = local.config.application
}

module "networking" {
  source = "../../modules/networking"
  config = local.config
  tags   = module.common_tags.tags
}

module "security_groups" {
  source    = "../../modules/security-groups"
  vpc_id    = module.networking.vpc_ids["primary"]
  sg_config = local.sg_config
  tags      = module.common_tags.tags
}

module "iam" {
  source = "../../modules/iam"
  config = local.config
  tags   = module.common_tags.tags
}

module "eks_cluster" {
  source     = "../../modules/eks-cluster"
  config     = local.config
  vpc_id     = module.networking.vpc_ids["primary"]
  subnet_ids = module.networking.subnet_ids_map["private_eks"]
  #subnet_ids     = module.networking.subnet_ids_map.private_eks
  tags = module.common_tags.tags

  admin_role_arn            = module.iam.role_arns["eks-admin"]
  pod_identity_associations = module.iam.pod_identity_associations
}

module "ec2_instances" {
  source             = "../../modules/ec2-instances"
  config             = local.config
  vpc_id             = module.networking.vpc_ids["primary"]
  subnet_ids_map     = local.subnet_outputs_map
  security_group_ids = module.security_groups.security_group_ids
  tags               = module.common_tags.tags
}

module "secrets_manager" {
  source = "../../modules/secrets-manager"

  environment = local.config.environment
  application = local.config.application

  alicloud_access_keys = module.alicloud_ram.access_keys

  alicloud_oss_region   = module.alicloud_oss.region
  alicloud_oss_endpoint = module.alicloud_oss.endpoint

  tags = module.common_tags.tags
}

module "redis" {
  source             = "../../modules/elasticache-redis"
  config             = local.config
  subnet_ids         = local.subnet_outputs_map[local.config.elasticache.redis.subnet_type]
  security_group_ids = module.security_groups.security_group_ids
  tags               = module.common_tags.tags

  redis_auth_token = module.secrets_manager.redis_auth_token
}

module "aurora_postgresql" {
  source     = "../../modules/aurora-postgresql"
  config     = local.config
  vpc_id     = module.networking.vpc_ids["primary"]
  subnet_ids = module.networking.subnet_ids_map["private_ec2"]
  #security_group_ids = [module.security_groups.security_group_ids["aurora_pg"]]
  security_group_ids = [module.security_groups.security_group_ids[local.config.aurora_postgresql.security_group_key]
  ]
  tags = module.common_tags.tags
}

module "iam_users" {
  source = "../../modules/iam-users"

  #account_id = "318117467297"
  #partition  = "aws-cn"
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  tags = {
    environment = local.config.environment
    application = local.config.application
  }

  groups = local.config.iam_users.groups
  users  = local.config.iam_users.users
}


# ----------------------------------------------

# CloudFront isn't available in China any more.
# We use OSS/WAF/CDN of Alibaba cloud instead for China region.

# ----------------------------------------------

#module "cloudfront" {
#  source = "../../modules/cloudfront"
#  config = local.config
#  tags   = module.common_tags.tags
#}
#
module "s3-bucket" {
  source = "../../modules/s3-bucket"
  config = local.config

  #cloudfront_oac_arns =  module.cloudfront.oac_arns

  tags = module.common_tags.tags

}
#
#module "waf" {
#  source = "../../modules/waf"
#  config = local.config
#  
#  tags   = module.common_tags.tags
#
#}


## --- 1. 阿里云 OSS ---

module "alicloud_ram" {
  source = "../../modules/alicloud-ram"
  config = local.config
  tags   = module.common_tags.tags
}

## --- 1. 阿里云 OSS ---
module "alicloud_oss" {
  source = "../../modules/alicloud-oss"
  config = local.config
  tags   = module.common_tags.tags
}

# 2. 创建 CDN (依赖 OSS 的内网域名)
module "alicloud_cdn" {
  source = "../../modules/alicloud-cdn"
  config = local.config.cdn
  tags   = module.common_tags.tags
  # 传递 OSS 输出
  oss_public_endpoints = module.alicloud_oss.bucket_public_endpoints
}

# 3. 创建 WAF (依赖 CDN 的 CNAME)
module "alicloud_waf" {
  source = "../../modules/alicloud-waf"
  config = local.config.waf
  tags   = module.common_tags.tags

}
