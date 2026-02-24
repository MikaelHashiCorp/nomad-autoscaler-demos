<powershell>
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Windows User Data Script for Nomad Client
# This script configures a Windows instance as a Nomad client

$ErrorActionPreference = "Stop"

# Setup logging
$LogFile = "C:\ProgramData\user-data.log"
Start-Transcript -Path $LogFile -Append

Write-Host "Starting Windows Nomad Client configuration..."
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# Set environment variables for the client script
$env:NOMAD_BINARY = "${nomad_binary}"
$env:CONSUL_BINARY = "${consul_binary}"

# Verify the client script exists
$ClientScript = "C:\ops\scripts\client.ps1"
if (-not (Test-Path $ClientScript)) {
    Write-Error "Client script not found at $ClientScript"
    exit 1
}

Write-Host "Executing client configuration script..."
Write-Host "  Script: $ClientScript"
Write-Host "  Cloud Provider: aws"
Write-Host "  Retry Join: ${retry_join}"
Write-Host "  Node Class: ${node_class}"

try {
    # Execute the client configuration script
    & PowerShell.exe -ExecutionPolicy Bypass -File $ClientScript `
        -CloudProvider "aws" `
        -RetryJoin "${retry_join}" `
        -NodeClass "${node_class}"
    
    Write-Host "Client configuration completed successfully"
} catch {
    Write-Error "Failed to configure Nomad client: $_"
    exit 1
}

# Optional: Clean up ops directory after successful configuration
# Remove-Item -Path "C:\ops" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Windows Nomad Client user-data script completed"
Stop-Transcript
</powershell>

# Made with Bob
