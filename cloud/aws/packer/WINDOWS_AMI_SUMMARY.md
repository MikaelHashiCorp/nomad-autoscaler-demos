# Windows Server 2022 AMI Implementation Summary

## Overview
Successfully implemented Windows Server 2022 AMI support for the HashiCorp Nomad Autoscaler demonstration environment. The AMI includes HashiStack (Consul, Nomad, Vault) with automatic version detection and Docker support.

## Created AMI Details
- **AMI ID**: `ami-0ffb5e08f1d975964`
- **Name**: `hashistack-Windows-2022-<timestamp>`
- **Region**: `us-west-2`
- **Base Image**: Windows Server 2022 Base
- **Instance Type Used**: `t3a.xlarge`
- **Key Type**: RSA (Windows requirement)

## HashiStack Versions Installed
- **Consul**: 1.22.1 (latest, auto-detected)
- **Nomad**: 1.11.1 (latest, auto-detected)
- **Vault**: 1.21.1 (latest, auto-detected)

## Key Implementation Changes

### 1. Packer Configuration ([`aws-packer.pkr.hcl`](aws-packer.pkr.hcl))
- Added conditional key type selection (RSA for Windows, ED25519 for Linux)
- Configured WinRM for Windows provisioning (HTTP port 5985)
- Created separate `build "linux"` and `build "windows"` blocks
- Implemented EC2Launch v2 sysprep for Windows Server 2022

### 2. Windows Provisioning Script ([`../shared/packer/scripts/setup-windows.ps1`](../shared/packer/scripts/setup-windows.ps1))
- Automatic latest version detection via HashiCorp Checkpoint API
- Comprehensive installation of Consul, Nomad, and Vault
- Windows Firewall configuration for all HashiStack ports
- Extensive logging and error handling
- Docker installation disabled in AMI build (installed post-deployment)

### 3. Variable Configuration ([`variables.pkr.hcl`](variables.pkr.hcl))
- Added Windows-specific variables
- OS-based conditional logic for source AMI selection
- Support for Windows Server 2022

### 4. OS Configuration Script ([`create-os-configs.sh`](create-os-configs.sh))
- Added Windows Server 2022 configuration generation
- Creates [`windows-2022.pkrvars.hcl`](windows-2022.pkrvars.hcl) with proper OS settings

## Docker Installation Process

### Issue Discovered
Docker installation via PowerShell Gallery (`Install-Module DockerMsftProvider`) was unreliable in packer builds, causing indefinite hangs.

### Solution Implemented
Docker installation moved to post-deployment phase with two methods:

#### Method 1: Manual Installation via RDP
Comprehensive guide provided in [`DOCKER_INSTALLATION_GUIDE.md`](DOCKER_INSTALLATION_GUIDE.md)

#### Method 2: Automated Installation via SSM (Recommended)
Complete automated installation using AWS Systems Manager:

1. **Install Windows Containers Feature**:
```powershell
Install-WindowsFeature -Name Containers -Restart
```

2. **Download and Install Docker**:
```powershell
# Download Docker binaries
Invoke-WebRequest -Uri "https://download.docker.com/win/static/stable/x86_64/docker-24.0.7.zip" -OutFile "$env:TEMP\docker.zip"

# Extract to Program Files
Expand-Archive -Path "$env:TEMP\docker.zip" -DestinationPath "$env:ProgramFiles" -Force

# Add to PATH
[Environment]::SetEnvironmentVariable("Path", "$env:Path;C:\Program Files\Docker", "Machine")

# Register Docker service
& "C:\Program Files\Docker\dockerd.exe" --register-service

# Start Docker service
Start-Service docker
```

3. **Verify Installation**:
```powershell
docker version
docker info
docker run --rm mcr.microsoft.com/windows/nanoserver:ltsc2022 cmd /c echo Hello from Docker!
```

### Docker Installation Scripts Created
- [`install-docker-windows.ps1`](install-docker-windows.ps1) - Comprehensive installation script (175 lines)
- [`docker-install-simple.ps1`](docker-install-simple.ps1) - Simplified version for SSM (51 lines)
- [`launch-windows-instance.sh`](launch-windows-instance.sh) - Automated instance launcher
- [`DOCKER_INSTALLATION_GUIDE.md`](DOCKER_INSTALLATION_GUIDE.md) - Complete installation guide (318 lines)

