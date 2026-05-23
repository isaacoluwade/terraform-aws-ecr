output "repository_urls" {
  description = "Map of repo key → URL. The 'app' value is what CI pushes to."
  value       = module.ecr.repository_urls
}

output "repository_arns" {
  description = "Map of repo key → ARN."
  value       = module.ecr.repository_arns
}

output "push_command" {
  description = "Copy-paste-able commands to push an image to the 'app' repo."
  value       = <<-EOT
    aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${module.ecr.repository_urls["app"]}
    docker tag <local-image> ${module.ecr.repository_urls["app"]}:v1
    docker push ${module.ecr.repository_urls["app"]}:v1
  EOT
}
