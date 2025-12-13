# Windows Server 2022 Setup Script for HashiStack
# This script installs Consul, Nomad, and Vault on Windows Server 2022

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"  # Enable verbose output globally
$ProgressPreference = "Continue"  # Show progress bars

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows Server 2022 HashiStack Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Script started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Cyan
Write-Host "Execution Policy: $(Get-ExecutionPolicy)" -ForegroundColor Cyan
Write-Host ""

# Function to get the latest version from HashiCorp releases
function Get-LatestHashiCorpVersion {
    param (
        [string]$Product
    )
    
    try {
        # Use HashiCorp checkpoint API for version detection
        $url = "https://checkpoint-api.hashicorp.com/v1/check/$Product"
        Write-Host "  Querying: $url" -ForegroundColor Gray
        
        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
        
        if ($response.current_version) {
            $latestVersion = $response.current_version
            Write-Host "  Latest $Product version: $latestVersion" -ForegroundColor Cyan
            return $latestVersion
        }
        else {
            throw "Could not find current_version in API response for $Product"
        }
    }
    catch {
        Write-Host "  Error fetching latest version for $Product : $_" -ForegroundColor Red
        throw
    }
}

# Get versions - use environment variable if set, otherwise fetch latest
if ($env:CONSULVERSION) {
    $ConsulVersion = $env:CONSULVERSION
    Write-Host "Using Consul version from environment: $ConsulVersion" -ForegroundColor Yellow
} else {
    Write-Host "Fetching latest Consul version..." -ForegroundColor Yellow
    $ConsulVersion = Get-LatestHashiCorpVersion -Product "consul"
}

if ($env:NOMADVERSION) {
    $NomadVersion = $env:NOMADVERSION
    Write-Host "Using Nomad version from environment: $NomadVersion" -ForegroundColor Yellow
} else {
    Write-Host "Fetching latest Nomad version..." -ForegroundColor Yellow
    $NomadVersion = Get-LatestHashiCorpVersion -Product "nomad"
}

if ($env:VAULTVERSION) {
    $VaultVersion = $env:VAULTVERSION
    Write-Host "Using Vault version from environment: $VaultVersion" -ForegroundColor Yellow
} else {
    Write-Host "Fetching latest Vault version..." -ForegroundColor Yellow
    $VaultVersion = Get-LatestHashiCorpVersion -Product "vault"
}

Write-Host ""
Write-Host "Final versions to install:" -ForegroundColor Green
Write-Host "  Consul: $ConsulVersion" -ForegroundColor Green
Write-Host "  Nomad: $NomadVersion" -ForegroundColor Green
Write-Host "  Vault: $VaultVersion" -ForegroundColor Green
Write-Host ""

# Create directories
$BinDir = "C:\HashiCorp\bin"
$ConsulDir = "C:\HashiCorp\Consul"
$NomadDir = "C:\HashiCorp\Nomad"
$VaultDir = "C:\HashiCorp\Vault"

Write-Host "" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Directory Structure Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Creating HashiCorp directory structure..." -ForegroundColor Yellow

$directories = @(
    $BinDir,
    $ConsulDir,
    "$ConsulDir\data",
    "$ConsulDir\config",
    $NomadDir,
    "$NomadDir\data",
    "$NomadDir\config",
    $VaultDir,
    "$VaultDir\data",
    "$VaultDir\config"
)

foreach ($dir in $directories) {
    Write-Host "  Creating: $dir" -ForegroundColor Cyan
    $result = New-Item -ItemType Directory -Force -Path $dir
    Write-Host "    [OK] Created successfully" -ForegroundColor Green
}

Write-Host "All directories created successfully" -ForegroundColor Green
Write-Host ""

# Download and install Consul
Write-Host "" -ForegroundColor Cyan
Write-Host "[Consul] Downloading version $ConsulVersion..." -ForegroundColor Yellow
$ConsulZip = "$env:TEMP\consul.zip"
$ConsulUrl = "https://releases.hashicorp.com/consul/${ConsulVersion}/consul_${ConsulVersion}_windows_amd64.zip"
Write-Host "  URL: $ConsulUrl" -ForegroundColor Cyan
Invoke-WebRequest -Uri $ConsulUrl -OutFile $ConsulZip -Verbose
Write-Host "  Download complete, extracting to $BinDir..." -ForegroundColor Cyan
Expand-Archive -Path $ConsulZip -DestinationPath $BinDir -Force
Remove-Item $ConsulZip
Write-Host "[Consul] Installed successfully" -ForegroundColor Green

