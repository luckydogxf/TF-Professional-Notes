

resource "aws_iam_instance_profile" "this" {
  for_each = {
    for k, v in var.config.ec2_instances : k => v
    if lookup(v, "iam_role", null) != null
  }
  name = "${var.tags.environment}-${var.tags.application}-${each.value.iam_role}-role"
  role = "${var.tags.environment}-${var.tags.application}-${each.value.iam_role}-role"
}

resource "aws_instance" "nodes" {
  for_each = var.config.ec2_instances

  ami           = data.aws_ami.amazon_linux.id
  instance_type = each.value.instance_type
  subnet_id     = var.subnet_ids_map[each.value.subnet_type][each.value.subnet_index]
  key_name      = lookup(each.value, "key_name", null)

  vpc_security_group_ids = [for sg_name in each.value.security_groups : var.security_group_ids[sg_name]]

  iam_instance_profile = lookup(each.value, "iam_role", null) != null ? aws_iam_instance_profile.this[each.key].name : null

  root_block_device {
    volume_type           = "gp3"
    volume_size           = lookup(each.value, "volume_size", 50)
    delete_on_termination = lookup(each.value, "delete_on_termination", false)
  }

  # 动态绑定 EIP：只有当 YAML 中显式配置了 allocation_id 时才会创建关联
  tags = merge(
    var.tags,
    { Name = "${var.tags.environment}-${var.tags.application}-${each.key}" },
    lookup(each.value, "custom_tags", {})
  )
}

# 动态绑定 EIP：只有当 YAML 中显式配置了 allocation_id 时才会创建关联
resource "aws_eip_association" "this" {
  for_each = {
    for k, v in var.config.ec2_instances : k => v
    if lookup(v, "allocation_id", null) != null
  }

  allocation_id = each.value.allocation_id
  instance_id   = aws_instance.nodes[each.key].id
}
