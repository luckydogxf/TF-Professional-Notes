output "tags" {
  value = merge({
    environment = lower(var.environment)
    application = lower(var.application)
    managed_by  = "terraform"
  }, var.extra_tags)
}
