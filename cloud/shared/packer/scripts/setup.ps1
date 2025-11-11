# Windows Setup Script for HashiStack
# Installs Consul, Nomad, Vault, and CNI plugins on Windows Server

# Error handling
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Logging function
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $logMessage = "$timestamp $Message"
    Write-Host $logMessage
    Add-Content -Path "C:\provision.log" -Value $logMessage
}

Write-Log "Starting Windows setup.ps1"

# Get versions from environment variables (passed from Packer)
$CONSULVERSION = $env:CONSULVERSION
$NOMADVERSION = $env:NOMADVERSION
$CNIVERSION = $env:CNIVERSION

Write-Log "Consul Version: $CONSULVERSION"
Write-Log "Nomad Version: $NOMADVERSION"
Write-Log "CNI Version: $CNIVERSION"

# Define directories
$CONFIGDIR = "C:\ops\config"
$SCRIPTDIR = "C:\ops\scripts"
$CONSULDIR = "C:\opt\consul"
$CONSULCONFIGDIR = "C:\etc\consul.d"
$NOMADDIR = "C:\opt\nomad"
$NOMADCONFIGDIR = "C:\etc\nomad.d"
$CNIDIR = "C:\opt\cni\bin"

# Create directories
Write-Log "Creating directories..."
New-Item -ItemType Directory -Force -Path $CONSULDIR | Out-Null
New-Item -ItemType Directory -Force -Path $CONSULCONFIGDIR | Out-Null
New-Item -ItemType Directory -Force -Path $NOMADDIR | Out-Null
New-Item -ItemType Directory -Force -Path $NOMADCONFIGDIR | Out-Null
New-Item -ItemType Directory -Force -Path $CNIDIR | Out-Null
New-Item -ItemType Directory -Force -Path "C:\tmp" | Out-Null

# Install Chocolatey (package manager for Windows)
Write-Log "Installing Chocolatey..."
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Install basic tools
Write-Log "Installing basic tools via Chocolatey..."
choco install -y 7zip curl wget jq git

# Refresh PATH again after installations
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Download and install Consul
Write-Log "Downloading Consul..."
$CONSULDOWNLOAD = "https://releases.hashicorp.com/consul/${CONSULVERSION}/consul_${CONSULVERSION}_windows_amd64.zip"
Write-Log "CONSULDOWNLOAD=${CONSULDOWNLOAD}"

Invoke-WebRequest -Uri $CONSULDOWNLOAD -OutFile "C:\tmp\consul.zip"
Expand-Archive -Path "C:\tmp\consul.zip" -DestinationPath $CONSULDIR -Force
Remove-Item "C:\tmp\consul.zip"

# Add Consul to PATH
[Environment]::SetEnvironmentVariable("Path", "$env:Path;$CONSULDIR", [EnvironmentVariableTarget]::Machine)
$env:Path += ";$CONSULDIR"

# Copy Consul configuration files (Windows-specific)
Write-Log "Copying Consul configuration..."
if (Test-Path "$CONFIGDIR\consul_windows.hcl") {
    Copy-Item "$CONFIGDIR\consul_windows.hcl" -Destination "$CONSULCONFIGDIR\consul.hcl"
}
if (Test-Path "$CONFIGDIR\consul_client_windows.hcl") {
    Copy-Item "$CONFIGDIR\consul_client_windows.hcl" -Destination "$CONSULCONFIGDIR\consul_client.hcl"
}

# Download and install Nomad
Write-Log "Downloading Nomad..."
$NOMADDOWNLOAD = "https://releases.hashicorp.com/nomad/${NOMADVERSION}/nomad_${NOMADVERSION}_windows_amd64.zip"
Write-Log "NOMADDOWNLOAD=${NOMADDOWNLOAD}"

Invoke-WebRequest -Uri $NOMADDOWNLOAD -OutFile "C:\tmp\nomad.zip"
Expand-Archive -Path "C:\tmp\nomad.zip" -DestinationPath $NOMADDIR -Force
Remove-Item "C:\tmp\nomad.zip"

# Add Nomad to PATH
[Environment]::SetEnvironmentVariable("Path", "$env:Path;$NOMADDIR", [EnvironmentVariableTarget]::Machine)
$env:Path += ";$NOMADDIR"

# Copy Nomad configuration files (Windows-specific)
Write-Log "Copying Nomad configuration..."
if (Test-Path "$CONFIGDIR\nomad_windows.hcl") {
    Copy-Item "$CONFIGDIR\nomad_windows.hcl" -Destination "$NOMADCONFIGDIR\nomad.hcl"
}
if (Test-Path "$CONFIGDIR\nomad_client_windows.hcl") {
    Copy-Item "$CONFIGDIR\nomad_client_windows.hcl" -Destination "$NOMADCONFIGDIR\nomad_client.hcl"
}

