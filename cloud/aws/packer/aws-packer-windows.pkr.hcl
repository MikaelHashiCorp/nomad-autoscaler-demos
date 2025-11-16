# Windows Server 2022 AMI build (separate from Linux build)
# Builds a base image that enables OpenSSH and ensures SSM agent is started.
# Usage: source env-pkr-var.sh && packer init . && packer build -var 'os=Windows' -var 'os_version=2022' -var 'os_name=' aws-packer-windows.pkr.hcl
# NOTE: Required plugin "amazon" already declared in aws-packer.pkr.hcl, omitted here to avoid duplicate accessor error.

# Only use this file if var.os == "Windows"; we keep variables consistent

source "amazon-ebs" "win2022" {
  ami_name      = format("%s%s", var.name_prefix, "-win-{{timestamp}}")
  region        = var.region
  instance_type = "t3a.2xlarge"
  # Windows does not support ED25519 temporary keys; use RSA
  temporary_key_pair_type = "rsa"

  # Public Windows Server 2022 English Full Base AMI
  source_ami_filter {
    filters = {
      name                = "Windows_Server-2022-English-Full-Base-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["801119661308"] # Amazon
    most_recent = true
  }

  communicator        = "winrm"
  winrm_username      = "Administrator"
  winrm_use_ssl       = false
  winrm_insecure      = true
  winrm_timeout       = "30m"
  # Force early WinRM availability: run a bootstrap PowerShell via user_data
  # This ensures WinRM service configured & firewall rule present before Packer attempts connection.
  user_data            = <<EOF
<powershell>
Write-Host "[user_data] Initializing WinRM"
winrm quickconfig -quiet
Set-Item -Path 'WSMan:\localhost\Service\AllowUnencrypted' -Value $true
Set-Item -Path 'WSMan:\localhost\Service\Auth\Basic' -Value $true
netsh advfirewall firewall add rule name="WinRM 5985" dir=in action=allow protocol=TCP localport=5985
Restart-Service WinRM
Write-Host "[user_data] WinRM ready"
</powershell>
EOF

  tags = {
    Name           = format("%s%s", var.name_prefix, formatdate("'_win_'YYYY-MM-DD", timestamp()))
    Architecture   = var.architecture
    OS             = var.os
    OS_Version     = var.os_version
    Created_Email  = var.created_email
    Created_Name   = var.created_name
  }
}

build {
  sources = ["source.amazon-ebs.win2022"]

  # Ensure SSM agent enabled (preinstalled on Windows images but ensure startup)
  provisioner "powershell" {
    inline = [
      "if (Get-Service -Name AmazonSSMAgent -ErrorAction SilentlyContinue) { Set-Service AmazonSSMAgent -StartupType Automatic; Start-Service AmazonSSMAgent }"
    ]
  }

  # Configure EC2Launch v2 to always (re)generate Administrator password (optional)
  provisioner "powershell" {
    inline = [
      "$cfg = @'\nversion: 1.0\nconfig:\n  - stage: boot\n    tasks:\n      - task: setAdminAccount\n        inputs:\n          name: Administrator\n          password:\n            type: random\n'@",
      "$path = 'C:/ProgramData/Amazon/EC2Launch/config/agent-config.yml'",
      "$cfg | Out-File -FilePath $path -Encoding UTF8 -Force"
    ]
  }
}
