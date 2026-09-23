locals {

  buckets = lookup(lookup(var.config, "s3", {}), "buckets", {})

}

