locals {
  region_code = format(
    "%s%s",
    substr(replace(var.region, "-", ""), 0, length(replace(var.region, "-", "")) - 1),
    substr(var.region, length(var.region) - 1, 1),
  )

  primary_name = "${var.project}-${var.environment}-${local.region_code}"

  module_version = trimspace(file("${path.module}/VERSION"))

  default_tags = {
    Project       = var.project
    Environment   = var.environment
    Region        = var.region
    ManagedBy     = "terraform"
    Module        = "terraform-aws-ecr"
    ModuleVersion = local.module_version
  }

  tags = merge(var.tags, local.default_tags)

  # Resolve effective repo name: explicit override or derive from key.
  repo_names = {
    for k, r in var.repositories : k => coalesce(r.name, "${local.primary_name}/${k}")
  }

  # Repositories that need a repository policy (either pull or push grants).
  repos_with_policy = {
    for k, r in var.repositories : k => r
    if length(r.cross_account_pull) + length(r.cross_account_push) > 0
  }

  # Repositories with replication targets.
  repos_with_replication = {
    for k, r in var.repositories : k => r.replicate_to
    if length(r.replicate_to) > 0
  }

  # Repositories opting in to Enhanced (Inspector-powered) scanning.
  repos_with_enhanced_scan = {
    for k, r in var.repositories : k => r
    if r.enhanced_scan
  }
}

# --------------------------------------------------------------------------
# Repositories
# --------------------------------------------------------------------------

resource "aws_ecr_repository" "this" {
  for_each = var.repositories

  name                 = local.repo_names[each.key]
  image_tag_mutability = each.value.immutable_tags ? "IMMUTABLE" : "MUTABLE"

  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = merge(local.tags, {
    Name = local.repo_names[each.key]
  })
}

# --------------------------------------------------------------------------
# Lifecycle policies — one per repo, two rules each
# --------------------------------------------------------------------------

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = var.repositories

  repository = aws_ecr_repository.this[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than ${each.value.expire_untagged_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = each.value.expire_untagged_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the most recent ${each.value.expire_old_versions} tagged images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = each.value.expire_old_versions
        }
        action = { type = "expire" }
      },
    ]
  })
}

# --------------------------------------------------------------------------
# Repository policies (cross-account pull/push)
# --------------------------------------------------------------------------

resource "aws_ecr_repository_policy" "this" {
  for_each = local.repos_with_policy

  repository = aws_ecr_repository.this[each.key].name
  policy     = data.aws_iam_policy_document.repo[each.key].json
}

# --------------------------------------------------------------------------
# Enhanced scanning (Inspector-powered) — opt-in, per-repo filter
# --------------------------------------------------------------------------

resource "aws_ecr_registry_scanning_configuration" "this" {
  count = length(local.repos_with_enhanced_scan) > 0 ? 1 : 0

  scan_type = "ENHANCED"

  dynamic "rule" {
    for_each = local.repos_with_enhanced_scan

    content {
      scan_frequency = "CONTINUOUS_SCAN"

      repository_filter {
        filter      = local.repo_names[rule.key]
        filter_type = "WILDCARD"
      }
    }
  }
}

# --------------------------------------------------------------------------
# Cross-region replication — registry-wide, per-repo prefix filter
# --------------------------------------------------------------------------

resource "aws_ecr_replication_configuration" "this" {
  count = length(local.repos_with_replication) > 0 ? 1 : 0

  replication_configuration {
    dynamic "rule" {
      for_each = local.repos_with_replication

      content {
        dynamic "destination" {
          for_each = rule.value

          content {
            region      = destination.value
            registry_id = data.aws_caller_identity.current.account_id
          }
        }

        repository_filter {
          filter      = local.repo_names[rule.key]
          filter_type = "PREFIX_MATCH"
        }
      }
    }
  }
}
