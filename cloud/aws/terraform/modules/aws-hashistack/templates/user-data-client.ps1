<powershell>
# Windows Client User Data for Nomad/Consul Client
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

Set-ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = "Stop"

Write-Host "Starting Nomad/Consul client configuration..."

# Get instance metadata
$instanceId = Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/instance-id
$localIp = Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/local-ipv4
$region = "${region}"

Write-Host "Instance ID: $instanceId"
Write-Host "Local IP: $localIp"
Write-Host "Region: $region"

# Optional SSH public key injection for Administrator
$publicKey = "${windows_ssh_public_key}"
if ($publicKey -and $publicKey.Trim() -ne "") {
  Write-Host "Configuring OpenSSH authorized key for Administrator..."
  $authFile = "C:\\ProgramData\\ssh\\administrators_authorized_keys"
  $authDir = Split-Path $authFile
  if (!(Test-Path $authDir)) { New-Item -ItemType Directory -Path $authDir -Force | Out-Null }
  $publicKey | Out-File -FilePath $authFile -Encoding ascii -Force
  & icacls $authFile /inheritance:r | Out-Null
  & icacls $authFile /grant "SYSTEM:(R)" | Out-Null
  & icacls $authFile /grant "Administrators:(R)" | Out-Null
  Write-Host "Authorized key installed. Restarting sshd..."
  Restart-Service sshd -ErrorAction SilentlyContinue
}

# Configure Consul
Write-Host "Configuring Consul client..."
$consulConfig = @"
datacenter = "dc1"
data_dir = "C:/opt/consul/data"
log_level = "INFO"
node_name = "$instanceId"
bind_addr = "$localIp"
client_addr = "0.0.0.0"

retry_join = ["${retry_join}"]

ports {
  grpc = 8502
}
"@

$consulConfig | Out-File -FilePath "C:\opt\consul\config\consul.hcl" -Encoding UTF8

# Start Consul service
Write-Host "Starting Consul service..."
Start-Service -Name "Consul"
Start-Sleep -Seconds 5

# Set Consul to auto-start on boot
Write-Host "Configuring Consul for automatic startup..."
nssm set Consul Start SERVICE_AUTO_START

# Configure Nomad
Write-Host "Configuring Nomad client..."
$nomadConfig = @"
datacenter = "dc1"
data_dir = "C:/opt/nomad/data"
log_level = "INFO"
bind_addr = "0.0.0.0"

client {
  enabled = true
  node_class = "${node_class}"
  
  options {
    "driver.raw_exec.enable" = "1"
  }
}

consul {
  address = "127.0.0.1:8500"
}

plugin "docker" {
  config {
    allow_privileged = true
    volumes {
      enabled = true
    }
  }
}

telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}
"@

$nomadConfig | Out-File -FilePath "C:\opt\nomad\config\nomad.hcl" -Encoding UTF8

# Start Nomad service
Write-Host "Starting Nomad service..."
Start-Service -Name "Nomad"

# Set Nomad to auto-start on boot  
Write-Host "Configuring Nomad for automatic startup..."
nssm set Nomad Start SERVICE_AUTO_START

Write-Host "Client configuration completed successfully."
</powershell>
