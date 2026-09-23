locals {
  redis_cfg = var.config.elasticache.redis
  env       = lower(var.config.environment)
  app       = var.config.application

  # 核心：从 YAML 读取安全组名称列表，未配置则默认回退到 ["redis"]
  sg_names = local.redis_cfg.security_groups

}

