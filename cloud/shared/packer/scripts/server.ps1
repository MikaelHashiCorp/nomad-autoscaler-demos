# Windows Server Configuration for Consul and Nomad
# Configures this instance as a Consul/Nomad server

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $logMessage = "$timestamp $Message"
    Write-Host $logMessage
    Add-Content -Path "C:\provision.log" -Value $logMessage
}

Write-Log "Starting Windows server.ps1"

# Install Consul as a Windows Service
Write-Log "Installing Consul as a Windows service..."

$consulService = Get-Service -Name "Consul" -ErrorAction SilentlyContinue
if ($consulService) {
    Write-Log "Consul service already exists, stopping..."
    Stop-Service -Name "Consul" -Force
    & sc.exe delete "Consul"
}

# Create Consul service using NSSM (Non-Sucking Service Manager)
choco install -y nssm

$consulExe = "C:\opt\consul\consul.exe"
$consulConfig = "C:\etc\consul.d"

& nssm install Consul $consulExe "agent" "-config-dir=$consulConfig"
& nssm set Consul AppDirectory "C:\opt\consul"
& nssm set Consul DisplayName "HashiCorp Consul"
& nssm set Consul Description "HashiCorp Consul service discovery and configuration"
& nssm set Consul Start SERVICE_AUTO_START
& nssm set Consul AppStdout "C:\opt\consul\consul.log"
& nssm set Consul AppStderr "C:\opt\consul\consul-error.log"

Write-Log "Starting Consul service..."
Start-Service -Name "Consul"

# Install Nomad as a Windows Service
Write-Log "Installing Nomad as a Windows service..."

$nomadService = Get-Service -Name "Nomad" -ErrorAction SilentlyContinue
if ($nomadService) {
    Write-Log "Nomad service already exists, stopping..."
    Stop-Service -Name "Nomad" -Force
    & sc.exe delete "Nomad"
}

$nomadExe = "C:\opt\nomad\nomad.exe"
$nomadConfig = "C:\etc\nomad.d"

& nssm install Nomad $nomadExe "agent" "-config=$nomadConfig"
& nssm set Nomad AppDirectory "C:\opt\nomad"
& nssm set Nomad DisplayName "HashiCorp Nomad"
& nssm set Nomad Description "HashiCorp Nomad cluster scheduler"
& nssm set Nomad Start SERVICE_AUTO_START
& nssm set Nomad AppStdout "C:\opt\nomad\nomad.log"
& nssm set Nomad AppStderr "C:\opt\nomad\nomad-error.log"

Write-Log "Starting Nomad service..."
Start-Service -Name "Nomad"

Write-Log "Windows server.ps1 completed successfully"
