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
      name                = "Windows_Server-2022-English-Full-Base-*"
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

  # Tags for the temporary build instance
  run_tags = {
    Name = format("%s-packer-build-%s", var.name_prefix, var.os)
  }

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
      "VAULTVERSION=${var.vault_version}"
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

  # Explicit directory copies to avoid Windows file provisioner issues with nested directories
  provisioner "file" {
    source      = "../../shared/packer/scripts/"
    destination = "C:\\ops\\scripts\\"
  }

  provisioner "file" {
    source      = "../../shared/packer/config/"
    destination = "C:\\ops\\config\\"
  }

  # Verify all required files were copied successfully
  provisioner "powershell" {
    inline = [
      "Write-Host 'Verifying C:\\ops directory structure...' -ForegroundColor Cyan",
      "Write-Host ''",
      "Write-Host 'Scripts directory:' -ForegroundColor Yellow",
      "Get-ChildItem -Path C:\\ops\\scripts | Select-Object Name, Length | Format-Table -AutoSize",
      "Write-Host 'Config directory:' -ForegroundColor Yellow",
      "Get-ChildItem -Path C:\\ops\\config | Select-Object Name, Length | Format-Table -AutoSize",
      "Write-Host ''",
      "",
      "# Verify critical files exist",
      "$missingFiles = @()",
      "if (-not (Test-Path 'C:\\ops\\scripts\\client.ps1')) { $missingFiles += 'client.ps1' }",
      "if (-not (Test-Path 'C:\\ops\\config\\consul_client.hcl')) { $missingFiles += 'consul_client.hcl' }",
      "if (-not (Test-Path 'C:\\ops\\config\\nomad_client.hcl')) { $missingFiles += 'nomad_client.hcl' }",
      "",
      "if ($missingFiles.Count -gt 0) {",
      "  Write-Host 'ERROR: Missing required files:' -ForegroundColor Red",
      "  $missingFiles | ForEach-Object { Write-Host \"  - $_\" -ForegroundColor Red }",
      "  exit 1",
      "}",
      "",
      "Write-Host 'All required files verified successfully!' -ForegroundColor Green"
    ]
  }

  provisioner "powershell" {
    script = "../../shared/packer/scripts/setup-windows.ps1"
    # Environment variables removed to allow script to auto-fetch latest versions
    # To use specific versions, set environment variables before running packer:
    #   export CONSULVERSION=1.22.1
    #   export NOMADVERSION=1.11.1
    #   export VAULTVERSION=1.21.1
    # Or source env-pkr-var.sh to fetch latest versions into environment
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
      "}",
      "exit 0"
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
  
  # Configure EC2Launch v2 to execute user-data on every boot
  # This replaces the default agent-config.yml with one that includes the executeScript task
  provisioner "file" {
    source      = "config/ec2launch-agent-config.yml"
    destination = "C:\\ProgramData\\Amazon\\EC2Launch\\config\\agent-config.yml"
  }
  
  # Verify the EC2Launch v2 configuration was applied correctly
  provisioner "powershell" {
    inline = [
      "Write-Host 'Verifying EC2Launch v2 configuration...'",
      "$configPath = 'C:\\ProgramData\\Amazon\\EC2Launch\\config\\agent-config.yml'",
      "if (Test-Path $configPath) {",
      "  $config = Get-Content $configPath -Raw",
      "  # EC2Launch v2 handles user-data automatically - no executeScript task needed",
      "  if ($config -match 'executeScript') {",
      "    Write-Host '[WARNING] executeScript task found - this is not needed as EC2Launch v2 handles user-data automatically'",
      "    Write-Host '[INFO] Consider removing executeScript task from configuration'",
      "  }",
      "  # Verify essential tasks are present",
      "  if ($config -match 'startSsm') {",
      "    Write-Host '[OK] startSsm task found in configuration'",
      "  } else {",
      "    Write-Host '[WARNING] startSsm task not found - SSM may not be available'",
      "  }",
      "  Write-Host '[SUCCESS] EC2Launch v2 configuration verified'",
      "  Write-Host '[INFO] User-data will be executed automatically by EC2Launch v2 on every boot'",
      "} else {",
      "  Write-Host '[ERROR] Configuration file not found at expected location'",
      "  exit 1",
      "}"
    ]
  }
  
  # Clean up HashiStack state and config files from Packer build
  # This prevents leftover server configs and state data from being baked into the AMI
  # Bug #12: AMI was containing Packer build artifacts that conflicted with runtime config
  provisioner "powershell" {
    inline = [
      "Write-Host 'Cleaning up HashiStack state and config files from Packer build...' -ForegroundColor Yellow",
      "",
      "# Remove Consul state and config subdirectories",
      "Write-Host '  Cleaning Consul directories...'",
      "if (Test-Path 'C:\\HashiCorp\\Consul\\data') {",
      "  Remove-Item 'C:\\HashiCorp\\Consul\\data' -Recurse -Force -ErrorAction SilentlyContinue",
      "  Write-Host '    [OK] Removed Consul data directory' -ForegroundColor Green",
      "}",
      "if (Test-Path 'C:\\HashiCorp\\Consul\\config') {",
      "  Remove-Item 'C:\\HashiCorp\\Consul\\config' -Recurse -Force -ErrorAction SilentlyContinue",
      "  Write-Host '    [OK] Removed Consul config directory' -ForegroundColor Green",
      "}",
      "if (Test-Path 'C:\\HashiCorp\\Consul\\logs') {",
      "  Remove-Item 'C:\\HashiCorp\\Consul\\logs' -Recurse -Force -ErrorAction SilentlyContinue",
      "  Write-Host '    [OK] Removed Consul logs directory' -ForegroundColor Green",
      "}",
      "",
      "# Remove Nomad state and config subdirectories",
      "Write-Host '  Cleaning Nomad directories...'",
      "if (Test-Path 'C:\\HashiCorp\\Nomad\\data') {",
      "  Remove-Item 'C:\\HashiCorp\\Nomad\\data' -Recurse -Force -ErrorAction SilentlyContinue",
      "  Write-Host '    [OK] Removed Nomad data directory' -ForegroundColor Green",
      "}",
      "if (Test-Path 'C:\\HashiCorp\\Nomad\\config') {",
      "  Remove-Item 'C:\\HashiCorp\\Nomad\\config' -Recurse -Force -ErrorAction SilentlyContinue",
      "  Write-Host '    [OK] Removed Nomad config directory' -ForegroundColor Green",
      "}",
      "if (Test-Path 'C:\\HashiCorp\\Nomad\\logs') {",
      "  Remove-Item 'C:\\HashiCorp\\Nomad\\logs' -Recurse -Force -ErrorAction SilentlyContinue",
      "  Write-Host '    [OK] Removed Nomad logs directory' -ForegroundColor Green",
      "}",
      "",
      "# Recreate empty directories for runtime use",
      "Write-Host '  Recreating empty directories...'",
      "New-Item -Path 'C:\\HashiCorp\\Consul\\data' -ItemType Directory -Force | Out-Null",
      "New-Item -Path 'C:\\HashiCorp\\Consul\\logs' -ItemType Directory -Force | Out-Null",
      "New-Item -Path 'C:\\HashiCorp\\Nomad\\data' -ItemType Directory -Force | Out-Null",
      "New-Item -Path 'C:\\HashiCorp\\Nomad\\config' -ItemType Directory -Force | Out-Null",
      "New-Item -Path 'C:\\HashiCorp\\Nomad\\logs' -ItemType Directory -Force | Out-Null",
      "Write-Host '    [OK] Empty directories created' -ForegroundColor Green",
      "",
      "# Verify cleanup",
      "Write-Host '  Verifying cleanup...'",
      "$consulFiles = Get-ChildItem 'C:\\HashiCorp\\Consul' -Recurse -File -ErrorAction SilentlyContinue",
      "$nomadFiles = Get-ChildItem 'C:\\HashiCorp\\Nomad' -Recurse -File -ErrorAction SilentlyContinue",
      "if ($consulFiles -or $nomadFiles) {",
      "  Write-Host '    [WARNING] Some files remain:' -ForegroundColor Yellow",
      "  $consulFiles | ForEach-Object { Write-Host \"      Consul: $($_.FullName)\" -ForegroundColor Yellow }",
      "  $nomadFiles | ForEach-Object { Write-Host \"      Nomad: $($_.FullName)\" -ForegroundColor Yellow }",
      "} else {",
      "  Write-Host '    [OK] All state and config files removed' -ForegroundColor Green",
      "}",
      "",
      "Write-Host '[SUCCESS] HashiStack cleanup complete - AMI is ready for runtime configuration' -ForegroundColor Green"
    ]
  }
  
  # Reset EC2Launch v2 state files (secondary cleanup)
  # Removes state files created during Packer build
  provisioner "powershell" {
    inline = [
      "Write-Host 'Cleaning up EC2Launch v2 state files...'",
      "$statePath = 'C:\\ProgramData\\Amazon\\EC2Launch\\state'",
      "if (Test-Path \"$statePath\\.run-once\") {",
      "  Remove-Item \"$statePath\\.run-once\" -Force",
      "  Write-Host 'Removed .run-once file'",
      "}",
      "if (Test-Path \"$statePath\\state.json\") {",
      "  Remove-Item \"$statePath\\state.json\" -Force",
      "  Write-Host 'Removed state.json file'",
      "}",
      "Write-Host 'EC2Launch v2 state reset complete'"
    ]
  }
}
