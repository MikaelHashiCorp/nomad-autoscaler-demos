# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# https://developer.hashicorp.com/nomad/tutorials/autoscaler/horizontal-cluster-scaling?in=nomad%2Fautoscaler#build-demo-environment-ami
# The "packer build ."" command loads all the contents in the current directory.
# USAGE:  source env-pkr-var.sh && packer init . && packer validate . && packer build .

packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

source "amazon-ebs" "hashistack" {
  temporary_key_pair_type = "ed25519"
  ami_name      = format("%s%s", var.name_prefix, "-{{timestamp}}")
  region        = var.region
  instance_type = "t3a.2xlarge"

  # Conditional source AMI filter based on OS type
  source_ami_filter {
    filters = var.os == "Ubuntu" ? {
      virtualization-type = "hvm"
      name                = "ubuntu/images/*ubuntu-${var.os_name}-${var.os_version}-amd64-server-*"
      root-device-type    = "ebs"
    } : {
      virtualization-type = "hvm"
      name                = "RHEL-${var.os_version}_HVM-*-x86_64-*-Hourly2-GP3"
      root-device-type    = "ebs"
    }
    # Ubuntu: Canonical's owner ID, RedHat: Red Hat's owner ID
    owners      = var.os == "Ubuntu" ? ["099720109477"] : ["309956199498"]
    most_recent = true
  }

  communicator = "ssh"
  # Use 'ubuntu' for Ubuntu, 'ec2-user' for RedHat
  ssh_username = var.os == "Ubuntu" ? "ubuntu" : "ec2-user"

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

build {
  sources = [
    "source.amazon-ebs.hashistack"
  ]

  provisioner "shell" {
    inline = [
      "cloud-init status --wait"
    ]
  }

  # Conditional debconf setup for Ubuntu only (inline conditional)
  provisioner "shell" {
    valid_exit_codes = [
      "0",
      "1",
      "2"
    ]
    inline = [
      "if [ -f /etc/debian_version ]; then echo 'set debconf to Noninteractive'; echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections; fi"
    ]
  }

  # Conditional debconf lock cleanup for Ubuntu only
  provisioner "shell" {
    valid_exit_codes = [
      "0",
      "1",
      "2"
    ]
    inline = [
      "if [ -f /etc/debian_version ]; then sudo fuser -v -k /var/cache/debconf/config.dat || true; fi"
    ]
  }

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
      "NOMADVERSION=${var.nomad_version}",
      "TARGET_OS=${var.os}"
    ]
  }
}
