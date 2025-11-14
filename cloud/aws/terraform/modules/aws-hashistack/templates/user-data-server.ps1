<powershell>
# Windows Server User Data for Nomad/Consul Server
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

Set-ExecutionPolicy Bypass -Scope Process -Force
$ErrorActionPreference = "Stop"

Write-Host "Starting Nomad/Consul server configuration..."

# Get instance metadata
$instanceId = Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/instance-id
$localIp = Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/local-ipv4
$region = "${region}"
$serverCount = ${server_count}

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

# Configure Consul (align with NSSM service config dir C:\etc\consul.d)
Write-Host "Configuring Consul server..."
New-Item -ItemType Directory -Path "C:\etc\consul.d" -Force | Out-Null
$consulConfig = @"
datacenter = "dc1"
data_dir = "C:/opt/consul/data"
log_level = "INFO"
node_name = "$instanceId"
server = true
bootstrap_expect = $serverCount
bind_addr = "$localIp"
client_addr = "0.0.0.0"

ui_config {
  enabled = true
}

retry_join = ["${retry_join}"]

ports {
  grpc = 8502
}
"@

$consulConfig | Out-File -FilePath "C:\etc\consul.d\consul.hcl" -Encoding UTF8

# Adjust Consul service parameters to correct config dir (was C:\opt\consul\config in AMI)
Write-Host "Configuring Consul service parameters for C:\\etc\\consul.d ..."
nssm set Consul AppParameters "agent -config-dir=C:\\etc\\consul.d -data-dir=C:\\opt\\consul\\data"
nssm set Consul Start SERVICE_AUTO_START
Write-Host "Restarting Consul service..."
if (Get-Service -Name "Consul" -ErrorAction SilentlyContinue) { Stop-Service Consul -Force -ErrorAction SilentlyContinue }
Start-Service -Name "Consul"
Start-Sleep -Seconds 10

# Configure Nomad (align with NSSM service config dir C:\etc\nomad.d)
Write-Host "Configuring Nomad server..."
New-Item -ItemType Directory -Path "C:\etc\nomad.d" -Force | Out-Null
$nomadConfig = @"
datacenter = "dc1"
data_dir = "C:/opt/nomad/data"
log_level = "INFO"
bind_addr = "0.0.0.0"

server {
  enabled = true
  bootstrap_expect = $serverCount
}

consul {
  address = "127.0.0.1:8500"
}

telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}
"@

$nomadConfig | Out-File -FilePath "C:\etc\nomad.d\nomad.hcl" -Encoding UTF8

# Adjust Nomad service parameters to correct config dir (was C:\opt\nomad\config in AMI)
Write-Host "Configuring Nomad service parameters for C:\\etc\\nomad.d ..."
nssm set Nomad AppParameters "agent -config=C:\\etc\\nomad.d"
nssm set Nomad Start SERVICE_AUTO_START
Write-Host "Restarting Nomad service..."
if (Get-Service -Name "Nomad" -ErrorAction SilentlyContinue) { Stop-Service Nomad -Force -ErrorAction SilentlyContinue }
Start-Service -Name "Nomad"
Start-Sleep -Seconds 5

Write-Host "Server configuration completed successfully."
</powershell>
