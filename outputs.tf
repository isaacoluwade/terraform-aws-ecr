output "repository_arns" {
  description = "Map of repo key → ARN. Use for IAM policies scoped to specific repos."
  value       = { for k, r in aws_ecr_repository.this : k => r.arn }
}

output "repository_urls" {
  description = "Map of repo key → repo URL (e.g. <account>.dkr.ecr.us-east-1.amazonaws.com/<repo-name>). What CI pushes to and EKS pulls from."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "repository_names" {
  description = "Map of repo key → resolved ECR repository name. Useful for AWS CLI commands."
  value       = { for k, r in aws_ecr_repository.this : k => r.name }
}

output "registry_id" {
  description = "AWS account ID hosting the registry. For consumers building authentication helpers."
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "Echo of the input region."
  value       = var.region
}

output "replication_destinations" {
  description = "Map of repo key → list of replication destination regions. Empty map when no repos have replicate_to set."
  value       = local.repos_with_replication
}
