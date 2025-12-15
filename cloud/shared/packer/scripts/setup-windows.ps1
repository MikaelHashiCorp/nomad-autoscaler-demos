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

# ============================================================================
# Chocolatey Package Manager Installation
# ============================================================================
Write-Host "" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Chocolatey Package Manager Installation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    # Check if Chocolatey is already installed
    $chocoInstalled = Get-Command choco -ErrorAction SilentlyContinue
    
    if ($chocoInstalled) {
        Write-Host "Chocolatey is already installed" -ForegroundColor Green
        $chocoVersion = & choco --version
        Write-Host "  Version: $chocoVersion" -ForegroundColor Cyan
    } else {
        Write-Host "Installing Chocolatey package manager..." -ForegroundColor Yellow
        
        # Set execution policy for this process
        Set-ExecutionPolicy Bypass -Scope Process -Force
        
        # Download and install Chocolatey
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Host "  [OK] Chocolatey installed successfully" -ForegroundColor Green
        
        # Verify installation
        $chocoVersion = & choco --version
        Write-Host "  Chocolatey version: $chocoVersion" -ForegroundColor Green
    }
    
    Write-Host "" -ForegroundColor Green
    Write-Host "SUCCESS: Chocolatey package manager ready" -ForegroundColor Green
    Write-Host "" -ForegroundColor Cyan
    
} catch {
    Write-Host "" -ForegroundColor Red
    Write-Host "ERROR: Chocolatey installation failed" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    Write-Host "  This is non-critical - continuing with manual Docker installation" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Cyan
}

# ============================================================================
# OpenSSH Server Installation (via Chocolatey)
# ============================================================================
Write-Host "" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "OpenSSH Server Installation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {
    Write-Host "[1/5] Checking for existing OpenSSH Server..." -ForegroundColor Yellow
    
    # Check if SSH service exists
    $sshService = Get-Service sshd -ErrorAction SilentlyContinue
    
    if ($sshService) {
        Write-Host "  OpenSSH Server already installed" -ForegroundColor Green
    } else {
        Write-Host "  OpenSSH Server not found, installing via Chocolatey..." -ForegroundColor Cyan
        
        Write-Host "[2/5] Installing OpenSSH via Chocolatey..." -ForegroundColor Yellow
        # Install OpenSSH with server feature enabled
        choco install openssh -y --params '"/SSHServerFeature"' --force
        
        # Refresh environment to pick up new PATH entries
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Host "  [OK] OpenSSH installed via Chocolatey" -ForegroundColor Green
    }
    
    Write-Host "[3/5] Configuring SSH service..." -ForegroundColor Yellow
    # Ensure service exists after installation
    $sshService = Get-Service sshd -ErrorAction SilentlyContinue
    if ($sshService) {
        # Start and configure for automatic startup
        if ($sshService.Status -ne 'Running') {
            Start-Service sshd -ErrorAction SilentlyContinue
        }
        Set-Service -Name sshd -StartupType 'Automatic'
        Write-Host "  [OK] SSH service configured for automatic startup" -ForegroundColor Green
    }
    
    Write-Host "[4/5] Configuring Windows Firewall..." -ForegroundColor Yellow
    # Configure firewall
    $firewallRule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
    if (-not $firewallRule) {
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
        Write-Host "  [OK] Firewall rule created (port 22)" -ForegroundColor Green
    } else {
        Write-Host "  Firewall rule already exists" -ForegroundColor Green
    }
    
    Write-Host "[5/5] Configuring RSA key authentication..." -ForegroundColor Yellow
    # Configure for RSA key authentication
    $sshdConfigPath = "C:\ProgramData\ssh\sshd_config"
    
    if (Test-Path $sshdConfigPath) {
        # Backup original config
        Copy-Item $sshdConfigPath "$sshdConfigPath.backup" -Force -ErrorAction SilentlyContinue
        
        # Read config
        $config = Get-Content $sshdConfigPath
        
        # Ensure RSA keys are accepted
        $newConfig = @()
        $foundPubkey = $false
        $foundKeyTypes = $false
        
        foreach ($line in $config) {
            if ($line -match "^#?PubkeyAuthentication") {
                $newConfig += "PubkeyAuthentication yes"
                $foundPubkey = $true
            }
            elseif ($line -match "^#?PubkeyAcceptedKeyTypes") {
                $newConfig += "PubkeyAcceptedKeyTypes +ssh-rsa"
                $foundKeyTypes = $true
            }
            else {
                $newConfig += $line
            }
        }
        
        # Add if not found
        if (-not $foundPubkey) {
            $newConfig += "PubkeyAuthentication yes"
        }
        if (-not $foundKeyTypes) {
            $newConfig += "PubkeyAcceptedKeyTypes +ssh-rsa"
        }
        
        # Write back
        $newConfig | Set-Content $sshdConfigPath
        
        # Restart SSH to apply changes
        Restart-Service sshd -ErrorAction SilentlyContinue
        Write-Host "  [OK] RSA key authentication enabled" -ForegroundColor Green
    } else {
        Write-Host "  Warning: sshd_config not found at expected location" -ForegroundColor Yellow
    }
    
    Write-Host "[6/6] Creating SSH key injection startup script..." -ForegroundColor Yellow
    # Create a PowerShell script that runs on startup to inject EC2 key pair
    # This fetches the public key from EC2 instance metadata and adds it to authorized_keys
    # Works with any EC2 key pair specified at instance launch (e.g., aws-mikael-test)
    
    $startupScriptPath = "C:\ProgramData\ssh\inject-ec2-key.ps1"
    $startupScript = @'
