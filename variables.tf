variable "project" {
  type        = string
  description = "Project / platform name. Drives primary_name and the Project tag on every resource. Lowercase letters, digits, and hyphens only; 3-12 characters."

  validation {
    condition     = can(regex("^[a-z0-9-]{3,12}$", var.project))
    error_message = "project must be 3-12 chars, lowercase letters, digits, and hyphens only."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod, ci-*). Drives primary_name and the Environment tag. Lowercase letters, digits, and hyphens only."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "environment must be lowercase letters, digits, and hyphens only."
  }
}

variable "region" {
  type        = string
  description = "Primary AWS region (e.g. us-east-1). Where the ECR registry lives."

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "region must look like 'us-east-1', 'eu-west-2', etc."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key used to encrypt repository data at rest. Typically module.platform_kms.key_arn."

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be a valid KMS key ARN."
  }
}

variable "manage_registry_replication" {
  type        = bool
  description = "EC-C2 fix: must be true to allow this module instance to write the account/region-wide aws_ecr_replication_configuration. Only ONE module instance per account+region may set this true — the resource is a registry-wide singleton and a second writer silently overwrites the first. Per-repo replicate_to settings are rejected with a precondition error when this flag is false."
  default     = false
}

variable "manage_registry_scanning" {
  type        = bool
  description = "EC-C2 fix: must be true to allow this module instance to write the account/region-wide aws_ecr_registry_scanning_configuration. Same singleton constraint as manage_registry_replication. Per-repo enhanced_scan opt-ins are rejected with a precondition error when this flag is false."
  default     = false
}

variable "repositories" {
  type = map(object({
    name = optional(string)

    immutable_tags = optional(bool, true)
    scan_on_push   = optional(bool, true)
    enhanced_scan  = optional(bool, false)

    cross_account_pull = optional(list(string), [])
    cross_account_push = optional(list(string), [])

    expire_untagged_days = optional(number, 7)
    expire_old_versions  = optional(number, 30)

    replicate_to = optional(list(string), [])
  }))

  description = "Map of repositories to create. Keys become the default repo name suffix (derived as $${primary_name}/$${key}) unless overridden by 'name'."

  validation {
    condition = alltrue([
      for r in var.repositories : alltrue([
        for acct in concat(r.cross_account_pull, r.cross_account_push) :
        can(regex("^[0-9]{12}$", acct))
      ])
    ])
    error_message = "cross_account_pull and cross_account_push entries must be 12-digit AWS account IDs."
  }

  validation {
    condition = alltrue([
      for r in var.repositories : r.expire_untagged_days >= 1 && r.expire_untagged_days <= 365
    ])
    error_message = "expire_untagged_days must be between 1 and 365."
  }

  validation {
    condition = alltrue([
      for r in var.repositories : r.expire_old_versions >= 1 && r.expire_old_versions <= 100
    ])
    error_message = "expire_old_versions must be between 1 and 100."
  }

  validation {
    condition = alltrue([
      for r in var.repositories : alltrue([
        for region in r.replicate_to :
        can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", region))
      ])
    ])
    error_message = "replicate_to entries must be valid AWS regions."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to merge with the module's default tag spine. Keys that conflict with the spine are overridden by the spine."
  default     = {}
}