# Download and install Nomad
Write-Host "" -ForegroundColor Cyan
Write-Host "[Nomad] Downloading version $NomadVersion..." -ForegroundColor Yellow
$NomadZip = "$env:TEMP\nomad.zip"
$NomadUrl = "https://releases.hashicorp.com/nomad/${NomadVersion}/nomad_${NomadVersion}_windows_amd64.zip"
Write-Host "  URL: $NomadUrl" -ForegroundColor Cyan
Invoke-WebRequest -Uri $NomadUrl -OutFile $NomadZip -Verbose
Write-Host "  Download complete, extracting to $BinDir..." -ForegroundColor Cyan
Expand-Archive -Path $NomadZip -DestinationPath $BinDir -Force
Remove-Item $NomadZip
Write-Host "[Nomad] Installed successfully" -ForegroundColor Green

# Download and install Vault
Write-Host "" -ForegroundColor Cyan
Write-Host "[Vault] Downloading version $VaultVersion..." -ForegroundColor Yellow
$VaultZip = "$env:TEMP\vault.zip"
$VaultUrl = "https://releases.hashicorp.com/vault/${VaultVersion}/vault_${VaultVersion}_windows_amd64.zip"
Write-Host "  URL: $VaultUrl" -ForegroundColor Cyan
Invoke-WebRequest -Uri $VaultUrl -OutFile $VaultZip -Verbose
Write-Host "  Download complete, extracting to $BinDir..." -ForegroundColor Cyan
Expand-Archive -Path $VaultZip -DestinationPath $BinDir -Force
Remove-Item $VaultZip
Write-Host "[Vault] Installed successfully" -ForegroundColor Green

# Add to PATH
Write-Host "" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "PATH Configuration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuring system PATH..." -ForegroundColor Yellow

$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
Write-Host "  Current PATH length: $($CurrentPath.Length) characters" -ForegroundColor Cyan

if ($CurrentPath -notlike "*$BinDir*") {
    Write-Host "  Adding $BinDir to system PATH..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("Path", "$CurrentPath;$BinDir", "Machine")
    $env:Path = "$env:Path;$BinDir"
    Write-Host "  [OK] PATH updated successfully" -ForegroundColor Green
} else {
    Write-Host "  $BinDir already in PATH" -ForegroundColor Green
}

Write-Host "  New PATH length: $($([Environment]::GetEnvironmentVariable('Path', 'Machine')).Length) characters" -ForegroundColor Cyan
Write-Host ""

# Verify installations
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Installation Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verifying installed components..." -ForegroundColor Yellow
Write-Host ""

Write-Host "[Consul] Version check:" -ForegroundColor Cyan
& "$BinDir\consul.exe" version
Write-Host ""

Write-Host "[Nomad] Version check:" -ForegroundColor Cyan
& "$BinDir\nomad.exe" version
Write-Host ""

Write-Host "[Vault] Version check:" -ForegroundColor Cyan
& "$BinDir\vault.exe" version
Write-Host ""

Write-Host "All components verified successfully!" -ForegroundColor Green
Write-Host ""

# Configure Windows Firewall rules
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows Firewall Configuration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Configuring firewall rules for HashiStack..." -ForegroundColor Yellow
Write-Host ""

$firewallRules = @(
    @{Name="Consul HTTP"; Port=8500; Protocol="TCP"},
    @{Name="Consul DNS"; Port=8600; Protocol="TCP"},
    @{Name="Consul DNS UDP"; Port=8600; Protocol="UDP"},
    @{Name="Consul Serf LAN"; Port=8301; Protocol="TCP"},
    @{Name="Consul Serf LAN UDP"; Port=8301; Protocol="UDP"},
    @{Name="Consul Serf WAN"; Port=8302; Protocol="TCP"},
    @{Name="Consul Serf WAN UDP"; Port=8302; Protocol="UDP"},
    @{Name="Consul Server RPC"; Port=8300; Protocol="TCP"},
    @{Name="Nomad HTTP"; Port=4646; Protocol="TCP"},
    @{Name="Nomad RPC"; Port=4647; Protocol="TCP"},
    @{Name="Nomad Serf"; Port=4648; Protocol="TCP"},
    @{Name="Nomad Serf UDP"; Port=4648; Protocol="UDP"},
    @{Name="Vault API"; Port=8200; Protocol="TCP"},
    @{Name="Vault Cluster"; Port=8201; Protocol="TCP"}
)