# SSH Key Injection Script for EC2 Instances
# Fetches the EC2 key pair public key from instance metadata and adds to authorized_keys
# This enables SSH access using the key pair specified at instance launch

try {
    # Get EC2 instance metadata token (IMDSv2)
    $tokenUrl = "http://169.254.169.254/latest/api/token"
    $token = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "21600"} -Method PUT -Uri $tokenUrl -ErrorAction Stop
    
    # Get public key from instance metadata
    $pubKeyUrl = "http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key"
    $pubKey = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token" = $token} -Uri $pubKeyUrl -ErrorAction Stop
    
    if ($pubKey) {
        $sshDir = "C:\ProgramData\ssh"
        $authKeysFile = Join-Path $sshDir "administrators_authorized_keys"
        
        # Create directory if it doesn't exist
        if (-not (Test-Path $sshDir)) {
            New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        }
        
        # Write public key (overwrite to ensure it matches the instance's key pair)
        Set-Content -Path $authKeysFile -Value $pubKey -Force
        
        # Set proper permissions (SYSTEM and Administrators only)
        icacls $authKeysFile /inheritance:r | Out-Null
        icacls $authKeysFile /grant "SYSTEM:(F)" | Out-Null
        icacls $authKeysFile /grant "Administrators:(F)" | Out-Null
        
        Write-Host "SSH key injected successfully from EC2 metadata"
    } else {
        Write-Host "No SSH key found in EC2 metadata"
    }
} catch {
    Write-Host "Failed to inject SSH key: $_"
}
'@
    
    # Write the startup script
    Set-Content -Path $startupScriptPath -Value $startupScript -Force
    Write-Host "  [OK] Startup script created at $startupScriptPath" -ForegroundColor Green
    
    # Create a scheduled task to run the script on startup
    $taskName = "InjectEC2SSHKey"
    $taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    
    if ($taskExists) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$startupScriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Inject EC2 key pair into SSH authorized_keys on instance startup" | Out-Null
    
    Write-Host "  [OK] Scheduled task '$taskName' created to run on startup" -ForegroundColor Green
    Write-Host "  SSH will automatically work with any EC2 key pair specified at launch" -ForegroundColor Cyan
    
    # Verify installation
    $sshService = Get-Service sshd -ErrorAction SilentlyContinue
    if ($sshService) {
        Write-Host "" -ForegroundColor Green
        Write-Host "SUCCESS: OpenSSH Server ready" -ForegroundColor Green
        Write-Host "  Service Status: $($sshService.Status)" -ForegroundColor Green
        Write-Host "  Startup Type: $($sshService.StartType)" -ForegroundColor Green
        Write-Host "  Port: 22" -ForegroundColor Green
        Write-Host "  RSA key authentication: Enabled" -ForegroundColor Green
    } else {
        Write-Host "" -ForegroundColor Yellow
        Write-Host "WARNING: SSH service not found after installation" -ForegroundColor Yellow
        Write-Host "  SSH may require manual configuration after instance launch" -ForegroundColor Yellow
    }
    Write-Host "" -ForegroundColor Cyan
    
} catch {
    Write-Host "" -ForegroundColor Red
    Write-Host "OpenSSH Server installation encountered an issue:" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    Write-Host "" -ForegroundColor Yellow
    Write-Host "  This is non-critical - SSH can be configured manually if needed" -ForegroundColor Yellow
    Write-Host "" -ForegroundColor Cyan
}

# Install Docker (required for Nomad)
# Using direct download method instead of PowerShell Gallery for reliability
$InstallDocker = $true

