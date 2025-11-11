# Windows Client Configuration for Nomad
# Configures this instance as a Nomad client

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $logMessage = "$timestamp $Message"
    Write-Host $logMessage
    Add-Content -Path "C:\provision.log" -Value $logMessage
}

Write-Log "Starting Windows client.ps1"

# Install Consul as a Windows Service (client mode)
Write-Log "Installing Consul as a Windows service (client mode)..."

$consulService = Get-Service -Name "Consul" -ErrorAction SilentlyContinue
if ($consulService) {
    Write-Log "Consul service already exists, stopping..."
    Stop-Service -Name "Consul" -Force
    & sc.exe delete "Consul"
}

# Create Consul service using NSSM (Non-Sucking Service Manager)
$nssmInstalled = Get-Command nssm -ErrorAction SilentlyContinue
if (-not $nssmInstalled) {
    choco install -y nssm
}

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

# Install Nomad as a Windows Service (client mode)
Write-Log "Installing Nomad as a Windows service (client mode)..."

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

# Set environment variable for Nomad plugin directory
[Environment]::SetEnvironmentVariable("NOMAD_PLUGIN_DIR", "C:\opt\cni\bin", [EnvironmentVariableTarget]::Machine)

Write-Log "Starting Nomad service..."
Start-Service -Name "Nomad"

# Verify Docker is running (required for container tasks)
$dockerService = Get-Service -Name "docker" -ErrorAction SilentlyContinue
if ($dockerService) {
    if ($dockerService.Status -ne "Running") {
        Write-Log "Starting Docker service..."
        Start-Service -Name "docker"
    }
    Write-Log "Docker service is running"
} else {
    Write-Log "Warning: Docker service not found. Container tasks may not work."
}

Write-Log "Windows client.ps1 completed successfully"
