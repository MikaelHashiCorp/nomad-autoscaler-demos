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

# Install and configure OpenSSH Server for remote administration
Write-Log "Installing OpenSSH Server..."
try {
    # Use Chocolatey to install OpenSSH (more reliable than Windows Capability)
    choco install -y openssh --package-parameters="/SSHServerFeature"
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    # Wait a moment for installation to complete
    Start-Sleep -Seconds 5
    
    # Start the sshd service
    Start-Service sshd -ErrorAction SilentlyContinue
    
    # Set the service to start automatically
    Set-Service -Name sshd -StartupType 'Automatic' -ErrorAction SilentlyContinue
    
    # Ensure firewall rule exists for SSH
    if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    }
    
    Write-Log "OpenSSH Server installed and configured successfully"
} catch {
    Write-Log "Warning: OpenSSH Server installation encountered issues: $_"
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

# Install NSSM (Non-Sucking Service Manager) for better Windows service management
Write-Log "Installing NSSM (service manager)..."
try {
    choco install -y nssm
    Write-Log "NSSM installed successfully"
} catch {
    Write-Log "Warning: NSSM installation failed: $_"
}

# Refresh PATH to include NSSM
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Create Windows Services for Consul and Nomad using NSSM
Write-Log "Creating Windows services for Consul and Nomad..."

# Create directory for service logs
New-Item -ItemType Directory -Force -Path "C:\opt\consul\logs" | Out-Null
New-Item -ItemType Directory -Force -Path "C:\opt\nomad\logs" | Out-Null

# Create Consul Windows Service
try {
    # Remove service if it exists
    $consulService = Get-Service -Name "Consul" -ErrorAction SilentlyContinue
    if ($consulService) {
        Write-Log "Removing existing Consul service..."
        & nssm stop Consul
        Start-Sleep -Seconds 2
        & nssm remove Consul confirm
        Start-Sleep -Seconds 2
    }
    
    # Install Consul service with NSSM
    Write-Log "Installing Consul service with NSSM..."
    & nssm install Consul "C:\opt\consul\consul.exe"
    & nssm set Consul AppDirectory "C:\opt\consul"
    & nssm set Consul AppParameters "agent -config-dir=C:\opt\consul\config -data-dir=C:\opt\consul\data"
    & nssm set Consul DisplayName "HashiCorp Consul"
    & nssm set Consul Description "HashiCorp Consul agent for service discovery and configuration"
    & nssm set Consul Start SERVICE_DEMAND_START
    & nssm set Consul AppStdout "C:\opt\consul\logs\consul-stdout.log"
    & nssm set Consul AppStderr "C:\opt\consul\logs\consul-stderr.log"
    & nssm set Consul AppRotateFiles 1
    & nssm set Consul AppRotateBytes 10485760
    
    Write-Log "Consul service created successfully"
} catch {
    Write-Log "Warning: Failed to create Consul service: $_"
}

# Create Nomad Windows Service
try {
    # Remove service if it exists
    $nomadService = Get-Service -Name "Nomad" -ErrorAction SilentlyContinue
    if ($nomadService) {
        Write-Log "Removing existing Nomad service..."
        & nssm stop Nomad
        Start-Sleep -Seconds 2
        & nssm remove Nomad confirm
        Start-Sleep -Seconds 2
    }
    
    # Install Nomad service with NSSM
    Write-Log "Installing Nomad service with NSSM..."
    & nssm install Nomad "C:\opt\nomad\nomad.exe"
    & nssm set Nomad AppDirectory "C:\opt\nomad"
    & nssm set Nomad AppParameters "agent -config=C:\opt\nomad\config"
    & nssm set Nomad DisplayName "HashiCorp Nomad"
    & nssm set Nomad Description "HashiCorp Nomad workload orchestrator"
    & nssm set Nomad Start SERVICE_DEMAND_START
    & nssm set Nomad AppStdout "C:\opt\nomad\logs\nomad-stdout.log"
    & nssm set Nomad AppStderr "C:\opt\nomad\logs\nomad-stderr.log"
    & nssm set Nomad AppRotateFiles 1
    & nssm set Nomad AppRotateBytes 10485760
    
    Write-Log "Nomad service created successfully"
} catch {
    Write-Log "Warning: Failed to create Nomad service: $_"
}

# Configure EC2Launch V2 to run user data on every boot
Write-Log "Configuring EC2Launch V2 to execute user data on every boot..."
try {
    # EC2Launch V2 reads agent-config.yml from C:\ProgramData\Amazon\EC2Launch\config\
    # The executeScript task with frequency: always ensures user data runs on every boot
    # Reference: https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch-v2-settings.html
    
    $configDir = "C:\ProgramData\Amazon\EC2Launch\config"
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    }
    
    # Create agent-config.yml with AWS-documented YAML structure
    # CRITICAL: The 'frequency' property must be at the task input level
    $agentConfigPath = "$configDir\agent-config.yml"
    $agentConfig = @"
version: 1.1
config:
- stage: boot
  tasks:
  - task: executeScript
    inputs:
    - frequency: always
      type: powershell
      runAs: localSystem
"@
    
    $agentConfig | Set-Content -Path $agentConfigPath -Force
    Write-Log "Created EC2Launch V2 agent-config.yml"
    Write-Log "Configuration: executeScript frequency = always"
    Write-Log "Path: $agentConfigPath"
    
} catch {
    Write-Log "Warning: Failed to configure EC2Launch for repeated user data execution: $_"
}

Write-Log "Windows setup.ps1 completed successfully"
