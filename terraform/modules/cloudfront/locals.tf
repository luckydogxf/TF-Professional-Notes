locals {

  env        = lower(var.config.environment)
  app        = var.config.application
  cloudfront = lookup(var.config, "cloudfront", {})
}

