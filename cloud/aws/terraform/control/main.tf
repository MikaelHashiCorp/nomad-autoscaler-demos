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

module "my_ip_address" {
  source = "matti/resource/shell"

  command = "curl https://ipinfo.io/ip"
}

module "hashistack_image" {
  source = "../modules/aws-nomad-image"

  ami_id                  = var.ami
  region                  = var.region
  stack_name              = var.stack_name
  owner_name              = var.owner_name
  owner_email             = var.owner_email
  packer_os               = var.packer_os
  packer_os_version       = var.packer_os_version
  packer_os_name          = var.packer_os_name
  cleanup_ami_on_destroy  = var.cleanup_ami_on_destroy
}

module "hashistack_cluster" {
  source = "../modules/aws-hashistack"

  # Explicit dependency ensures AMI is fully built before creating infrastructure
  depends_on = [module.hashistack_image]

  region                = var.region
  availability_zones    = var.availability_zones
  ami                   = module.hashistack_image.id
  key_name              = var.key_name
  owner_name            = var.owner_name
  owner_email           = var.owner_email
  stack_name            = var.stack_name
  allowlist_ip          = length(var.allowlist_ip) > 0 ? var.allowlist_ip : ["${module.my_ip_address.stdout}/32"]
  server_instance_type  = var.server_instance_type
  client_instance_type  = var.client_instance_type
  server_count          = var.server_count
  client_count          = var.client_count
}

module "hashistack_jobs" {
  source = "../../../shared/terraform/modules/shared-nomad-jobs"

  nomad_addr = "http://${module.hashistack_cluster.server_elb_dns}:4646"
}
