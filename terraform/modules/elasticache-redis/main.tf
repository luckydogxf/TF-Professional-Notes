resource "aws_elasticache_subnet_group" "this" {
  name        = "${local.env}-${local.app}-redis-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "Subnet group for Redis cluster"
}

resource "aws_elasticache_parameter_group" "this" {
  name        = "${local.env}-${local.app}-redis7-params"
  family      = local.redis_cfg.parameter_group_family
  description = "Custom parameter group for Redis 7.x"

  parameter {
    name  = "maxmemory-policy"
    value = local.redis_cfg.maxmemory_policy
  }
  parameter {
    name  = "cluster-enabled"
    value = "yes"
  }
}


resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${local.env}-${local.app}-redis"
  description          = "Redis cluster (Cluster mode, Multi-AZ)"
  engine               = "redis"
  engine_version       = local.redis_cfg.engine_version
  node_type            = local.redis_cfg.node_type
  port                 = 6379

  automatic_failover_enabled = lookup(local.redis_cfg, "automatic_failover_enabled", true)
  multi_az_enabled           = lookup(local.redis_cfg, "multi_az_enabled", true)

  subnet_group_name = aws_elasticache_subnet_group.this.name

  # 启用传输中和静态加密
  transit_encryption_enabled = lookup(local.redis_cfg, "transit_encryption_enabled", true)
  at_rest_encryption_enabled = lookup(local.redis_cfg, "at_rest_encryption_enabled", true)

  # from S.M output
  auth_token                 = var.transit_encryption_enabled ? var.redis_auth_token : null
  auth_token_update_strategy = var.transit_encryption_enabled ? "ROTATE" : null

  # 完美支持多安全组动态映射
  security_group_ids = [for name in local.sg_names : var.security_group_ids[name]]

  parameter_group_name = aws_elasticache_parameter_group.this.name

  num_node_groups         = local.redis_cfg.num_node_groups
  replicas_per_node_group = local.redis_cfg.replicas_per_node_group

  snapshot_retention_limit = lookup(local.redis_cfg, "snapshot_retention_limit", 0)
  snapshot_window          = lookup(local.redis_cfg, "snapshot_window", null)
  maintenance_window       = lookup(local.redis_cfg, "maintenance_window", null)

  tags = merge(var.tags, { Name = "${local.env}-${local.app}-redis" })
}
