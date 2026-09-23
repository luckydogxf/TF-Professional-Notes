output "web_acl_id" {
  description = "The ID of the WAF WebACL"
  value       = aws_wafv2_web_acl.main.id
}

output "web_acl_arn" {
  description = "The ARN of the WAF WebACL"
  # fill in cloudfront or K8s Ingress: alb.ingress.kubernetes.io/wafv2-acl-arn
  value = aws_wafv2_web_acl.main.arn
}


