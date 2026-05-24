locals {
  # S-1 fix: explicit region→short-code map (no derivation tricks).
  # Adding a new region = adding a line here.
  region_code_map = {
    "us-east-1"      = "use1"
    "us-east-2"      = "use2"
    "us-west-1"      = "usw1"
    "us-west-2"      = "usw2"
    "eu-west-1"      = "euw1"
    "eu-west-2"      = "euw2"
    "eu-west-3"      = "euw3"
    "eu-central-1"   = "euc1"
    "eu-north-1"     = "eun1"
    "eu-south-1"     = "eus1"
    "ap-southeast-1" = "apse1"
    "ap-southeast-2" = "apse2"
    "ap-northeast-1" = "apne1"
    "ap-northeast-2" = "apne2"
    "ap-northeast-3" = "apne3"
    "ap-south-1"     = "aps1"
    "ap-east-1"      = "ape1"
    "ca-central-1"   = "cac1"
    "ca-west-1"      = "caw1"
    "sa-east-1"      = "sae1"
    "me-south-1"     = "mes1"
    "me-central-1"   = "mec1"
    "af-south-1"     = "afs1"
  }
  region_code = local.region_code_map[var.region]

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
  # EC-C2: explicit ownership flag prevents two module instances in the same
  # account+region from silently overwriting each other's scanning config.
  count = var.manage_registry_scanning && length(local.repos_with_enhanced_scan) > 0 ? 1 : 0

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

# EC-C2 guard: surface a plan-time error if any repo opts into enhanced_scan
# without this module instance owning the registry-wide writer.
check "enhanced_scan_requires_registry_ownership" {
  assert {
    condition     = var.manage_registry_scanning || length(local.repos_with_enhanced_scan) == 0
    error_message = "One or more repositories set enhanced_scan = true, but manage_registry_scanning is false. Set manage_registry_scanning = true on exactly one module instance per account+region."
  }
}

# --------------------------------------------------------------------------
# Cross-region replication — registry-wide, per-repo prefix filter
# --------------------------------------------------------------------------

resource "aws_ecr_replication_configuration" "this" {
  # EC-C2: same singleton-ownership story as scanning above.
  count = var.manage_registry_replication && length(local.repos_with_replication) > 0 ? 1 : 0

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

# EC-C2 guard: surface a plan-time error if any repo opts into replicate_to
# without this module instance owning the registry-wide writer.
check "replicate_to_requires_registry_ownership" {
  assert {
    condition     = var.manage_registry_replication || length(local.repos_with_replication) == 0
    error_message = "One or more repositories set replicate_to, but manage_registry_replication is false. Set manage_registry_replication = true on exactly one module instance per account+region."
  }
}
