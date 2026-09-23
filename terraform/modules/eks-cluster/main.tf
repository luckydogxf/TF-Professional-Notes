module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${var.tags.environment}-${var.tags.application}-cluster"
  kubernetes_version = var.config.eks.cluster_version
  service_ipv4_cidr  = var.config.eks.service_cidr

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # 开启公网与私有访问，并放行外部调用
  endpoint_public_access       = lookup(var.config.eks, "endpoint_public_access", true)
  endpoint_private_access      = lookup(var.config.eks, "endpoint_private_access", false)
  endpoint_public_access_cidrs = lookup(var.config.eks, "endpoint_public_access_cidrs", ["0.0.0.0/0"])

  create_iam_role = true
  iam_role_name   = "${var.tags.environment}-${var.tags.application}-cluster-role"

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose", "system"]
  }
  create_auto_mode_iam_resources = true
  # 当前通过 aws sso login 运行 terraform apply 的终端

  enable_cluster_creator_admin_permissions = true


  addons = {
    vpc-cni = {
      addon_version               = var.config.eks.addon_versions["vpc-cni"]
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    coredns = {
      addon_version               = var.config.eks.addon_versions["coredns"]
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {
      addon_version               = var.config.eks.addon_versions["kube-proxy"]
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    amazon-cloudwatch-observability = {
      addon_version               = var.config.eks.addon_versions["amazon-cloudwatch-observability"]
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    metrics-server = {
      addon_version               = var.config.eks.addon_versions["metrics-server"]
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-state-metrics = {
      addon_version               = var.config.eks.addon_versions["kube-state-metrics"]
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    eks-pod-identity-agent = {
      addon_version               = var.config.eks.addon_versions["eks-pod-identity-agent"]
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }

  access_entries = {
    admin_role = {
      principal_arn = var.admin_role_arn
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws-cn:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_security_group_rule" "node_custom_rules" {
  for_each = lookup(var.config.eks, "custom_security_group_rules", {})

  security_group_id = module.eks.node_security_group_id
  type              = each.value.type
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  cidr_blocks       = each.value.cidr_blocks
  description       = each.value.description
}

resource "aws_eks_pod_identity_association" "this" {
  for_each = var.pod_identity_associations

  cluster_name    = module.eks.cluster_name
  namespace       = each.value.namespace
  service_account = each.value.service_account
  role_arn        = each.value.role_arn
}
