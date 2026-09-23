locals {
  env       = terraform.workspace
  config    = yamldecode(file("../../config/${local.env}.yaml"))
  sg_config = yamldecode(file("../../config/security_groups/${local.env}.yaml"))

  subnet_outputs_map = {

    public      = module.networking.subnet_ids_map.public
    private_ec2 = module.networking.subnet_ids_map.private_ec2
    private_eks = module.networking.subnet_ids_map.private_eks
  }
}
