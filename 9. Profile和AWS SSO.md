# Profile

```
~/.aws/credentials 内容如下：

...
# 
[ec1.production.xxx]
region = eu-central-1
aws_access_key_id = A...sdskskazl
aws_secret_access_key = NSZTKvln8sdksls.....
aws_session_token = IQoJb3JpZ2luX2VjEE8aDGV1LWNlbnRy.......


locals.xxx.yaml 指定一下即可使用。这个会读取上述的 .aws/xxx文件的值。


#locals.xxx.yaml
ec1.production:
  environment:  production
  region:       eu-central-1
  profile:      ec1.production.xxx
  
以及 

provider "aws" {
  region  = local.env[terraform.workspace].region
  profile = local.env[terraform.workspace].profile
 
}

- local.env[terraform.workspace]：根据当前 Terraform 工作空间（如 dev、prod）动态选择配置。

- profile的值：来自 local.env中对应工作空间的 profile字段（例如 dev工作空间可能对应 dev-profile，prod对应 prod-profile）。
- 
当你指定 profile = "my-profile"时，Terraform 会：

- 读取 ~/.aws/credentials文件，查找 [my-profile]段落下的 aws_access_key_id和 aws_secret_access_key。

- 使用这些信息初始化 AWS SDK，完成认证并访问 AWS 资源。

```

结合AWS SSO 以及自定义脚本可以实现动态产生profile的内容，给TF调用。
