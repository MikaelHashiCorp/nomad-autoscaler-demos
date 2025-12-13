# Simple Docker Installation Script
Write-Host "Starting Docker installation via direct download method..."

$dockerUrl = "https://download.docker.com/win/static/stable/x86_64/docker-24.0.7.zip"
$downloadPath = "$env:TEMP\docker.zip"
$extractPath = "C:\Program Files\Docker"

try {
    Write-Host "Downloading Docker from $dockerUrl..."
    Invoke-WebRequest -Uri $dockerUrl -OutFile $downloadPath -UseBasicParsing
    Write-Host "Download complete"
    
    Write-Host "Extracting Docker to $extractPath..."
    Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
    Write-Host "Extraction complete"
    
    Write-Host "Adding Docker to system PATH..."
    $dockerBinPath = "$extractPath\docker"
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$dockerBinPath*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$dockerBinPath", "Machine")
        $env:Path = "$env:Path;$dockerBinPath"
        Write-Host "PATH updated"
    } else {
        Write-Host "Docker already in PATH"
    }
    
    Write-Host "Registering Docker service..."
    & "$dockerBinPath\dockerd.exe" --register-service
    Write-Host "Service registered"
    
    Write-Host "Starting Docker service..."
    Start-Service docker
    Write-Host "Service started"
    
    Start-Sleep -Seconds 5
    
    Write-Host "Verifying Docker installation..."
    $version = docker version --format '{{.Server.Version}}' 2>$null
    if ($version) {
        Write-Host "SUCCESS: Docker version $version installed!"
    } else {
        Write-Host "WARNING: Docker installed but version check failed"
    }
    
} catch {
    Write-Host "ERROR: Docker installation failed - $_"
    exit 1
}

Write-Host "Docker installation complete!"

# Made with Bob
