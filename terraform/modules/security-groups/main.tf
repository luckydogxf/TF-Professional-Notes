# ============================================
# 安全组本体 - 纯净，不含任何内联规则
# ============================================

resource "aws_security_group" "this" {

  for_each = var.sg_config

  name        = "${var.tags.environment}-${var.tags.application}-${each.key}-sg"
  description = lookup(each.value, "description", "Managed by Terraform")
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.tags.environment}-${var.tags.application}-${each.key}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================
# 独立入站规则资源（AWS Provider v5+ 最佳实践）
# ============================================

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.ingress_rules_map

  security_group_id = aws_security_group.this[each.value.sg_key].id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = each.value.cidr_ipv4

  tags = {
    Name = each.key
  }
}

# ============================================
# 独立出站规则资源（AWS Provider v5+ 最佳实践）
# ============================================

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = local.egress_rules_map

  security_group_id = aws_security_group.this[each.value.sg_key].id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = each.value.cidr_ipv4

  tags = {
    Name = each.key
  }
}
