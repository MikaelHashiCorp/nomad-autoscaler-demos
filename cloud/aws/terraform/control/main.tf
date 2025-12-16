# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_version = ">= 0.12"

  required_providers {
    aws = {
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "nomad" {
  address = "http://${module.hashistack_cluster.server_elb_dns}:4646"
}

locals {
  # Create OS-specific stack name for AWS resources
  # Maps OS names to lowercase: "Ubuntu" -> "ubuntu", "RedHat" -> "redhat", etc.
  os_suffix = lower(var.packer_os)
  stack_name_with_os = "${var.stack_name}-${local.os_suffix}"
  
  # Windows stack name for Windows AMI
  stack_name_windows = "${var.stack_name}-windows"
}

module "my_ip_address" {
  source = "matti/resource/shell"

  command = "curl https://ipinfo.io/ip"
}

# Linux AMI (for servers and Linux clients)
module "hashistack_image_linux" {
  source = "../modules/aws-nomad-image"

  ami_id                  = var.ami
  region                  = var.region
  stack_name              = local.stack_name_with_os
  owner_name              = var.owner_name
  owner_email             = var.owner_email
  packer_os               = var.packer_os
  packer_os_version       = var.packer_os_version
  packer_os_name          = var.packer_os_name
  cleanup_ami_on_destroy  = var.cleanup_ami_on_destroy
}

# Windows AMI (for Windows clients only, built only when windows_client_count > 0)
module "hashistack_image_windows" {
  count  = var.windows_client_count > 0 ? 1 : 0
  source = "../modules/aws-nomad-image"

  ami_id                  = var.windows_ami
  region                  = var.region
  stack_name              = local.stack_name_windows
  owner_name              = var.owner_name
  owner_email             = var.owner_email
  packer_os               = "Windows"
  packer_os_version       = var.packer_windows_version
  packer_os_name          = ""
  cleanup_ami_on_destroy  = var.cleanup_ami_on_destroy
}

module "hashistack_cluster" {
  source = "../modules/aws-hashistack"

  # Explicit dependency ensures AMIs are fully built before creating infrastructure
  depends_on = [
    module.hashistack_image_linux,
    module.hashistack_image_windows
  ]

  region                       = var.region
  availability_zones           = var.availability_zones
  ami                          = module.hashistack_image_linux.id
  windows_ami                  = var.windows_client_count > 0 ? module.hashistack_image_windows[0].id : ""
  key_name                     = var.key_name
  owner_name                   = var.owner_name
  owner_email                  = var.owner_email
  stack_name                   = local.stack_name_with_os
  allowlist_ip                 = length(var.allowlist_ip) > 0 ? var.allowlist_ip : ["${module.my_ip_address.stdout}/32"]
  server_instance_type         = var.server_instance_type
  client_instance_type         = var.client_instance_type
  server_count                 = var.server_count
  client_count                 = var.client_count
  windows_client_instance_type = var.windows_client_instance_type
  windows_client_count         = var.windows_client_count
}

module "hashistack_jobs" {
  source = "../../../shared/terraform/modules/shared-nomad-jobs"

  nomad_addr = "http://${module.hashistack_cluster.server_elb_dns}:4646"
}
