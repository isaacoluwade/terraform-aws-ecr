output "repository_urls" {
  description = "Map of repo key → URL."
  value       = module.ecr.repository_urls
}

output "repository_arns" {
  description = "Map of repo key → ARN."
  value       = module.ecr.repository_arns
}

output "replication_destinations" {
  description = "Map of repo key → list of replication destination regions."
  value       = module.ecr.replication_destinations
}

output "registry_id" {
  description = "AWS account ID hosting the registry."
  value       = module.ecr.registry_id
}
