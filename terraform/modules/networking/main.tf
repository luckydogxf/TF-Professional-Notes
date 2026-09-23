module "vpcs" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  for_each = var.config.vpcs

  name = "${var.tags.environment}-${var.tags.application}-${each.key}-vpc"
  cidr = each.value.cidr
  azs  = each.value.azs

  public_subnets   = [for s in each.value.subnets.public : s.cidr]
  private_subnets  = [for s in each.value.subnets.private_eks : s.cidr]
  database_subnets = [for s in each.value.subnets.private_ec2 : s.cidr]

  enable_nat_gateway   = each.value.enable_nat_gateway
  single_nat_gateway   = each.value.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = merge(var.tags, {
    Name                     = "${var.tags.environment}-public-subnet"
    "kubernetes.io/role/elb" = 1
  })

  private_subnet_tags = merge(var.tags, {
    Name                              = "${var.tags.environment}-eks-subnet"
    "kubernetes.io/role/internal-elb" = 1
  })

  database_subnet_tags = merge(var.tags, {
    Name = "${var.tags.environment}-ec2-subnet"
  })

  tags = merge(var.tags, { VPCKey = each.key })
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 5.0"

  for_each = var.config.vpcs

  vpc_id = module.vpcs[each.key].vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpcs[each.key].private_route_table_ids
      tags            = { Name = "${var.tags.environment}-${each.key}-s3-endpoint" }
    },
    dynamodb = {
      service         = "dynamodb"
      service_type    = "Gateway"
      route_table_ids = module.vpcs[each.key].private_route_table_ids
      tags            = { Name = "${var.tags.environment}-${each.key}-dynamodb-endpoint" }
    }
  }
}
