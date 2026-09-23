output "cluster_endpoint" {
  description = "The cluster writer endpoint"
  value       = aws_rds_cluster.this.endpoint
}

output "cluster_reader_endpoint" {
  description = "The cluster reader endpoint (load-balanced across read replicas)"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "cluster_id" {
  description = "The RDS Cluster Identifier"
  value       = aws_rds_cluster.this.id
}

output "cluster_arn" {
  description = "The ARN of the Aurora cluster"
  value       = aws_rds_cluster.this.arn
}

output "database_name" {
  description = "The default database name"
  value       = var.config.aurora_postgresql.database_name
}

output "master_username" {
  description = "The master username"
  value       = aws_rds_cluster.this.master_username
}

output "master_user_secret_arn" {
  description = "The ARN of the secret containing the master user password"
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
}