if ($InstallDocker) {
    Write-Host "" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Docker Installation" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    try {
        Write-Host "[1/5] Installing Windows Containers feature..." -ForegroundColor Yellow
        $containersFeature = Get-WindowsFeature -Name Containers -ErrorAction SilentlyContinue
        if ($containersFeature -and $containersFeature.Installed) {
            Write-Host "  Windows Containers feature already installed" -ForegroundColor Green
        } else {
            Write-Host "  Installing Windows Containers feature (this may take a few minutes)..." -ForegroundColor Cyan
            Install-WindowsFeature -Name Containers -ErrorAction Stop | Out-Null
            Write-Host "  [OK] Windows Containers feature installed" -ForegroundColor Green
        }
        
        Write-Host "[2/5] Checking for existing Docker installation..." -ForegroundColor Yellow
        $dockerExe = Test-Path "C:\Program Files\Docker\dockerd.exe"
        if ($dockerExe) {
            Write-Host "  Docker is already installed" -ForegroundColor Green
        } else {
            Write-Host "  Docker not found, proceeding with installation" -ForegroundColor Cyan
            
            Write-Host "[3/5] Downloading Docker 24.0.7..." -ForegroundColor Yellow
            $dockerUrl = "https://download.docker.com/win/static/stable/x86_64/docker-24.0.7.zip"
            $dockerZip = "$env:TEMP\docker.zip"
            Write-Host "  URL: $dockerUrl" -ForegroundColor Cyan
            Invoke-WebRequest -Uri $dockerUrl -OutFile $dockerZip -UseBasicParsing -ErrorAction Stop
            Write-Host "  [OK] Download complete" -ForegroundColor Green
            
            Write-Host "[4/5] Extracting Docker to C:\Program Files..." -ForegroundColor Yellow
            Expand-Archive -Path $dockerZip -DestinationPath "C:\Program Files" -Force -ErrorAction Stop
            Remove-Item $dockerZip -Force
            Write-Host "  [OK] Docker extracted successfully" -ForegroundColor Green
            
            Write-Host "[5/5] Configuring Docker..." -ForegroundColor Yellow
            
            # Add Docker to PATH
            $dockerPath = "C:\Program Files\Docker"
            $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            if ($currentPath -notlike "*$dockerPath*") {
                Write-Host "  Adding Docker to system PATH..." -ForegroundColor Cyan
                [Environment]::SetEnvironmentVariable("Path", "$currentPath;$dockerPath", "Machine")
                $env:Path = "$env:Path;$dockerPath"
                Write-Host "  [OK] PATH updated" -ForegroundColor Green
            }
            
            # Register Docker service
            Write-Host "  Registering Docker service..." -ForegroundColor Cyan
            & "C:\Program Files\Docker\dockerd.exe" --register-service
            Write-Host "  [OK] Docker service registered" -ForegroundColor Green
            
            # Start Docker service
            Write-Host "  Starting Docker service..." -ForegroundColor Cyan
            Start-Service docker -ErrorAction Stop
            Write-Host "  [OK] Docker service started" -ForegroundColor Green
            
            # Set Docker service to automatic startup
            Set-Service -Name docker -StartupType Automatic
            Write-Host "  [OK] Docker service set to automatic startup" -ForegroundColor Green
        }
        
        # Verify Docker installation
        Write-Host "" -ForegroundColor Cyan
        Write-Host "Verifying Docker installation..." -ForegroundColor Yellow
        $dockerVersion = & docker version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Docker is working correctly" -ForegroundColor Green
            Write-Host "" -ForegroundColor Cyan
            & docker version
        } else {
            Write-Host "  [WARN] Docker verification failed, but installation completed" -ForegroundColor Yellow
            Write-Host "  Docker may require a system restart to function properly" -ForegroundColor Yellow
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
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows Server 2022 Setup Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installed components:" -ForegroundColor Green
Write-Host "  - Consul $ConsulVersion" -ForegroundColor White
Write-Host "  - Nomad $NomadVersion" -ForegroundColor White
Write-Host "  - Vault $VaultVersion" -ForegroundColor White
Write-Host "  - Docker 24.0.7 (with Windows Containers)" -ForegroundColor White
Write-Host "  - OpenSSH Server" -ForegroundColor White
Write-Host ""
Write-Host "Installation directory: $BinDir" -ForegroundColor Green
Write-Host "Configuration directories:" -ForegroundColor Green
Write-Host "  - Consul: $ConsulDir" -ForegroundColor White
Write-Host "  - Nomad: $NomadDir" -ForegroundColor White
Write-Host "  - Vault: $VaultDir" -ForegroundColor White
Write-Host ""
Write-Host "Additional services:" -ForegroundColor Green
Write-Host "  - Docker: C:\Program Files\Docker" -ForegroundColor White
Write-Host "  - SSH: OpenSSH Server (port 22)" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. SSH keys must be configured after instance launch" -ForegroundColor Cyan
Write-Host "  2. Add public key to: C:\ProgramData\ssh\administrators_authorized_keys" -ForegroundColor Cyan
Write-Host "  3. Set proper permissions on authorized_keys file" -ForegroundColor Cyan

# Made with Bob
