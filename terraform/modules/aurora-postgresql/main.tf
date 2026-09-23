# ──────────────────────────────────────────────
# DB Subnet Group
# ──────────────────────────────────────────────
resource "aws_db_subnet_group" "this" {
  name       = "${local.env}-${local.app}-aurora-pg-subnet"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${local.env}-${local.app}-aurora-pg-subnet"
  })
}

# ──────────────────────────────────────────────
# Cluster Parameter Group
# ──────────────────────────────────────────────
resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${local.env}-${local.app}-aurora-pg-params"
  family      = local.pg_conf.parameter_group.family
  description = "Custom cluster parameter group for ${local.env} Aurora PostgreSQL"

  dynamic "parameter" {
    for_each = local.pg_conf.parameter_group.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", "immediate")
    }
  }

  tags = var.tags
}

# ──────────────────────────────────────────────
# Aurora PostgreSQL Cluster (Multi-AZ, 1 writer + 1 reader)
# ──────────────────────────────────────────────
resource "aws_rds_cluster" "this" {
  cluster_identifier              = "${local.env}-${local.app}-aurora-pg"
  engine                          = "aurora-postgresql"
  engine_mode                     = "provisioned"
  engine_version                  = local.pg_conf.engine_version
  database_name                   = local.pg_conf.database_name
  master_username                 = local.pg_conf.master_username
  manage_master_user_password     = true
  port                            = 5432
  storage_encrypted               = true
  kms_key_id                      = lookup(local.pg_conf, "kms_key_id", null)
  backup_retention_period         = local.pg_conf.backup_retention_period
  preferred_backup_window         = local.pg_conf.preferred_backup_window
  preferred_maintenance_window    = local.pg_conf.preferred_maintenance_window
  deletion_protection             = local.pg_conf.deletion_protection
  skip_final_snapshot             = local.pg_conf.skip_final_snapshot
  final_snapshot_identifier       = local.pg_conf.skip_final_snapshot ? null : "${local.env}-${local.app}-aurora-pg-final"
  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = var.security_group_ids
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name
  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(var.tags, {
    Name = "${local.env}-${local.app}-aurora-pg"
  })
}

# ──────────────────────────────────────────────
# Cluster Instances (1 writer + N readers)
# ──────────────────────────────────────────────
resource "aws_rds_cluster_instance" "this" {
  count                      = local.pg_conf.instance_count
  identifier                 = "${local.env}-${local.app}-aurora-pg-${count.index}"
  cluster_identifier         = aws_rds_cluster.this.id
  instance_class             = local.pg_conf.instance_class
  engine                     = aws_rds_cluster.this.engine
  engine_version             = aws_rds_cluster.this.engine_version
  publicly_accessible        = false
  auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    Name = "${local.env}-${local.app}-aurora-pg-${count.index}"
    Role = count.index == 0 ? "writer" : "reader"
  })
}