## Testing Results

### AMI Build Test
✅ **Status**: Success
- Build completed in ~15 minutes
- All HashiStack components installed successfully
- EC2Launch v2 sysprep successful
- AMI created and available

### Instance Launch Test
✅ **Status**: Success
- Instance ID: `i-0363b8ece02ab1221`
- Public IP: `54.203.125.163`
- SSM agent: Online
- HashiStack services: Verified installed

### Docker Installation Test
✅ **Status**: Success
- Windows Containers feature: Installed
- Docker service: Running
- Docker version: 24.0.7 (Client and Server)
- Container test: Successful (nanoserver:ltsc2022)

## Key Technical Challenges Resolved

### 1. ED25519 Key Type Issue
**Problem**: Windows AMIs don't support ED25519 SSH keys
**Solution**: Implemented conditional key type selection (RSA for Windows)

### 2. WinRM Connection Timeout
**Problem**: HTTPS WinRM connection timing out
**Solution**: Switched to HTTP (port 5985) with `winrm_use_ssl = false`

### 3. Provisioner Conditional Logic
**Problem**: `only` parameter with empty array didn't skip provisioners
**Solution**: Created separate build blocks for Linux and Windows

### 4. Version Detection Failure
**Problem**: HTML parsing from releases.hashicorp.com unreliable
**Solution**: Switched to HashiCorp Checkpoint API

### 5. PowerShell Syntax Errors
**Problem**: Unicode characters and string interpolation causing parse errors
**Solution**: Replaced Unicode with ASCII, fixed string interpolation

### 6. Docker Installation Hanging
**Problem**: PowerShell Gallery operations hanging in packer builds
**Solution**: Disabled Docker in AMI build, moved to post-deployment

### 7. EC2Launch Sysprep Failure
**Problem**: Windows Server 2022 uses EC2Launch v2, not v1
**Solution**: Updated sysprep command to use EC2Launch v2

### 8. Docker Service Won't Start
**Problem**: Docker service failed with "vmcompute.dll" error
**Solution**: Installed Windows Containers feature, restarted instance

## Files Modified/Created

### Modified Files
1. [`aws-packer.pkr.hcl`](aws-packer.pkr.hcl) - Main packer configuration
2. [`variables.pkr.hcl`](variables.pkr.hcl) - Variable definitions
3. [`create-os-configs.sh`](create-os-configs.sh) - OS configuration generator

### Created Files
1. [`../shared/packer/scripts/setup-windows.ps1`](../shared/packer/scripts/setup-windows.ps1) - Windows provisioning script
2. [`windows-2022.pkrvars.hcl`](windows-2022.pkrvars.hcl) - Windows variables
3. [`install-docker-windows.ps1`](install-docker-windows.ps1) - Docker installation script
4. [`docker-install-simple.ps1`](docker-install-simple.ps1) - Simplified Docker installer
5. [`launch-windows-instance.sh`](launch-windows-instance.sh) - Instance launcher
6. [`DOCKER_INSTALLATION_GUIDE.md`](DOCKER_INSTALLATION_GUIDE.md) - Installation guide
7. [`VERSION_MANAGEMENT.md`](VERSION_MANAGEMENT.md) - Version management documentation
8. [`WINDOWS_AMI_SUMMARY.md`](WINDOWS_AMI_SUMMARY.md) - This document

## Usage Instructions

### Building the Windows AMI
```bash
# Generate OS configuration
./create-os-configs.sh

# Authenticate to AWS (per copilot-instructions.md)
source ~/.zshrc
# Follow AWS authentication prompts

# Build the AMI
packer build -var-file="windows-2022.pkrvars.hcl" aws-packer.pkr.hcl
```

### Launching an Instance
```bash
# Use the automated launcher
./launch-windows-instance.sh

# Or manually with AWS CLI
aws ec2 run-instances \
  --image-id ami-0ffb5e08f1d975964 \
  --instance-type t3a.xlarge \
  --key-name your-key-name \
  --security-group-ids sg-xxxxx \
  --iam-instance-profile Name=AWS-QuickSetup-SSM-DefaultEC2MgmtRole-us-west-2 \
  --region us-west-2
```

