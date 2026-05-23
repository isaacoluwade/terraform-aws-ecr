variable "project" {
  type        = string
  description = "Project name passed through to the module."
  default     = "example"
}

variable "environment" {
  type        = string
  description = "Environment name passed through to the module."
  default     = "dev"
}

variable "region" {
  type        = string
  description = "Primary AWS region."
  default     = "us-east-1"
}

variable "dr_region" {
  type        = string
  description = "DR AWS region for cross-region replication."
  default     = "us-west-2"
}

variable "consumer_account_id" {
  type        = string
  description = "Optional sister AWS account that may pull from the api-service repo. Null = no cross-account grant."
  default     = null

  validation {
    condition     = var.consumer_account_id == null || can(regex("^[0-9]{12}$", var.consumer_account_id))
    error_message = "consumer_account_id must be null or a 12-digit AWS account ID."
  }
}
