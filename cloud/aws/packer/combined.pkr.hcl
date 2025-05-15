# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# https://developer.hashicorp.com/nomad/tutorials/autoscaler/horizontal-cluster-scaling?in=nomad%2Fautoscaler#build-demo-environment-ami
# The "packer build ."" command loads all the contents in the current directory.
# USAGE:  source env-pkr-var.sh && packer init . && packer validate . && packer build .

# Variable declarations
variable "created_email" { default = "mikael.sikora@hashicorp.com" }
variable "created_name"  { default = "mikael_sikora" }
variable "region"        { default = "us-east-1" }
variable "name_prefix"   { default = "autosc-mws" }
variable "architecture"  { default = "amd64" }
variable "os"            { default = "Ubuntu" }
variable "os_version"    { default = "22.04" }

variable "cni_version"    { default = env("CNIVERSION") }
variable "consul_version" { default = env("CONSULVERSION") }
variable "nomad_version"  { default = env("NOMADVERSION") }
variable "vault_version"  { default = env("VAULTVERSION") }
variable "consul_template_version" { default = env("CONSULTEMPLATEVERSION") }

packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

# Source block
source "amazon-ebs" "hashistack" {
  temporary_key_pair_type = "ed25519"
  ami_name      = format("%s%s", var.name_prefix, "-{{timestamp}}")
  region        = var.region
  instance_type = "t3a.medium"

  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      name                = "ubuntu/images/*ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
    }
    owners      = ["099720109477"] # Canonical's owner ID
    most_recent = true
  }

  communicator = "ssh"
  ssh_username = "ubuntu"

  tags = {
    Name           = format("%s%s", var.name_prefix, formatdate("'_'YYYY-MM-DD", timestamp()))
    Architecture   = var.architecture
    OS             = var.os
    OS_Version     = var.os_version
    CNI_Version    = var.cni_version
    Consul_Version = var.consul_version
    Nomad_Version  = var.nomad_version
    Vault_Version  = var.vault_version
    Consul_Template_Version = var.consul_template_version
    Created_Email  = var.created_email
    Created_Name   = var.created_name
  }
}

# Build block
build {
  sources = [
    "source.amazon-ebs.hashistack"
  ]

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /ops",
      "sudo chmod 777 /ops"
    ]
  }

  provisioner "file" {
    source      = "../../shared/packer/"
    destination = "/ops"
  }

  provisioner "shell" {
    script = "../../shared/packer/scripts/setup.sh"
    environment_vars = [
      "CNIVERSION=${var.cni_version}",
      "CONSULVERSION=${var.consul_version}",
      "NOMADVERSION=${var.nomad_version}"
    ]
  }
}
