variable "project" {
  type    = string
  default = "tt"
}

variable "environment" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "dr_region" {
  type    = string
  default = null
}
