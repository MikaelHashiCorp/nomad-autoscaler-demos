# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "stack_name" {
  description = "The name to prefix onto resources."
  type        = string
  default     = "hashistack"
}

variable "owner_name" {
  description = "Your name so resources can be easily assigned."
  type        = string
}

variable "owner_email" {
  description = "Your email so you can be contacted about resources."
  type        = string
}

variable "region" {
  description = "The AWS region to deploy into."
  type        = string
  default     = "us-west-2"
}

variable "availability_zones" {
  description = "The AWS region AZs to deploy into."
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "vpc_id" {
  description = "The AWS VPC to use for resources. If left empty, the default will be used."
  type        = string
  default     = ""
}

variable "ami" {
  description = "The AMI to use, preferably built by the supplied Packer scripts. If left empty, a new AMI will be built automatically."
  type        = string
  default     = ""
}

variable "key_name" {
  description = "The EC2 key pair to use for EC2 instance SSH access."
  type        = string
}

variable "server_instance_type" {
  description = "The EC2 instance type to launch for Nomad servers."
  type        = string
  default     = "t3.small"
}

variable "server_count" {
  description = "The number of Nomad servers to run."
  type        = number
  default     = 1
}

variable "client_instance_type" {
  description = "The EC2 instance type to launch for Nomad clients."
  type        = string
  default     = "t3.small"
}
variable "client_count" {
  description = "The number of Nomad clients to run."
  type        = number
  default     = 1
}

variable "root_block_device_size" {
  description = "The number of GB to assign as a block device on instances."
  type        = number
  default     = 16
}

variable "retry_join" {
  description = "The retry join configuration to use."
  type        = string
  default     = "provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"
}

variable "nomad_binary" {
  description = "The URL to download a custom Nomad binary if desired."
  type        = string
  default     = "none"
}

variable "consul_binary" {
  description = "The URL to download a custom Consul binary if desired."
  type        = string
  default     = "none"
}

variable "allowlist_ip" {
  description = "A list of IP address to grant access via the LBs. If empty, defaults to your current IP."
  type        = list(string)
  default     = []
}

# Packer build configuration (only used when ami is empty and building new AMI)
variable "packer_os" {
  description = "Operating system type for Packer build. Valid values: Ubuntu, RedHat, Windows. Only used when ami is empty."
  type        = string
  default     = "Ubuntu"
}

variable "packer_os_version" {
  description = "Operating system version for Packer build. For Ubuntu: 24.04, 22.04, etc. For RedHat: 9.6.0, etc. For Windows: 2022. Only used when ami is empty."
  type        = string
  default     = "24.04"
}

variable "packer_os_name" {
  description = "Ubuntu codename for Packer build (e.g., noble, jammy). Leave empty for RedHat and Windows. Only used when ami is empty."
  type        = string
  default     = "noble"
}

# Optional Windows test instance (not part of hashistack cluster)

variable "cleanup_ami_on_destroy" {
  description = "Whether to deregister the AMI and delete snapshots when running terraform destroy. Set to false to keep AMIs for later use."
  type        = bool
  default     = true
}

variable "nomad_autoscaler_image" {
  description = "The Docker image to use for the Nomad Autoscaler job."
  type        = string
  default     = "hashicorp/nomad-autoscaler:0.3.3"
}

# When set true and a Windows test instance is enabled, suppress Linux HashiStack
# details in the consolidated output and show only Windows information.

