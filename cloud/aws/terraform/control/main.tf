# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # version = "~> 5.0"  # Updated to latest major version
    }
    nomad = {
      source  = "hashicorp/nomad"
      # version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      # version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      # version = "~> 3.0"
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
  source  = "matti/resource/shell"
  command = "curl https://ipinfo.io/ip"
}

module "hashistack_cluster" {
  source               = "../modules/aws-hashistack"
  owner_name           = var.owner_name
  owner_email          = var.owner_email
  region               = var.region
  availability_zones   = var.availability_zones
  ami                  = var.ami
  create_csi_resources = var.create_csi_resources
  create_ebs_resources = var.create_ebs_resources
  key_name             = var.key_name
  stack_name           = var.stack_name
  server_instance_type = var.server_instance_type
  server_count         = var.server_count
  client_instance_type = var.client_instance_type
  client_count         = var.client_count
  nomad_autoscaler_image = var.nomad_autoscaler_image
  allowlist_ip         = (var.allowlist_ip == "" ? ["${module.my_ip_address.stdout}/32"] : var.allowlist_ip)
}

module "hashistack_jobs" {
  source     = "../../../shared/terraform/modules/shared-nomad-jobs"
  nomad_addr = "http://${module.hashistack_cluster.server_elb_dns}:4646"
}