# Download and install CNI plugins
Write-Log "Downloading CNI plugins..."
$CNIDOWNLOAD = "https://github.com/containernetworking/plugins/releases/download/${CNIVERSION}/cni-plugins-windows-amd64-${CNIVERSION}.tgz"
Write-Log "CNIDOWNLOAD=${CNIDOWNLOAD}"

try {
    Invoke-WebRequest -Uri $CNIDOWNLOAD -OutFile "C:\tmp\cni-plugins.tgz"
    
    # Extract using 7zip (tar.gz extraction on Windows)
    & "C:\Program Files\7-Zip\7z.exe" x "C:\tmp\cni-plugins.tgz" -o"C:\tmp" -y
    & "C:\Program Files\7-Zip\7z.exe" x "C:\tmp\cni-plugins.tar" -o"$CNIDIR" -y
    
    Remove-Item "C:\tmp\cni-plugins.tgz"
    Remove-Item "C:\tmp\cni-plugins.tar"
} catch {
    Write-Log "Warning: Failed to download CNI plugins for Windows. CNI plugins may not be available for Windows."
}

# Install Docker (required for Nomad container tasks)
Write-Log "Installing Docker..."
try {
    # Install Docker using the Microsoft provider
    Install-WindowsFeature -Name Containers
    
    # Download Docker
    Invoke-WebRequest -UseBasicParsing "https://download.docker.com/components/engine/windows-server/index.json" | ConvertFrom-Json | Select-Object -First 1 -ExpandProperty url | ForEach-Object {
        Invoke-WebRequest -UseBasicParsing -OutFile "C:\tmp\docker.zip" $_
    }
    
    # Extract Docker
    Expand-Archive "C:\tmp\docker.zip" -DestinationPath $env:ProgramFiles -Force
    
    # Add Docker to PATH
    [Environment]::SetEnvironmentVariable("Path", "$env:Path;$env:ProgramFiles\docker", [EnvironmentVariableTarget]::Machine)
    $env:Path += ";$env:ProgramFiles\docker"
    
    # Register Docker as a service
    & dockerd --register-service
    
    # Start Docker service
    Start-Service docker
    
    Remove-Item "C:\tmp\docker.zip"
    
    Write-Log "Docker installed successfully"
} catch {
    Write-Log "Warning: Docker installation encountered issues: $_"
}

# Configure Windows Firewall for HashiCorp services
Write-Log "Configuring Windows Firewall..."

# Consul ports
New-NetFirewallRule -DisplayName "Consul HTTP" -Direction Inbound -LocalPort 8500 -Protocol TCP -Action Allow | Out-Null
New-NetFirewallRule -DisplayName "Consul DNS" -Direction Inbound -LocalPort 8600 -Protocol TCP -Action Allow | Out-Null
New-NetFirewallRule -DisplayName "Consul DNS UDP" -Direction Inbound -LocalPort 8600 -Protocol UDP -Action Allow | Out-Null
New-NetFirewallRule -DisplayName "Consul Serf LAN" -Direction Inbound -LocalPort 8301 -Protocol TCP -Action Allow | Out-Null
New-NetFirewallRule -DisplayName "Consul Serf LAN UDP" -Direction Inbound -LocalPort 8301 -Protocol UDP -Action Allow | Out-Null
New-NetFirewallRule -DisplayName "Consul Serf WAN" -Direction Inbound -LocalPort 8302 -Protocol TCP -Action Allow | Out-Null
New-NetFirewallRule -DisplayName "Consul Serf WAN UDP" -Direction Inbound -LocalPort 8302 -Protocol UDP -Action Allow | Out-Null
New-NetFirewallRule -DisplayName "Consul Server RPC" -Direction Inbound -LocalPort 8300 -Protocol TCP -Action Allow | Out-Null

# Nomad ports
New-NetFirewallRule -DisplayName "Nomad HTTP" -Direction Inbound -LocalPort 4646 -Protocol TCP -Action Allow | Out-Null
New-NetFirewallRule -DisplayName "Nomad RPC" -Direction Inbound -LocalPort 4647 -Protocol TCP -Action Allow | Out-Null
New-NetFirewallRule -DisplayName "Nomad Serf" -Direction Inbound -LocalPort 4648 -Protocol TCP -Action Allow | Out-Null
New-NetFirewallRule -DisplayName "Nomad Serf UDP" -Direction Inbound -LocalPort 4648 -Protocol UDP -Action Allow | Out-Null

# Dynamic port range for Nomad tasks
New-NetFirewallRule -DisplayName "Nomad Dynamic Ports" -Direction Inbound -LocalPort 20000-32000 -Protocol TCP -Action Allow | Out-Null

Write-Log "Windows setup.ps1 completed successfully"
