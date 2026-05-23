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
  description = "AWS region."
  default     = "us-east-1"
}
