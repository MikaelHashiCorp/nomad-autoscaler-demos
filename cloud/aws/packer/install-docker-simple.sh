#!/bin/bash

# Simple script to install Docker on Windows instance
# Uses AWS CLI to send commands

source ~/.zshrc 2>/dev/null

INSTANCE_ID="i-0363b8ece02ab1221"
REGION="us-west-2"
PUBLIC_IP="54.203.125.163"

echo "=========================================="
echo "Docker Installation via User Data"
echo "=========================================="
echo ""
echo "Instance: $INSTANCE_ID"
echo "IP: $PUBLIC_IP"
echo ""

# Create a PowerShell script that will be executed via user data
cat > /tmp/docker-install-userdata.ps1 << 'PSEOF'
<powershell>
# Set execution policy
Set-ExecutionPolicy Bypass -Scope Process -Force

# Log file
$logFile = "C:\docker-install.log"
function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Tee-Object -FilePath $logFile -Append | Write-Host
}

Write-Log "Starting Docker installation"

try {
    # Method 1: Try DockerMsftProvider
    Write-Log "Installing DockerMsftProvider..."
    Install-Module -Name DockerMsftProvider -Repository PSGallery -Force -Confirm:$false
    
    Write-Log "Installing Docker..."
    Install-Package -Name docker -ProviderName DockerMsftProvider -Force -Confirm:$false
    
    Write-Log "Starting Docker service..."
    Start-Service docker
    
    Write-Log "Docker installed successfully via DockerMsftProvider"
    
} catch {
    Write-Log "DockerMsftProvider method failed: $_"
    Write-Log "Trying direct download method..."
    
    try {
        # Method 2: Direct download
        $dockerUrl = "https://download.docker.com/win/static/stable/x86_64/docker-24.0.7.zip"
        $downloadPath = "$env:TEMP\docker.zip"
        $extractPath = "C:\Program Files\Docker"
        
        Write-Log "Downloading Docker from $dockerUrl..."
        Invoke-WebRequest -Uri $dockerUrl -OutFile $downloadPath -UseBasicParsing
        
        Write-Log "Extracting Docker..."
        Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
        
        Write-Log "Adding Docker to PATH..."
        $dockerBinPath = "$extractPath\docker"
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$dockerBinPath*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$dockerBinPath", "Machine")
            $env:Path = "$env:Path;$dockerBinPath"
        }
        
        Write-Log "Registering Docker service..."
        & "$dockerBinPath\dockerd.exe" --register-service
        
        Write-Log "Starting Docker service..."
        Start-Service docker
        
        Write-Log "Docker installed successfully via direct download"
        
    } catch {
        Write-Log "Direct download method also failed: $_"
        exit 1
    }
}

# Verify installation
Write-Log "Verifying Docker installation..."
Start-Sleep -Seconds 5
$version = docker version --format '{{.Server.Version}}' 2>$null
if ($version) {
    Write-Log "Docker version: $version"
    Write-Log "Docker installation completed successfully!"
} else {
    Write-Log "Docker verification failed"
}

Write-Log "Installation log saved to: $logFile"
</powershell>
PSEOF

echo "User data script created at /tmp/docker-install-userdata.ps1"
echo ""
echo "Note: AWS doesn't allow modifying user data on running instances."
echo "We need to use a different approach."
echo ""
echo "=========================================="
echo "Alternative Approach: Manual Installation"
echo "=========================================="
echo ""
echo "Since SSM is not available and we can't modify user data on a running instance,"
echo "you have two options:"
echo ""
echo "Option 1: Connect via RDP and run the PowerShell script manually"
echo "  1. Get the Windows password (wait 4-5 minutes after launch):"
echo "     source ~/.zshrc && logcmd aws ec2 get-password-data --instance-id $INSTANCE_ID --region $REGION"
echo "  2. Connect via RDP to $PUBLIC_IP"
echo "  3. Open PowerShell as Administrator"
echo "  4. Copy and paste the contents of install-docker-windows.ps1"
echo ""
echo "Option 2: Use WinRM (if configured)"
echo "  This requires the Windows password and WinRM to be properly configured."
echo ""
echo "Option 3: Terminate and relaunch with user data"
echo "  We can terminate this instance and launch a new one with Docker installation"
echo "  included in the user data."
echo ""

read -p "Would you like to terminate and relaunch with Docker in user data? (y/n): " response

if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
    echo ""
    echo "Terminating instance $INSTANCE_ID..."
    source ~/.zshrc && logcmd aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION
    
    echo "Waiting for instance to terminate..."
    source ~/.zshrc && logcmd aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region $REGION
    
    echo "Instance terminated. You can now run launch-windows-instance.sh with modified user data."
else
    echo ""
    echo "Keeping instance running. Use one of the manual options above."
    echo ""
    echo "Instance details:"
    echo "  Instance ID: $INSTANCE_ID"
    echo "  Public IP: $PUBLIC_IP"
    echo "  Region: $REGION"
    echo ""
    echo "To check if password is available:"
    echo "  source ~/.zshrc && logcmd aws ec2 get-password-data --instance-id $INSTANCE_ID --region $REGION"
fi

# Made with Bob
