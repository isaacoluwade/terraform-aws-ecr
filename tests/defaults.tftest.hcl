mock_provider "aws" {}

variables {
  project     = "test"
  environment = "test"
  region      = "us-east-1"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abc-def"

  repositories = {
    "api-service" = {}
    "web"         = {}
  }
}

run "all_repos_kms_encrypted" {
  command = plan

  assert {
    condition = alltrue([
      for r in values(aws_ecr_repository.this) :
      r.encryption_configuration[0].encryption_type == "KMS"
    ])
    error_message = "every repository must use KMS encryption"
  }

  assert {
    condition = alltrue([
      for r in values(aws_ecr_repository.this) :
      r.encryption_configuration[0].kms_key == "arn:aws:kms:us-east-1:123456789012:key/abc-def"
    ])
    error_message = "every repository must use the configured KMS key"
  }
}

run "immutable_tags_default" {
  command = plan

  assert {
    condition = alltrue([
      for r in values(aws_ecr_repository.this) :
      r.image_tag_mutability == "IMMUTABLE"
    ])
    error_message = "default tag mutability should be IMMUTABLE"
  }
}

run "scan_on_push_default" {
  command = plan

  assert {
    condition = alltrue([
      for r in values(aws_ecr_repository.this) :
      r.image_scanning_configuration[0].scan_on_push == true
    ])
    error_message = "scan_on_push must default to true"
  }
}

run "lifecycle_has_two_rules" {
  command = plan

  assert {
    condition = alltrue([
      for k, _ in var.repositories :
      length(jsondecode(aws_ecr_lifecycle_policy.this[k].policy).rules) == 2
    ])
    error_message = "each repo's lifecycle policy must have exactly 2 rules (untagged + tagged)"
  }
}

run "lifecycle_untagged_rule_priority_1" {
  command = plan

  assert {
    condition = alltrue([
      for k, _ in var.repositories :
      jsondecode(aws_ecr_lifecycle_policy.this[k].policy).rules[0].selection.tagStatus == "untagged"
    ])
    error_message = "rulePriority 1 must target untagged images so it runs before the count-based rule"
  }
}

run "no_repo_policy_without_cross_account" {
  command = plan

  assert {
    condition     = length(aws_ecr_repository_policy.this) == 0
    error_message = "no repository policy should exist when no cross-account access is configured"
  }
}

run "no_replication_without_targets" {
  command = plan

  assert {
    condition     = length(aws_ecr_replication_configuration.this) == 0
    error_message = "no replication config should exist when no replicate_to is set"
  }
}

run "no_enhanced_scan_without_opt_in" {
  command = plan

  assert {
    condition     = length(aws_ecr_registry_scanning_configuration.this) == 0
    error_message = "no enhanced scanning resource should exist when no repo has enhanced_scan=true"
  }
}

run "cross_account_pull_produces_policy" {
  command = plan

  variables {
    repositories = {
      "shared" = {
        cross_account_pull = ["123456789012"]
      }
    }
  }

  assert {
    condition     = length(aws_ecr_repository_policy.this) == 1
    error_message = "exactly one repository policy should be produced for the cross-account-pull repo"
  }
}

run "replication_configured_when_replicate_to_set" {
  command = plan

  variables {
    repositories = {
      "ml-model" = {
        replicate_to = ["us-west-2"]
      }
    }
  }

  assert {
    condition     = length(aws_ecr_replication_configuration.this) == 1
    error_message = "exactly one registry-wide replication configuration should be produced"
  }
}
