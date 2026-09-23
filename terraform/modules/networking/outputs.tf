output "vpc_ids" { value = { for k, v in module.vpcs : k => v.vpc_id } }
output "subnet_ids_map" {
  value = {
    public      = module.vpcs["primary"].public_subnets
    private_ec2 = module.vpcs["primary"].database_subnets
    private_eks = module.vpcs["primary"].private_subnets
  }
}
