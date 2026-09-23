provider "aws" {
  region = "ap-northeast-1" # 假设海外核心资源（EKS/ALB/S3）部署在东京
}

provider "aws" {
  alias  = "us_east_1" # 必须显式声明美东一别名，专供 CloudFront WAF
  region = "us-east-1"
}
