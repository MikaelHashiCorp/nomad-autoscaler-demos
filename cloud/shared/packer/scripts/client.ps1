# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Windows Nomad Client Configuration Script
# This script configures Consul and Nomad clients on Windows

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$CloudProvider,
    
    [Parameter(Mandatory=$true)]
    [string]$RetryJoin,
    
    [Parameter(Mandatory=$true)]
    [string]$NodeClass
)

$ErrorActionPreference = "Stop"

# Setup logging
$LogFile = "C:\ProgramData\client-config.log"
Start-Transcript -Path $LogFile -Append

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows Nomad Client Configuration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Cloud Provider: $CloudProvider"
Write-Host "Retry Join: $RetryJoin"
Write-Host "Node Class: $NodeClass"
Write-Host ""

# Directories
$SHAREDDIR = "C:\ops"
$CONFIGDIR = "$SHAREDDIR\config"
$CONSULCONFIGDIR = "C:\HashiCorp\Consul"
$NOMADCONFIGDIR = "C:\HashiCorp\Nomad"

# Get IP Address
Write-Host "Detecting IP address..."
$IP_ADDRESS = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet*" | Where-Object {$_.IPAddress -notlike "169.254.*"} | Select-Object -First 1).IPAddress
Write-Host "  IP Address: $IP_ADDRESS"

# Wait for network to be fully ready
Write-Host "Waiting for network to stabilize..."
Start-Sleep -Seconds 15

#
# Configure Consul Client
#
Write-Host ""
Write-Host "Configuring Consul client..." -ForegroundColor Yellow

# Read and modify Consul client config
$ConsulConfigTemplate = "$CONFIGDIR\consul_client.hcl"
if (-not (Test-Path $ConsulConfigTemplate)) {
    Write-Error "Consul client config template not found: $ConsulConfigTemplate"
    exit 1
}

$ConsulConfig = Get-Content $ConsulConfigTemplate -Raw
$ConsulConfig = $ConsulConfig -replace 'IP_ADDRESS', $IP_ADDRESS
$ConsulConfig = $ConsulConfig -creplace 'RETRY_JOIN', $RetryJoin
$ConsulConfig = $ConsulConfig -replace '/opt/consul/data', 'C:/HashiCorp/Consul/data'
$ConsulConfig = $ConsulConfig -replace '/opt/consul/logs/', 'C:/HashiCorp/Consul/logs/'

# Write Consul config (without BOM to avoid HCL parse errors)
$ConsulConfigFile = "$CONSULCONFIGDIR\consul.hcl"
[System.IO.File]::WriteAllText($ConsulConfigFile, $ConsulConfig, [System.Text.UTF8Encoding]::new($false))
Write-Host "  Consul config written to: $ConsulConfigFile"

# Create Consul service
Write-Host "  Creating Consul Windows service..."
$ConsulBinary = "C:\HashiCorp\bin\consul.exe"
if (-not (Test-Path $ConsulBinary)) {
    Write-Error "Consul binary not found: $ConsulBinary"
    exit 1
}

# Remove existing service if it exists
$existingService = Get-Service -Name "Consul" -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "  Removing existing Consul service..."
    Stop-Service -Name "Consul" -Force -ErrorAction SilentlyContinue
    & sc.exe delete "Consul"
    Start-Sleep -Seconds 2
}

# Create new service
$ConsulArgs = "agent -config-dir=`"$CONSULCONFIGDIR`""
& sc.exe create "Consul" binPath= "`"$ConsulBinary`" $ConsulArgs" start= auto
& sc.exe description "Consul" "HashiCorp Consul Agent"

# Start Consul service
Write-Host "  Starting Consul service..."
Start-Service -Name "Consul"
Start-Sleep -Seconds 10

# Verify Consul is running
$consulService = Get-Service -Name "Consul"
if ($consulService.Status -eq "Running") {
    Write-Host "  [OK] Consul service is running" -ForegroundColor Green
} else {
    Write-Warning "  Consul service status: $($consulService.Status)"
}

#
# Configure Nomad Client
#
Write-Host ""
Write-Host "Configuring Nomad client..." -ForegroundColor Yellow

# Read and modify Nomad client config
$NomadConfigTemplate = "$CONFIGDIR\nomad_client.hcl"
if (-not (Test-Path $NomadConfigTemplate)) {
    Write-Error "Nomad client config template not found: $NomadConfigTemplate"
    exit 1
}

$NomadConfig = Get-Content $NomadConfigTemplate -Raw
$NomadConfig = $NomadConfig -creplace 'NODE_CLASS', "`"$NodeClass`""
$NomadConfig = $NomadConfig -replace '/opt/nomad/data', 'C:/HashiCorp/Nomad/data'
$NomadConfig = $NomadConfig -replace '/opt/nomad/logs/', 'C:/HashiCorp/Nomad/logs/'

# Write Nomad config to the config subdirectory (without BOM to avoid HCL parse errors)
$NomadConfigFile = "$NOMADCONFIGDIR\config\nomad.hcl"
[System.IO.File]::WriteAllText($NomadConfigFile, $NomadConfig, [System.Text.UTF8Encoding]::new($false))
Write-Host "  Nomad config written to: $NomadConfigFile"

# Create Nomad service
Write-Host "  Creating Nomad Windows service..."
$NomadBinary = "C:\HashiCorp\bin\nomad.exe"
if (-not (Test-Path $NomadBinary)) {
    Write-Error "Nomad binary not found: $NomadBinary"
    exit 1
}

# Remove existing service if it exists
$existingService = Get-Service -Name "Nomad" -ErrorAction SilentlyContinue
if ($existingService) {
    Write-Host "  Removing existing Nomad service..."
    Stop-Service -Name "Nomad" -Force -ErrorAction SilentlyContinue
    & sc.exe delete "Nomad"
    Start-Sleep -Seconds 2
}

# Create new service with correct config path
$NomadArgs = "agent -config=`"$NomadConfigFile`""
& sc.exe create "Nomad" binPath= "`"$NomadBinary`" $NomadArgs" start= auto depend= Consul
& sc.exe description "Nomad" "HashiCorp Nomad Agent"

# Start Nomad service
Write-Host "  Starting Nomad service..."
Start-Service -Name "Nomad"
Start-Sleep -Seconds 10

# Verify Nomad is running
$nomadService = Get-Service -Name "Nomad"
if ($nomadService.Status -eq "Running") {
    Write-Host "  [OK] Nomad service is running" -ForegroundColor Green
} else {
    Write-Warning "  Nomad service status: $($nomadService.Status)"
}

# Set environment variable
[Environment]::SetEnvironmentVariable("NOMAD_ADDR", "http://${IP_ADDRESS}:4646", "Machine")

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuration Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Consul Status: $((Get-Service -Name 'Consul').Status)"
Write-Host "Nomad Status:  $((Get-Service -Name 'Nomad').Status)"
Write-Host "Node Class:    $NodeClass"
Write-Host "IP Address:    $IP_ADDRESS"
Write-Host ""
Write-Host "Logs:"
Write-Host "  Client Config: $($LogFile)"
Write-Host '  Consul:        C:\HashiCorp\Consul\logs'
Write-Host '  Nomad:         C:\HashiCorp\Nomad\logs'
Write-Host ""

Stop-Transcript

# Made with Bob
