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
  # Windows AMIs don't support ED25519 keys, use RSA for Windows and ED25519 for Linux
  temporary_key_pair_type = var.os == "Windows" ? "rsa" : "ed25519"
  ami_name      = format("%s%s", var.name_prefix, "-{{timestamp}}")
  region        = var.region
  instance_type = "t3a.2xlarge"

  # Conditional source AMI filter based on OS type
  source_ami_filter {
    filters = var.os == "Ubuntu" ? {
      virtualization-type = "hvm"
      name                = "ubuntu/images/*ubuntu-${var.os_name}-${var.os_version}-amd64-server-*"
      root-device-type    = "ebs"
    } : var.os == "RedHat" ? {
      virtualization-type = "hvm"
      name                = "RHEL-${var.os_version}_HVM-*-x86_64-*-Hourly2-GP3"
      root-device-type    = "ebs"
    } : var.os == "Windows" ? {
      virtualization-type = "hvm"
      name                = var.os_version == "2025" ? "windows_server_2025_core_base*" : "Windows_Server-${var.os_version}-English-*-Base-*"
      root-device-type    = "ebs"
    } : {
      virtualization-type = "hvm"
      name                = "unknown"
      root-device-type    = "ebs"
    }
    # Ubuntu: Canonical's owner ID, RedHat: Red Hat's owner ID, Windows: 3-tier priority
    # Note: IBM (764552833819) does not currently publish Windows Server base AMIs, but included for future compatibility
    owners      = var.os == "Ubuntu" ? ["099720109477"] : var.os == "RedHat" ? ["309956199498"] : var.os == "Windows" ? ["730335318773", "764552833819", "801119661308"] : ["self"]
    most_recent = true
  }

  # Conditional communicator based on OS type
  communicator = var.os == "Windows" ? "winrm" : "ssh"
  
  # WinRM configuration (only used when communicator is winrm)
  winrm_username = "Administrator"
  winrm_use_ssl  = true
  winrm_insecure = true
  user_data_file = var.os == "Windows" ? "${path.root}/windows-userdata.ps1" : ""
  
  # SSH configuration (only used when communicator is ssh)
  # Use 'ubuntu' for Ubuntu, 'ec2-user' for RedHat, not used for Windows (WinRM)
  ssh_username = var.os == "Ubuntu" ? "ubuntu" : var.os == "RedHat" ? "ec2-user" : ""

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

locals {
  is_windows = var.os == "Windows"
  is_linux   = var.os != "Windows"
}

build {
  sources = [
    "source.amazon-ebs.hashistack"
  ]

  # Linux-only provisioners (Ubuntu and RedHat)
  dynamic "provisioner" {
    for_each = local.is_linux ? [1] : []
    labels   = ["shell"]
    content {
      inline = [
        "cloud-init status --wait"
      ]
    }
  }

  # Conditional debconf setup for Ubuntu only (inline conditional)
  dynamic "provisioner" {
    for_each = local.is_linux ? [1] : []
    labels   = ["shell"]
    content {
      valid_exit_codes = [
        "0",
        "1",
        "2"
      ]
      inline = [
        "if [ -f /etc/debian_version ]; then echo 'set debconf to Noninteractive'; echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections; fi"
      ]
    }
  }

  # Conditional debconf lock cleanup for Ubuntu only
  dynamic "provisioner" {
    for_each = local.is_linux ? [1] : []
    labels   = ["shell"]
    content {
      valid_exit_codes = [
        "0",
        "1",
        "2"
      ]
      inline = [
        "if [ -f /etc/debian_version ]; then sudo fuser -v -k /var/cache/debconf/config.dat || true; fi"
      ]
    }
  }

  # Linux directory setup
  dynamic "provisioner" {
    for_each = local.is_linux ? [1] : []
    labels   = ["shell"]
    content {
      inline = [
        "sudo mkdir -p /ops",
        "sudo chmod 777 /ops"
      ]
    }
  }

  # Linux file copy
  dynamic "provisioner" {
    for_each = local.is_linux ? [1] : []
    labels   = ["file"]
    content {
      source      = "../../shared/packer/"
      destination = "/ops"
    }
  }

  # Linux setup script
  dynamic "provisioner" {
    for_each = local.is_linux ? [1] : []
    labels   = ["shell"]
    content {
      script = "../../shared/packer/scripts/setup.sh"
      environment_vars = [
        "CNIVERSION=${var.cni_version}",
        "CONSULVERSION=${var.consul_version}",
        "NOMADVERSION=${var.nomad_version}",
        "TARGET_OS=${var.os}"
      ]
    }
  }

  # Windows-only provisioners
  # Windows directory setup
  dynamic "provisioner" {
    for_each = local.is_windows ? [1] : []
    labels   = ["powershell"]
    content {
      inline = [
        "New-Item -ItemType Directory -Force -Path C:\\ops"
      ]
    }
  }

  # Windows file copy
  dynamic "provisioner" {
    for_each = local.is_windows ? [1] : []
    labels   = ["file"]
    content {
      source      = "../../shared/packer/"
      destination = "C:/ops"
    }
  }

  # Windows setup script
  dynamic "provisioner" {
    for_each = local.is_windows ? [1] : []
    labels   = ["powershell"]
    content {
      script = "../../shared/packer/scripts/setup.ps1"
      environment_vars = [
        "CNIVERSION=${var.cni_version}",
        "CONSULVERSION=${var.consul_version}",
        "NOMADVERSION=${var.nomad_version}",
        "TARGET_OS=${var.os}"
      ]
    }
  }
}
