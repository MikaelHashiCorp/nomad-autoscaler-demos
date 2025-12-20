# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# https://developer.hashicorp.com/nomad/tutorials/autoscaler/horizontal-cluster-scaling?in=nomad%2Fautoscaler#build-demo-environment-ami
# The "packer build ."" command loads all the contents in the current directory.
#
# USAGE:
#   source env-pkr-var.sh && packer init . && packer validate . && packer build .
#
# RECOMMENDED: Use run-with-timestamps.sh for timestamped output:
#   source env-pkr-var.sh && bash ./run-with-timestamps.sh -only="windows.amazon-ebs.hashistack" -var-file=windows-2022.pkrvars.hcl .
#
# NOTE: Packer doesn't support timestamps in console output natively.
#       Timestamps are available in packer.log (via PACKER_LOG_TIMESTAMP=1)
#       or via run-with-timestamps.sh which pipes output through date/ts/gawk.

packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

source "amazon-ebs" "hashistack" {
  # Windows AMIs don't support ED25519, use RSA for Windows, ED25519 for Linux
  temporary_key_pair_type = var.os == "Windows" ? "rsa" : "ed25519"
  ami_name                = format("%s%s", var.name_prefix, "-{{timestamp}}")
  region                  = var.region
  instance_type           = "m5ad.2xlarge" # "m5ad.4xlarge" ; "m6a.4xlarge" ; "t3a.2xlarge"

  # Conditional source AMI filter based on OS type
  source_ami_filter {
    filters = var.os == "Windows" ? {
      virtualization-type = "hvm"
      name                = "Windows_Server-${var.os_version}-English-Full-Base-*"
      root-device-type    = "ebs"
      } : var.os == "Ubuntu" ? {
      virtualization-type = "hvm"
      name                = "ubuntu/images/*ubuntu-${var.os_name}-${var.os_version}-amd64-server-*"
      root-device-type    = "ebs"
      } : {
      virtualization-type = "hvm"
      name                = "RHEL-${var.os_version}_HVM-*-x86_64-*-Hourly2-GP3"
      root-device-type    = "ebs"
    }
    # Windows: Amazon's owner ID, Ubuntu: Canonical's owner ID, RedHat: Red Hat's owner ID
    owners      = var.os == "Windows" ? ["801119661308"] : var.os == "Ubuntu" ? ["099720109477"] : ["309956199498"]
    most_recent = true
  }

  # Conditional communicator based on OS type
  communicator = var.os == "Windows" ? "winrm" : "ssh"

  # WinRM configuration for Windows
  # Use HTTP (port 5985) instead of HTTPS for initial connection
  winrm_username = var.os == "Windows" ? "Administrator" : null
  winrm_use_ssl  = var.os == "Windows" ? false : null
  winrm_insecure = var.os == "Windows" ? true : null
  winrm_timeout  = var.os == "Windows" ? "5m" : null
  winrm_port     = var.os == "Windows" ? 5985 : null

  # SSH configuration for Linux
  # Use 'ubuntu' for Ubuntu, 'ec2-user' for RedHat
  ssh_username = var.os == "Windows" ? null : var.os == "Ubuntu" ? "ubuntu" : "ec2-user"

  # User data for Windows to configure WinRM
  user_data_file = var.os == "Windows" ? "${path.root}/windows-userdata.ps1" : null

  # Tags for the temporary EC2 instance during build
  run_tags = {
    Name = "${var.name_prefix}-packer-build"
  }

  # Tags for the final AMI
  tags = {
    Name                    = format("%s%s", var.name_prefix, formatdate("'_'YYYY-MM-DD", timestamp()))
    Architecture            = var.architecture
    OS                      = var.os
    OS_Version              = var.os_version
    CNI_Version             = var.cni_version
    Consul_Version          = var.consul_version
    Nomad_Version           = var.nomad_version
    Vault_Version           = var.vault_version
    Consul_Template_Version = var.consul_template_version
    Created_Email           = var.created_email
    Created_Name            = var.created_name
  }
}

# Linux build block
build {
  name = "linux"
  sources = [
    "source.amazon-ebs.hashistack"
  ]

  # Only run this build for non-Windows OS
  # Note: Packer doesn't support build-level conditionals, so we handle this at runtime

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
      "TARGET_OS=${var.os}",
      "CNIVERSION=${var.cni_version}",
      "CONSULVERSION=${var.consul_version}",
      "NOMADVERSION=${var.nomad_version}",
      "VAULTVERSION=${var.vault_version}",
      "CONSULTEMPLATEVERSION=${var.consul_template_version}"
    ]
  }
}

# Windows build block
build {
  name = "windows"
  sources = [
    "source.amazon-ebs.hashistack"
  ]

  provisioner "powershell" {
    inline = [
      "Write-Host 'Windows Server 2022 AMI Build Started'",
      "Write-Host 'Creating C:\\ops directory'",
      "New-Item -ItemType Directory -Force -Path C:\\ops"
    ]
  }

  provisioner "file" {
    source      = "../../shared/packer/"
    destination = "C:\\ops\\"
  }

  provisioner "powershell" {
    script = "../../shared/packer/scripts/setup-windows.ps1"
    environment_vars = [
      "CONSULVERSION=${var.consul_version}",
      "NOMADVERSION=${var.nomad_version}",
      "VAULTVERSION=${var.vault_version}",
      "CONSULTEMPLATEVERSION=${var.consul_template_version}"
    ]
  }

  # Restart Windows to complete Windows Containers feature installation
  # This is required before Docker can be started
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  # Post-reboot: Start Docker service and verify installation
  provisioner "powershell" {
    inline = [
      "Write-Host 'Post-reboot: Starting Docker service...'",
      "Start-Service docker -ErrorAction SilentlyContinue",
      "Start-Sleep -Seconds 10",
      "$dockerStatus = Get-Service docker -ErrorAction SilentlyContinue",
      "if ($dockerStatus -and $dockerStatus.Status -eq 'Running') {",
      "  Write-Host 'Docker service is running'",
      "  Write-Host 'Docker version check (may require elevated privileges):'",
      "  $ErrorActionPreference = 'SilentlyContinue'",
      "  docker version 2>$null | Out-String | Write-Host",
      "  $ErrorActionPreference = 'Continue'",
      "  Write-Host 'Docker verification complete (service is running)'",
      "} else {",
      "  Write-Host 'Docker service not running (non-critical)'",
      "}"
    ]
  }

  # NOTE: Sysprep removed to preserve installed HashiStack components
  # Linux AMIs don't run any generalization step, and neither should Windows for this use case
  # Sysprep with /generalize removes user-installed applications, which defeats the purpose
  # of baking HashiStack into the AMI.
  #
  # Trade-offs of skipping sysprep:
  # - Computer name will be the same across instances (acceptable for demo/dev)
  # - SID won't be unique (acceptable if not joining AD domain)
  # - Installed software persists (THIS IS WHAT WE WANT!)
  #
  # If sysprep is needed in the future, use EC2Launch v2 with a custom unattend.xml
  # that preserves C:\bin and installed applications.
  
  provisioner "powershell" {
    inline = [
      "Write-Host 'Windows AMI preparation complete - HashiStack components preserved'",
      "Write-Host 'Installed components:'",
      "Get-ChildItem C:\\HashiCorp\\bin\\*.exe | ForEach-Object { Write-Host \"  - $($_.Name)\" }",
      "Write-Host 'Docker service status:'",
      "Get-Service docker | Format-List Name,Status,StartType"
    ]
  }
}
