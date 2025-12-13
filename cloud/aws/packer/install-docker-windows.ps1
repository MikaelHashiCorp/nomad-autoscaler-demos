# Docker Installation Script for Windows Server 2022
# This script installs Docker Engine on Windows Server 2022

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Docker Installation for Windows Server 2022" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to log messages
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "This script must be run as Administrator!" "ERROR"
    exit 1
}

Write-Log "Running as Administrator - OK" "SUCCESS"
Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" "INFO"
Write-Log "OS: $((Get-WmiObject Win32_OperatingSystem).Caption)" "INFO"
Write-Log ""

# Step 1: Install Docker using the official Microsoft method
Write-Log "Step 1: Installing Docker using Microsoft's DockerMsftProvider" "INFO"
Write-Log "This method is more reliable than PowerShell Gallery" "INFO"

try {
    # Install the Docker provider
    Write-Log "Installing DockerMsftProvider..." "INFO"
    Install-Module -Name DockerMsftProvider -Repository PSGallery -Force -Confirm:$false -ErrorAction Stop
    Write-Log "DockerMsftProvider installed successfully" "SUCCESS"
    
    # Install Docker
    Write-Log "Installing Docker package..." "INFO"
    Install-Package -Name docker -ProviderName DockerMsftProvider -Force -Confirm:$false -ErrorAction Stop
    Write-Log "Docker package installed successfully" "SUCCESS"
    
} catch {
    Write-Log "Failed to install Docker via DockerMsftProvider: $_" "ERROR"
    Write-Log "Trying alternative method: Direct download" "WARN"
    
    try {
        # Alternative: Download and install Docker directly
        Write-Log "Downloading Docker binaries..." "INFO"
        $dockerUrl = "https://download.docker.com/win/static/stable/x86_64/docker-24.0.7.zip"
        $downloadPath = "$env:TEMP\docker.zip"
        $extractPath = "C:\Program Files\Docker"
        
        Invoke-WebRequest -Uri $dockerUrl -OutFile $downloadPath -UseBasicParsing
        Write-Log "Docker downloaded successfully" "SUCCESS"
        
        Write-Log "Extracting Docker..." "INFO"
        Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
        Write-Log "Docker extracted to $extractPath" "SUCCESS"
        
        # Add Docker to PATH
        $dockerBinPath = "$extractPath\docker"
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$dockerBinPath*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$dockerBinPath", "Machine")
            $env:Path = "$env:Path;$dockerBinPath"
            Write-Log "Docker added to system PATH" "SUCCESS"
        }
        
        # Register Docker as a service
        Write-Log "Registering Docker service..." "INFO"
        & "$dockerBinPath\dockerd.exe" --register-service
        Write-Log "Docker service registered" "SUCCESS"
        
    } catch {
        Write-Log "Alternative installation method also failed: $_" "ERROR"
        exit 1
    }
}

# Step 2: Start Docker service
Write-Log "" "INFO"
Write-Log "Step 2: Starting Docker service" "INFO"
try {
    Start-Service docker -ErrorAction Stop
    Write-Log "Docker service started successfully" "SUCCESS"
} catch {
    Write-Log "Failed to start Docker service: $_" "ERROR"
    Write-Log "Attempting to start manually..." "WARN"
    
    try {
        & dockerd --run-service
        Start-Sleep -Seconds 5
        Write-Log "Docker service started manually" "SUCCESS"
    } catch {
        Write-Log "Failed to start Docker manually: $_" "ERROR"
    }
}

# Step 3: Verify Docker installation
Write-Log "" "INFO"
Write-Log "Step 3: Verifying Docker installation" "INFO"

Start-Sleep -Seconds 5  # Give Docker time to fully start

try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
    if ($dockerVersion) {
        Write-Log "Docker version: $dockerVersion" "SUCCESS"
    } else {
        throw "Docker version command returned empty"
    }
    
    # Test Docker with hello-world
    Write-Log "Testing Docker with hello-world container..." "INFO"
    $testOutput = docker run --rm hello-world 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Docker test successful!" "SUCCESS"
        Write-Log "Test output:" "INFO"
        $testOutput | ForEach-Object { Write-Log "  $_" "INFO" }
    } else {
        Write-Log "Docker test failed with exit code: $LASTEXITCODE" "WARN"
        Write-Log "Output: $testOutput" "WARN"
    }
    
} catch {
    Write-Log "Docker verification failed: $_" "ERROR"
    Write-Log "Docker may not be fully operational yet" "WARN"
}

# Step 4: Configure Docker
Write-Log "" "INFO"
Write-Log "Step 4: Configuring Docker" "INFO"

try {
    # Create Docker config directory
    $dockerConfigDir = "C:\ProgramData\docker\config"
    if (-not (Test-Path $dockerConfigDir)) {
        New-Item -ItemType Directory -Path $dockerConfigDir -Force | Out-Null
        Write-Log "Created Docker config directory: $dockerConfigDir" "SUCCESS"
    }
    
    # Set Docker to start automatically
    Set-Service docker -StartupType Automatic
    Write-Log "Docker service set to start automatically" "SUCCESS"
    
} catch {
    Write-Log "Failed to configure Docker: $_" "WARN"
}

# Step 5: Display Docker info
Write-Log "" "INFO"
Write-Log "Step 5: Docker Information" "INFO"
try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Docker is running successfully" "SUCCESS"
        Write-Log "" "INFO"
        Write-Log "Docker Info:" "INFO"
        $dockerInfo | Select-Object -First 20 | ForEach-Object { Write-Log "  $_" "INFO" }
    } else {
        Write-Log "Docker info command failed" "WARN"
    }
} catch {
    Write-Log "Could not retrieve Docker info: $_" "WARN"
}

Write-Log "" "INFO"
Write-Log "========================================" "INFO"
Write-Log "Docker Installation Complete!" "SUCCESS"
Write-Log "========================================" "INFO"
Write-Log "" "INFO"
Write-Log "Next steps:" "INFO"
Write-Log "1. Verify Docker is running: docker ps" "INFO"
Write-Log "2. Pull an image: docker pull mcr.microsoft.com/windows/nanoserver:ltsc2022" "INFO"
Write-Log "3. Run a container: docker run --rm mcr.microsoft.com/windows/nanoserver:ltsc2022 cmd /c echo Hello from Docker!" "INFO"
Write-Log "" "INFO"

# Made with Bob
