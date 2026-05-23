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

# Required by the module even when no replication is configured (configuration_aliases);
# pointed at the primary region so the unused provider has a valid config.
provider "aws" {
  alias  = "dr"
  region = var.region
}

# In a real composition this comes from terraform-aws-kms; we synthesize a key
# here so the example can stand alone.
resource "aws_kms_key" "ecr" {
  description             = "${var.project}-${var.environment}-ecr"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.project}-${var.environment}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

module "ecr" {
  source = "../../"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  project     = var.project
  environment = var.environment
  region      = var.region
  kms_key_arn = aws_kms_key.ecr.arn

  repositories = {
    "app"  = {}
    "base" = { immutable_tags = false } # base image uses :latest
  }

  tags = {
    Owner = "platform-team"
  }
}
