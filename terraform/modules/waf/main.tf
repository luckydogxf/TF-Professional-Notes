# =============================================================================
# modules/waf/main.tf
# 兼顾中国区 ALB 与海外区 CloudFront 自由切换
# =============================================================================

resource "aws_wafv2_web_acl" "main" {
  name        = local.name
  scope       = local.scope # 🟩 动态 Scope 支持：从 YAML 的 waf.scope 中自动提取
  description = "EKS Cluster WAF Gateway - Managed by Terraform"
  tags        = var.tags

  default_action {
    dynamic "allow" {
      for_each = local.default_action == "ALLOW" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = local.default_action == "BLOCK" ? [1] : []
      content {}
    }
  }

  # ---------------------------------------------------------------------------
  # 1. AWS 官方托管规则组
  # ---------------------------------------------------------------------------
  dynamic "rule" {
    for_each = local.aws_managed_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = try(rule.value.vendor_name, "AWS") # 🟩 落实前文：YAML 缺省时自动使用 AWS 

          dynamic "rule_action_override" {
            for_each = try(rule.value.excluded_rules, [])
            content {
              name = rule_action_override.value
              action_to_use {
                count {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${rule.value.name}Metric"
        sampled_requests_enabled   = true
      }
    }
  }

  # ---------------------------------------------------------------------------
  # 2. 自定义规则（全面兼容 ByteMatch / Size / RateBased 特定 Host&URI 限流）
  # ---------------------------------------------------------------------------
  dynamic "rule" {
    for_each = local.custom_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        dynamic "allow" {
          for_each = rule.value.action == "ALLOW" ? [1] : []
          content {}
        }
        dynamic "block" {
          for_each = rule.value.action == "BLOCK" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = rule.value.action == "COUNT" ? [1] : []
          content {}
        }
      }

      statement {
        # --- 2.1 Byte Match Statement ---
        dynamic "byte_match_statement" {
          for_each = try([rule.value.statement.byte_match_statement], [])
          content {
            positional_constraint = byte_match_statement.value.positional_constraint
            search_string         = byte_match_statement.value.search_string

            field_to_match {
              dynamic "uri_path" {
                for_each = try([byte_match_statement.value.field_to_match.uri_path], [])
                content {}
              }
              dynamic "single_header" {
                for_each = try([byte_match_statement.value.field_to_match.single_header], [])
                content {
                  name = byte_match_statement.value.field_to_match.single_header.name
                }
              }
            }

            dynamic "text_transformation" {
              for_each = try(byte_match_statement.value.text_transformation, [])
              content {
                priority = text_transformation.value.priority
                type     = text_transformation.value.type
              }
            }
          }
        }

        # --- 2.2 Size Constraint Statement ---
        dynamic "size_constraint_statement" {
          for_each = try([rule.value.statement.size_constraint_statement], [])
          content {
            comparison_operator = size_constraint_statement.value.comparison_operator
            size                = size_constraint_statement.value.size

            field_to_match {
              dynamic "single_header" {
                for_each = try([size_constraint_statement.value.field_to_match.single_header], [])
                content {
                  name = size_constraint_statement.value.field_to_match.single_header.name
                }
              }
            }

            dynamic "text_transformation" {
              for_each = try(size_constraint_statement.value.text_transformation, [])
              content {
                priority = text_transformation.value.priority
                type     = text_transformation.value.type
              }
            }
          }
        }

        # --- 2.3 Not Statement ---
        dynamic "not_statement" {
          for_each = try([rule.value.statement.not_statement], [])
          content {
            statement {
              dynamic "geo_match_statement" {
                for_each = try([not_statement.value.statement.geo_match_statement], [])
                content {
                  country_codes = geo_match_statement.value.country_codes
                }
              }
            }
          }
        }

        # --- 2.4 Rate Based Statement (核心修复：全量支持 URI 路径与 Host 标头多维限流) ---
        dynamic "rate_based_statement" {
          for_each = try([rule.value.statement.rate_based_statement], [])
          content {
            limit              = rate_based_statement.value.limit
            aggregate_key_type = rate_based_statement.value.aggregate_key_type

            # 🟩 完美向下适配：全面支持 URI 或 Header 过滤
            dynamic "scope_down_statement" {
              for_each = try([rate_based_statement.value.scope_down_statement], [])
              content {
                dynamic "byte_match_statement" {
                  for_each = try([scope_down_statement.value.byte_match_statement], [])
                  content {
                    positional_constraint = byte_match_statement.value.positional_constraint
                    search_string         = byte_match_statement.value.search_string

                    field_to_match {
                      # 路径级过滤分支（如 /api/v1/auth/）
                      dynamic "uri_path" {
                        for_each = try([byte_match_statement.value.field_to_match.uri_path], [])
                        content {}
                      }
                      dynamic "single_header" {
                        for_each = try([byte_match_statement.value.field_to_match.single_header], [])
                        content {
                          name = byte_match_statement.value.field_to_match.single_header.name
                        }
                      }
                    }

                    dynamic "text_transformation" {
                      for_each = try(byte_match_statement.value.text_transformation, [])
                      content {
                        priority = text_transformation.value.priority
                        type     = text_transformation.value.type
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${rule.value.name}Metric"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name}Metric"
    sampled_requests_enabled   = true
  }
}

