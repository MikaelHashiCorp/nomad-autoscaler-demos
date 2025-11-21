# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Required variables.
variable "region" {
  type        = string
  description = "The AWS region where the image will be created."
}

variable "owner_name" {
  type        = string
  description = "The name used to identify the owner of the resources provisioned by this module. It will be stored in a tag called OwnerName."
}

variable "owner_email" {
  type        = string
  description = "The email used to contact the owner of the resources provisioned by this module. It will be stored in a tag called OwnerEmail."
}

# Optional variables.
variable "ami_id" {
  type        = string
  default     = ""
  description = "The ID of an existing AMI. If left empty, a new AMI will be built."
}

variable "public_ami" {
  type        = bool
  default     = false
  description = "Set true when ami_id refers to a public (non-self-owned) AMI so ownership checks are skipped."
}

variable "stack_name" {
  type        = string
  default     = "hashistack"
  description = "Name used to identify resources provisioned by this module."
}

# Packer build configuration (only used when building new AMI)
variable "packer_os" {
  type        = string
  default     = "Ubuntu"
  description = "Operating system type for Packer build. Valid values: Ubuntu, RedHat, Windows. Only used when ami_id is empty."
}

variable "packer_os_version" {
  type        = string
  default     = "24.04"
  description = "Operating system version for Packer build. For Ubuntu: 24.04, 22.04, etc. For RedHat: 9.6.0, etc. For Windows: 2022. Only used when ami_id is empty."
}

variable "packer_os_name" {
  type        = string
  default     = "noble"
  description = "Ubuntu codename for Packer build (e.g., noble, jammy). Leave empty for RedHat and Windows. Only used when ami_id is empty."
}

variable "cleanup_ami_on_destroy" {
  type        = bool
  default     = true
  description = "Whether to deregister the AMI and delete snapshots when running terraform destroy. Set to false to keep AMIs for later use."
}