### Installing Docker Post-Deployment
```bash
# Via SSM (recommended)
aws ssm send-command \
  --instance-ids i-xxxxx \
  --region us-west-2 \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Install-WindowsFeature -Name Containers -Restart"]'

# After restart, install Docker
aws ssm send-command \
  --instance-ids i-xxxxx \
  --region us-west-2 \
  --document-name "AWS-RunPowerShellScript" \
  --parameters @docker-install-simple.ps1
```

## Network Configuration

### Required Ports (Windows Firewall Rules Configured)
- **Consul**: 8300, 8301, 8302, 8500, 8600
- **Nomad**: 4646, 4647, 4648
- **Vault**: 8200, 8201
- **WinRM**: 5985 (HTTP), 5986 (HTTPS)
- **RDP**: 3389

### Security Group Requirements
- Allow inbound RDP (3389) from your IP
- Allow inbound WinRM (5985) for provisioning
- Allow HashiStack ports for cluster communication
- Allow outbound HTTPS (443) for downloads

## Cost Considerations
- **AMI Build**: ~$0.50 per build (15 minutes on t3a.xlarge)
- **Running Instance**: ~$0.15/hour (t3a.xlarge)
- **Storage**: ~$0.10/GB/month for AMI storage

## Next Steps

### Recommended Improvements
1. **Pre-install Docker in AMI**: Modify setup-windows.ps1 to install Containers feature and Docker
2. **Automated Testing**: Add automated tests for HashiStack services
3. **Multi-Region Support**: Replicate AMI to other regions
4. **Terraform Integration**: Update terraform modules to support Windows instances
5. **Monitoring**: Add CloudWatch agent for metrics and logs

### Optional Enhancements
1. **Windows Server Core**: Create a Server Core variant for smaller footprint
2. **Container Images**: Pre-pull common Windows container images
3. **HashiStack Configuration**: Add default configuration files
4. **Auto-scaling**: Integrate with AWS Auto Scaling groups
5. **Backup Strategy**: Implement automated AMI snapshots

## Troubleshooting

### Common Issues

#### WinRM Connection Fails
- Verify security group allows port 5985
- Check Windows Firewall rules
- Ensure user data script completed

#### Docker Service Won't Start
- Verify Windows Containers feature is installed: `Get-WindowsFeature -Name Containers`
- Check Docker service status: `Get-Service docker`
- Review event logs: `Get-EventLog -LogName Application -Source Docker -Newest 10`

#### HashiStack Services Not Running
- Check service status: `Get-Service consul,nomad,vault`
- Review installation logs in `C:\HashiCorp\logs\`
- Verify binaries are in PATH: `where consul`, `where nomad`, `where vault`

#### AMI Build Fails
- Check packer logs for specific errors
- Verify AWS credentials are valid
- Ensure base AMI is available in region
- Check network connectivity for downloads

## References

### Documentation
- [Packer Windows Documentation](https://www.packer.io/docs/builders/amazon/ebs#windows)
- [HashiCorp Checkpoint API](https://checkpoint-api.hashicorp.com/)
- [Docker on Windows Server](https://docs.microsoft.com/en-us/virtualization/windowscontainers/quick-start/set-up-environment)
- [EC2Launch v2](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch-v2.html)

### Related Files
- [`.github/copilot-instructions.md`](../.github/copilot-instructions.md) - Project instructions
- [`MULTI_OS_SUPPORT.md`](MULTI_OS_SUPPORT.md) - Multi-OS support documentation
- [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md) - Quick reference guide
- [`VERSION_MANAGEMENT.md`](VERSION_MANAGEMENT.md) - Version management guide

## Conclusion

The Windows Server 2022 AMI implementation is complete and fully functional. The AMI includes:
- ✅ HashiStack (Consul, Nomad, Vault) with automatic version detection
- ✅ Proper Windows Firewall configuration
- ✅ EC2Launch v2 sysprep for clean AMI creation
- ✅ Comprehensive documentation and installation scripts
- ✅ Docker support (post-deployment installation)
- ✅ SSM agent for remote management

The implementation follows best practices for Windows AMI creation and provides a solid foundation for HashiCorp Nomad Autoscaler demonstrations on Windows Server 2022.

---
**Created**: 2025-12-13  
**Last Updated**: 2025-12-13  
**Status**: Complete and Tested  
**AMI ID**: ami-0ffb5e08f1d975964  
**Region**: us-west-2