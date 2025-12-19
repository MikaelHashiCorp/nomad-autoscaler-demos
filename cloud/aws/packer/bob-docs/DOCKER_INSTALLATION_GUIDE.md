# Docker Installation Guide for Windows Server 2022 AMI

## Overview

This guide provides step-by-step instructions for installing Docker on the Windows Server 2022 instance launched from AMI `ami-0ffb5e08f1d975964`.

## Instance Information

- **Instance ID**: `i-0363b8ece02ab1221`
- **Public IP**: `54.203.125.163`
- **Region**: `us-west-2`
- **AMI**: `ami-0ffb5e08f1d975964` (Windows Server 2022 with HashiStack)
- **Instance Type**: `t3a.xlarge`

## Pre-installed Components

The AMI already includes:
- ✅ Consul v1.22.1
- ✅ Nomad v1.11.1
- ✅ Vault v1.21.1
- ✅ Windows Firewall configured for HashiStack ports
- ✅ WinRM enabled (HTTP port 5985)

## Docker Installation Methods

### Method 1: Manual RDP Connection (Recommended)

This is the most reliable method for installing Docker.

#### Step 1: Get Windows Password

1. **Via AWS Console** (Easiest):
   - Go to [AWS EC2 Console](https://us-west-2.console.aws.amazon.com/ec2/home?region=us-west-2#Instances:)
   - Select instance `i-0363b8ece02ab1221`
   - Click **Actions** → **Security** → **Get Windows password**
   - Upload your key pair file (.pem) to decrypt the password
   - Copy the decrypted password

2. **Via AWS CLI** (Requires private key):
   ```bash
   source ~/.zshrc
   logcmd aws ec2 get-password-data \
     --instance-id i-0363b8ece02ab1221 \
     --region us-west-2 \
     --priv-launch-key-file /path/to/your-key.pem \
     --query 'PasswordData' \
     --output text
   ```

#### Step 2: Connect via RDP

1. **Connection Details**:
   - Host: `54.203.125.163`
   - Port: `3389` (default RDP)
   - Username: `Administrator`
   - Password: (from Step 1)

2. **On macOS**:
   - Use Microsoft Remote Desktop app (available in App Store)
   - Or use `open rdp://Administrator@54.203.125.163`

3. **On Windows**:
   - Use built-in Remote Desktop Connection (`mstsc.exe`)

4. **On Linux**:
   - Use Remmina or `xfreerdp`:
     ```bash
     xfreerdp /u:Administrator /p:'YOUR_PASSWORD' /v:54.203.125.163
     ```

#### Step 3: Install Docker

Once connected via RDP:

1. **Open PowerShell as Administrator**:
   - Right-click Start menu → **Windows PowerShell (Admin)**

2. **Run the Docker installation script**:

   Copy and paste the entire script below into PowerShell:

   ```powershell
   # Docker Installation Script for Windows Server 2022
   Write-Host "Starting Docker installation..." -ForegroundColor Cyan
   
   # Method 1: Try DockerMsftProvider (Recommended)
   try {
       Write-Host "Installing DockerMsftProvider..." -ForegroundColor Yellow
       Install-Module -Name DockerMsftProvider -Repository PSGallery -Force -Confirm:$false
       
       Write-Host "Installing Docker..." -ForegroundColor Yellow
       Install-Package -Name docker -ProviderName DockerMsftProvider -Force -Confirm:$false
       
       Write-Host "Starting Docker service..." -ForegroundColor Yellow
       Start-Service docker
       
       Write-Host "Docker installed successfully!" -ForegroundColor Green
       
   } catch {
       Write-Host "DockerMsftProvider method failed: $_" -ForegroundColor Red
       Write-Host "Trying direct download method..." -ForegroundColor Yellow
       
       # Method 2: Direct Download
       try {
           $dockerUrl = "https://download.docker.com/win/static/stable/x86_64/docker-24.0.7.zip"
           $downloadPath = "$env:TEMP\docker.zip"
           $extractPath = "C:\Program Files\Docker"
           
           Write-Host "Downloading Docker..." -ForegroundColor Yellow
           Invoke-WebRequest -Uri $dockerUrl -OutFile $downloadPath -UseBasicParsing
           
           Write-Host "Extracting Docker..." -ForegroundColor Yellow
           Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
           
           Write-Host "Adding Docker to PATH..." -ForegroundColor Yellow
           $dockerBinPath = "$extractPath\docker"
           $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
           if ($currentPath -notlike "*$dockerBinPath*") {
               [Environment]::SetEnvironmentVariable("Path", "$currentPath;$dockerBinPath", "Machine")
               $env:Path = "$env:Path;$dockerBinPath"
           }
           
           Write-Host "Registering Docker service..." -ForegroundColor Yellow
           & "$dockerBinPath\dockerd.exe" --register-service
           
           Write-Host "Starting Docker service..." -ForegroundColor Yellow
           Start-Service docker
           
           Write-Host "Docker installed successfully!" -ForegroundColor Green
           
       } catch {
           Write-Host "Direct download method also failed: $_" -ForegroundColor Red
           exit 1
       }
   }
   
   # Verify installation
   Write-Host "`nVerifying Docker installation..." -ForegroundColor Cyan
   Start-Sleep -Seconds 5
   
   $version = docker version --format '{{.Server.Version}}' 2>$null
   if ($version) {
       Write-Host "Docker version: $version" -ForegroundColor Green
       
       Write-Host "`nTesting Docker with hello-world..." -ForegroundColor Cyan
       docker run --rm hello-world
       
       Write-Host "`nDocker is ready to use!" -ForegroundColor Green
   } else {
       Write-Host "Docker verification failed" -ForegroundColor Red
   }
   ```

3. **Wait for installation to complete** (5-10 minutes)

4. **Verify Docker is working**:
   ```powershell
   docker version
   docker ps
   docker run --rm mcr.microsoft.com/windows/nanoserver:ltsc2022 cmd /c echo Hello from Docker!
   ```

### Method 2: Automated Script File

If you prefer to use a pre-written script file:

1. Connect via RDP (see Method 1, Steps 1-2)

2. Download the installation script:
   ```powershell
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/your-repo/install-docker-windows.ps1" -OutFile C:\install-docker.ps1
   ```
   
   Or create the file manually by copying [`install-docker-windows.ps1`](install-docker-windows.ps1)

3. Run the script:
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   C:\install-docker.ps1
   ```

### Method 3: WinRM (Advanced)

If you have the decrypted password and pywinrm installed:

```bash
# Install pywinrm
python3 -m venv venv
source venv/bin/activate
pip install pywinrm requests-ntlm

# Run the installation
python3 install-docker-via-winrm.py --password YOUR_DECRYPTED_PASSWORD
```

## Troubleshooting

### Docker Installation Fails

1. **PowerShell Gallery timeout**:
   - This is common in automated builds
   - Use the direct download method (Method 2 in the script)

2. **Service won't start**:
   ```powershell
   # Check service status
   Get-Service docker
   
   # View logs
   Get-EventLog -LogName Application -Source Docker -Newest 20
   
   # Restart service
   Restart-Service docker
   ```

3. **Docker command not found**:
   ```powershell
   # Refresh PATH
   $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
   
   # Or restart PowerShell
   ```

### WinRM Connection Issues

1. **Cannot connect via WinRM**:
   - Verify security group allows port 5985
   - Check Windows Firewall: `Get-NetFirewallRule -DisplayName "*WinRM*"`
   - Verify WinRM service: `Get-Service WinRM`

2. **Authentication fails**:
   - Ensure you're using the correct decrypted password
   - Try RDP connection first to verify credentials

## Post-Installation

### Configure Docker

1. **Set Docker to start automatically** (already done by script):
   ```powershell
   Set-Service docker -StartupType Automatic
   ```

2. **Configure Docker daemon** (optional):
   ```powershell
   # Create daemon config
   New-Item -Path "C:\ProgramData\docker\config" -ItemType Directory -Force
   
   @"
   {
     "log-driver": "json-file",
     "log-opts": {
       "max-size": "10m",
       "max-file": "3"
     }
   }
   "@ | Out-File -FilePath "C:\ProgramData\docker\config\daemon.json" -Encoding ASCII
   
   Restart-Service docker
   ```

### Test Docker with Nomad

Since Nomad is already installed, you can test Docker integration:

```powershell
# Create a simple Nomad job
@"
job "docker-test" {
  datacenters = ["dc1"]
  type = "service"
  
  group "test" {
    task "hello" {
      driver = "docker"
      
      config {
        image = "mcr.microsoft.com/windows/nanoserver:ltsc2022"
        command = "cmd"
        args = ["/c", "echo Hello from Nomad + Docker!"]
      }
    }
  }
}
"@ | Out-File -FilePath "C:\docker-test.nomad" -Encoding ASCII

# Run the job (requires Nomad to be running)
nomad job run C:\docker-test.nomad
```

## Cleanup

When you're done testing:

### Terminate the Instance

```bash
source ~/.zshrc
logcmd aws ec2 terminate-instances --instance-ids i-0363b8ece02ab1221 --region us-west-2
```

### Delete Security Group

```bash
source ~/.zshrc
logcmd aws ec2 delete-security-group --group-id sg-0b7eae1b4bab461f1 --region us-west-2
```

## Files Reference

- [`install-docker-windows.ps1`](install-docker-windows.ps1) - Main Docker installation script
- [`launch-windows-instance.sh`](launch-windows-instance.sh) - Script to launch Windows instances
- [`run-docker-install-winrm.sh`](run-docker-install-winrm.sh) - Helper script with connection info
- [`install-docker-via-winrm.py`](install-docker-via-winrm.py) - Python script for WinRM automation

## Additional Resources

- [Docker on Windows Server](https://docs.docker.com/engine/install/windows-server/)
- [Nomad Docker Driver](https://developer.hashicorp.com/nomad/docs/drivers/docker)
- [Windows Containers Documentation](https://learn.microsoft.com/en-us/virtualization/windowscontainers/)

## Summary

The Windows Server 2022 AMI is ready with HashiStack components. Docker installation requires manual RDP connection due to password encryption. The provided PowerShell script handles both DockerMsftProvider and direct download methods for maximum reliability.