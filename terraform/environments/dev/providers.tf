# ──────────────────────────────────────────────
# Terraform & Provider Version Constraints
# ──────────────────────────────────────────────
terraform {

  required_version = "~> 1.16.0"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.59" # 允许 6.59.x ~ 6.x 升级，禁止跳到 7.0
    }

    alicloud = {
      source  = "aliyun/alicloud"
      version = "~> 1.285" # 允许 1.285.x ~ 1.x 升级，禁止跳到 2.0
    }
  }
}

provider "aws" {
  region  = local.config.region
  profile = local.config.profile
}

provider "alicloud" {
  region = local.config.alicloud_region

}
