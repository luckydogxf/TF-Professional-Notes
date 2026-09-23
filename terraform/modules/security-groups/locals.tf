# ============================================
# 从独立 YAML 文件读取安全组配置
# 第一步：展开每条规则的 cidr_blocks 为列表
# 将每个 SG 的每条规则拆成 [rule, cidr_list] 的扁平列表
# ============================================

locals {
  ingress_rules_expanded = flatten([
    for sg_key, sg_config in var.sg_config : [
      for rule_idx, rule in lookup(sg_config, "ingress_rules", []) : [
        for cidr_idx, cidr in rule.cidr_blocks : {
          sg_key      = sg_key
          rule_key    = "${sg_key}-ingress-${rule_idx}-${cidr_idx}"
          description = lookup(rule, "description", "Ingress rule")
          from_port   = rule.protocol == "-1" ? null : lookup(rule, "from_port", null)
          to_port     = rule.protocol == "-1" ? null : lookup(rule, "to_port", null)
          protocol    = rule.protocol
          cidr_ipv4   = cidr
        }
      ]
    ]
  ])

  egress_rules_expanded = flatten([
    for sg_key, sg_config in var.sg_config : [
      for rule_idx, rule in lookup(sg_config, "egress_rules", []) : [
        for cidr_idx, cidr in rule.cidr_blocks : {
          sg_key      = sg_key
          rule_key    = "${sg_key}-egress-${rule_idx}-${cidr_idx}"
          description = lookup(rule, "description", "Egress rule")
          from_port   = rule.protocol == "-1" ? null : lookup(rule, "from_port", null)
          to_port     = rule.protocol == "-1" ? null : lookup(rule, "to_port", null)
          protocol    = rule.protocol
          cidr_ipv4   = cidr
        }
      ]
    ]
  ])
}

# ============================================
# 第二步：将扁平列表转为 map，用于 for_each
# ============================================

locals {
  ingress_rules_map = {
    for item in local.ingress_rules_expanded : item.rule_key => item
  }

  egress_rules_map = {
    for item in local.egress_rules_expanded : item.rule_key => item
  }
}
