mock_provider "aws" {}

variables {
  project     = "test"
  environment = "test"
  region      = "us-east-1"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abc-def"

  repositories = {
    "api"           = {}
    "platform/base" = { name = "platform/base" }
  }
}

run "derived_name_uses_primary_name_prefix" {
  command = plan

  assert {
    condition     = aws_ecr_repository.this["api"].name == "test-test-use1/api"
    error_message = "derived repo name should be $${primary_name}/$${key}"
  }
}

run "explicit_name_override_used_directly" {
  command = plan

  assert {
    condition     = aws_ecr_repository.this["platform/base"].name == "platform/base"
    error_message = "explicit name override should be used verbatim, no prefix"
  }
}

run "module_tag_present" {
  command = plan

  assert {
    condition = alltrue([
      for r in values(aws_ecr_repository.this) :
      r.tags["Module"] == "terraform-aws-ecr"
    ])
    error_message = "every repo must carry the Module tag"
  }
}

run "all_repos_carry_spine_tags" {
  command = plan

  assert {
    condition     = aws_ecr_repository.this["api"].tags["Project"] == "test"
    error_message = "repo must carry the Project tag"
  }

  assert {
    condition     = aws_ecr_repository.this["api"].tags["Environment"] == "test"
    error_message = "repo must carry the Environment tag"
  }

  assert {
    condition     = aws_ecr_repository.this["api"].tags["ManagedBy"] == "terraform"
    error_message = "repo must carry ManagedBy=terraform tag"
  }
}

run "consumer_tags_do_not_override_spine" {
  command = plan

  variables {
    tags = {
      Module = "evil-override"
      Owner  = "platform-team"
    }
  }

  assert {
    condition     = aws_ecr_repository.this["api"].tags["Module"] == "terraform-aws-ecr"
    error_message = "consumer tags must not override the Module tag from the spine"
  }

  assert {
    condition     = aws_ecr_repository.this["api"].tags["Owner"] == "platform-team"
    error_message = "consumer-provided non-spine tags must be applied"
  }
}

run "region_compression_eu_west_2" {
  command = plan

  variables {
    region = "eu-west-2"
  }

  assert {
    condition     = aws_ecr_repository.this["api"].name == "test-test-euw2/api"
    error_message = "region compression should produce 'euw2' from 'eu-west-2'"
  }
}

run "name_tag_matches_repository_name" {
  command = plan

  assert {
    condition     = aws_ecr_repository.this["api"].tags["Name"] == "test-test-use1/api"
    error_message = "Name tag should match the resolved repository name"
  }
}