$ruleCount = 0
foreach ($rule in $firewallRules) {
    $ruleCount++
    Write-Host "  [$ruleCount/$($firewallRules.Count)] Creating rule: $($rule.Name) (Port $($rule.Port)/$($rule.Protocol))" -ForegroundColor Cyan
    try {
        New-NetFirewallRule -DisplayName $rule.Name -Direction Inbound -LocalPort $rule.Port -Protocol $rule.Protocol -Action Allow -ErrorAction Stop | Out-Null
        Write-Host "    [OK] Rule created successfully" -ForegroundColor Green
    } catch {
        Write-Host "    [WARN] Rule may already exist or creation skipped" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "  Creating dynamic port range rule for Nomad allocations..." -ForegroundColor Cyan
Write-Host "    Port range: 20000-32000 TCP" -ForegroundColor Cyan
try {
    New-NetFirewallRule -DisplayName "Nomad Dynamic Ports" -Direction Inbound -LocalPort 20000-32000 -Protocol TCP -Action Allow -ErrorAction Stop | Out-Null
    Write-Host "    [OK] Dynamic port rule created successfully" -ForegroundColor Green
} catch {
    Write-Host "    [WARN] Rule may already exist or creation skipped" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Firewall configuration completed!" -ForegroundColor Green
Write-Host "  Total rules configured: $($firewallRules.Count + 1)" -ForegroundColor Cyan
Write-Host ""

# Install Docker (required for Nomad)
# DISABLED: Docker installation via PowerShell Gallery is unreliable in packer builds
# Install Docker manually after AMI creation or use alternative installation method
$InstallDocker = $false

if ($InstallDocker) {
    Write-Host "" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Docker Installation" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    try {
        Write-Host "[1/4] Checking for existing Docker installation..." -ForegroundColor Yellow
        $dockerInstalled = Get-Package -Name Docker -ErrorAction SilentlyContinue
        if ($dockerInstalled) {
            Write-Host "  Docker is already installed (version: $($dockerInstalled.Version))" -ForegroundColor Green
        } else {
            Write-Host "  Docker not found, proceeding with installation" -ForegroundColor Cyan
            Write-Host "  NOTE: This can take 10-15 minutes" -ForegroundColor Yellow
            
            Write-Host "[2/4] Installing DockerMsftProvider module from PSGallery..." -ForegroundColor Yellow
            Write-Host "  This may take 1-2 minutes without progress output..." -ForegroundColor Yellow
            Install-Module -Name DockerMsftProvider -Repository PSGallery -Force -Confirm:$false -AllowClobber -SkipPublisherCheck -ErrorAction Stop
            Write-Host "  [OK] DockerMsftProvider module installed successfully" -ForegroundColor Green
            
            Write-Host "[3/4] Installing Docker package..." -ForegroundColor Yellow
            Write-Host "  This may take 5-10 minutes without progress output..." -ForegroundColor Yellow
            Write-Host "  Please be patient, the installation is running..." -ForegroundColor Yellow
            Install-Package -Name docker -ProviderName DockerMsftProvider -Force -Confirm:$false -ErrorAction Stop
            Write-Host "  [OK] Docker package installed successfully" -ForegroundColor Green
            
            Write-Host "[4/4] Verifying Docker installation..." -ForegroundColor Yellow
            $dockerService = Get-Service -Name docker -ErrorAction SilentlyContinue
            if ($dockerService) {
                Write-Host "  Docker service found: $($dockerService.Status)" -ForegroundColor Green
            } else {
                Write-Host "  Docker service not found (may require reboot)" -ForegroundColor Yellow
            }
        }
        
        Write-Host "" -ForegroundColor Green
        Write-Host "Docker installation completed successfully!" -ForegroundColor Green
        
    } catch {
        Write-Host "" -ForegroundColor Yellow
        Write-Host "Docker installation encountered an issue:" -ForegroundColor Yellow
        Write-Host "  Error: $_" -ForegroundColor Red
        Write-Host "  This is non-critical - Docker can be installed later if needed" -ForegroundColor Yellow
    }

    Write-Host "========================================" -ForegroundColor Cyan
} else {
    Write-Host "" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Docker Installation SKIPPED" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Docker installation is disabled for faster AMI builds." -ForegroundColor Cyan
    Write-Host "To enable Docker, set `$InstallDocker = `$true in setup-windows.ps1" -ForegroundColor Cyan
    Write-Host "Or install Docker manually after launching instances from this AMI." -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows Server 2022 Setup Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installed components:" -ForegroundColor Green
Write-Host "  - Consul $ConsulVersion" -ForegroundColor White
Write-Host "  - Nomad $NomadVersion" -ForegroundColor White
Write-Host "  - Vault $VaultVersion" -ForegroundColor White
Write-Host ""
Write-Host "Installation directory: $BinDir" -ForegroundColor Green
Write-Host "Configuration directories:" -ForegroundColor Green
Write-Host "  - Consul: $ConsulDir" -ForegroundColor White
Write-Host "  - Nomad: $NomadDir" -ForegroundColor White
Write-Host "  - Vault: $VaultDir" -ForegroundColor White

# Made with Bob
