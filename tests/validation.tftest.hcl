mock_provider "aws" {}
mock_provider "aws" {
  alias = "dr"
}

run "rejects_project_too_short" {
  command = plan

  variables {
    project     = "ab"
    environment = "test"
    region      = "us-east-1"
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abc-def"
    repositories = {
      "api" = {}
    }
  }

  expect_failures = [
    var.project,
  ]
}

run "rejects_environment_with_uppercase" {
  command = plan

  variables {
    project     = "test"
    environment = "Prod"
    region      = "us-east-1"
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abc-def"
    repositories = {
      "api" = {}
    }
  }

  expect_failures = [
    var.environment,
  ]
}

run "rejects_invalid_region" {
  command = plan

  variables {
    project     = "test"
    environment = "test"
    region      = "not-a-region"
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abc-def"
    repositories = {
      "api" = {}
    }
  }

  expect_failures = [
    var.region,
  ]
}

run "rejects_invalid_kms_key_arn" {
  command = plan

  variables {
    project     = "test"
    environment = "test"
    region      = "us-east-1"
    kms_key_arn = "not-an-arn"
    repositories = {
      "api" = {}
    }
  }

  expect_failures = [
    var.kms_key_arn,
  ]
}

run "rejects_invalid_account_id" {
  command = plan

  variables {
    project     = "test"
    environment = "test"
    region      = "us-east-1"
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abc-def"
    repositories = {
      "api" = { cross_account_pull = ["not-an-account"] }
    }
  }

  expect_failures = [
    var.repositories,
  ]
}

run "rejects_excessive_lifecycle_days" {
  command = plan

  variables {
    project     = "test"
    environment = "test"
    region      = "us-east-1"
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abc-def"
    repositories = {
      "api" = { expire_untagged_days = 9999 }
    }
  }

  expect_failures = [
    var.repositories,
  ]
}

run "rejects_zero_lifecycle_days" {
  command = plan

  variables {
    project     = "test"
    environment = "test"
    region      = "us-east-1"
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abc-def"
    repositories = {
      "api" = { expire_untagged_days = 0 }
    }
  }

  expect_failures = [
    var.repositories,
  ]
}

run "rejects_excessive_old_versions" {
  command = plan

  variables {
    project     = "test"
    environment = "test"
    region      = "us-east-1"
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abc-def"
    repositories = {
      "api" = { expire_old_versions = 9999 }
    }
  }

  expect_failures = [
    var.repositories,
  ]
}

run "rejects_invalid_replication_region" {
  command = plan

  variables {
    project     = "test"
    environment = "test"
    region      = "us-east-1"
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abc-def"
    repositories = {
      "api" = { replicate_to = ["not-a-region"] }
    }
  }

  expect_failures = [
    var.repositories,
  ]
}
