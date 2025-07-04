# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "owner_email" {}
variable "owner_name" {}
variable "region" {}
variable "vpc_id" {}
variable "subnet_id" {}
variable "stack_name" {}

source "amazon-ebs" "hashistack" {
  temporary_key_pair_type = "ed25519"
  ami_name      = var.stack_name
  region        = var.region
  subnet_id     = var.subnet_id
  vpc_id        = var.vpc_id
  instance_type = "t3.medium"

  associate_public_ip_address = true

  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
    }
    owners      = ["099720109477"] # Canonical's owner ID
    most_recent = true
  }

  communicator = "ssh"
  ssh_username = "ubuntu"

  tags = {
    OS           = "Ubuntu"
    Release      = "22.04"
    Architecture = "amd64"
    OwnerName    = var.owner_name
    OwnerEmail   = var.owner_email
  }
}

build {
  sources = [
    "source.amazon-ebs.hashistack"
  ]

  provisioner "shell" {
    inline = [
      "echo set debconf to Noninteractive", 
      "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections" ]
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
  }
}
