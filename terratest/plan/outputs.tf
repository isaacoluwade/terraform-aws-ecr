output "repository_urls" {
  value = module.ecr.repository_urls
}

output "repository_arns" {
  value = module.ecr.repository_arns
}

output "repository_names" {
  value = module.ecr.repository_names
}

output "registry_id" {
  value = module.ecr.registry_id
}

output "region" {
  value = module.ecr.region
}

output "replication_destinations" {
  value = module.ecr.replication_destinations
}
