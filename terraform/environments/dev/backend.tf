terraform {
  backend "s3" {
    bucket               = "aiasksport-tfstate-cn"
    region               = "cn-northwest-1"
    key                  = "terraform.tfstate"
    workspace_key_prefix = ""
    use_lockfile         = true
    encrypt              = true
    profile              = "dev"
  }
}

