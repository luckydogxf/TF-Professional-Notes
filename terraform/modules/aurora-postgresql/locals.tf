locals {
  env     = lower(var.config.environment)
  app     = var.config.application
  pg_conf = var.config.aurora_postgresql
}

