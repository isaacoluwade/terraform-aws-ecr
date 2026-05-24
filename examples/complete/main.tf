terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# S-2 fix: ECR no longer requires an aws.dr aliased provider — replication is
# configured in the source provider via the destination region name. We do not
# instantiate aws.dr here.

resource "aws_kms_key" "ecr" {
  description             = "${var.project}-${var.environment}-ecr"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  multi_region            = true
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.project}-${var.environment}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

module "ecr" {
  source = "../../"

  project     = var.project
  environment = var.environment
  region      = var.region
  kms_key_arn = aws_kms_key.ecr.arn

  repositories = {
    "api-service" = {
      enhanced_scan      = true
      cross_account_pull = var.consumer_account_id == null ? [] : [var.consumer_account_id]
    }
    "web-frontend" = {
      enhanced_scan = true
    }
    "ml-model" = {
      enhanced_scan        = true
      replicate_to         = [var.dr_region]
      expire_old_versions  = 50 # keep more history for model lineage
      expire_untagged_days = 14
    }
    "platform/base" = {
      name           = "platform/base"
      immutable_tags = false
    }
  }

  tags = {
    Owner      = "platform-team"
    Compliance = "sox"
  }
}
