terraform {
  required_version = ">= 1.6.0"

  required_providers {
    # S-2 fix: no configuration_aliases here. ECR's cross-region replication
    # (aws_ecr_replication_configuration) runs against the source-region
    # provider — the destination region is named in the rule, not assumed
    # via an aliased provider. Declaring aws.dr here was a consumer tax.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
