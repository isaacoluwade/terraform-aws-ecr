provider "aws" {
  region = var.region
}

resource "aws_kms_key" "ecr" {
  description             = "${var.project}-${var.environment}-ecr"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

module "ecr" {
  source = "../../"

  project     = var.project
  environment = var.environment
  region      = var.region
  kms_key_arn = aws_kms_key.ecr.arn

  repositories = {
    "app"  = {}
    "base" = { immutable_tags = false }
  }

  tags = {
    Owner = "ci-terratest"
  }
}
