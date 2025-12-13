# SSH Connection Guide for Windows Server 2022 AMI

## Overview
This guide provides instructions for connecting to Windows Server 2022 instances via SSH using OpenSSH Server.

## Prerequisites
- Windows Server 2022 instance running from the custom AMI
- SSH client installed on your local machine (macOS/Linux/Windows)
- RSA SSH key pair (ED25519 not supported by Windows)
- Security group allowing inbound traffic on port 22

## Instance Details
- **Instance ID**: i-0363b8ece02ab1221
- **Public IP**: 54.203.125.163
- **AMI ID**: ami-0ffb5e08f1d975964
- **Region**: us-west-2
- **Username**: Administrator

## OpenSSH Server Installation

### Automated Installation via SSM
```powershell
# Install OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start and configure SSH service
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# Configure Windows Firewall
New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server (sshd)" `
  -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

### Manual Installation via RDP
1. Connect to instance via RDP
2. Open PowerShell as Administrator
3. Run the commands above

## SSH Key Configuration

### For Administrator Account
Windows uses a special location for administrator SSH keys:

```powershell
# Create SSH directory
New-Item -ItemType Directory -Path "C:\ProgramData\ssh" -Force

# Add your public key
$pubKey = "ssh-rsa AAAAB3NzaC1yc2E... your-public-key-here"
Set-Content -Path "C:\ProgramData\ssh\administrators_authorized_keys" -Value $pubKey

# Set correct permissions (critical!)
icacls "C:\ProgramData\ssh\administrators_authorized_keys" /inheritance:r
icacls "C:\ProgramData\ssh\administrators_authorized_keys" /grant "SYSTEM:(F)"
icacls "C:\ProgramData\ssh\administrators_authorized_keys" /grant "BUILTIN\Administrators:(F)"

# Restart SSH service
Restart-Service sshd
```

### For Non-Administrator Users
```powershell
# Create .ssh directory in user's home
New-Item -ItemType Directory -Path "$env:USERPROFILE\.ssh" -Force

# Add public key
$pubKey = "ssh-rsa AAAAB3NzaC1yc2E... your-public-key-here"
Set-Content -Path "$env:USERPROFILE\.ssh\authorized_keys" -Value $pubKey
```

## Security Group Configuration

### Add SSH Port to Security Group
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-0b7eae1b4bab461f1 \
  --region us-west-2 \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

**Note**: For production, restrict CIDR to your specific IP address:
```bash
--cidr YOUR_IP_ADDRESS/32
```

## Connecting via SSH

### Basic Connection
```bash
ssh -i ~/.ssh/id_rsa Administrator@54.203.125.163
```

### Connection with Options
```bash
# Disable host key checking (for testing)
ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -i ~/.ssh/id_rsa \
    Administrator@54.203.125.163
```

### Running Remote Commands
```bash
# Single command
ssh -i ~/.ssh/id_rsa Administrator@54.203.125.163 "hostname"

# Multiple commands
ssh -i ~/.ssh/id_rsa Administrator@54.203.125.163 "hostname && whoami && systeminfo"

# Check Docker
ssh -i ~/.ssh/id_rsa Administrator@54.203.125.163 "docker version"

# Check HashiStack
ssh -i ~/.ssh/id_rsa Administrator@54.203.125.163 "consul version && nomad version && vault version"
```

### Interactive Session
```bash
ssh -i ~/.ssh/id_rsa Administrator@54.203.125.163
```

Once connected, you can run PowerShell commands:
```powershell
# Check system info
systeminfo

# Check services
Get-Service sshd,docker,consul,nomad,vault

# Check Docker
docker ps
docker images

# Check HashiStack
consul members
nomad node status
vault status
```

## SSH Configuration File

Create or edit `~/.ssh/config` for easier connections:

```
Host windows-demo
    HostName 54.203.125.163
    User Administrator
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host windows-demo-prod
    HostName 54.203.125.163
    User Administrator
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking yes
```

Then connect simply with:
```bash
ssh windows-demo
```

## Troubleshooting

### Connection Refused
**Problem**: `ssh: connect to host 54.203.125.163 port 22: Connection refused`

**Solutions**:
1. Check SSH service is running:
   ```powershell
   Get-Service sshd
   ```
2. Verify firewall rule:
   ```powershell
   Get-NetFirewallRule -Name sshd
   ```
3. Check security group allows port 22

### Permission Denied (publickey)
**Problem**: `Permission denied (publickey,keyboard-interactive)`

**Solutions**:
1. Verify authorized_keys file exists and has correct permissions:
   ```powershell
   Get-Content "C:\ProgramData\ssh\administrators_authorized_keys"
   icacls "C:\ProgramData\ssh\administrators_authorized_keys"
   ```
2. Check SSH service logs:
   ```powershell
   Get-EventLog -LogName Application -Source OpenSSH -Newest 10
   ```
3. Ensure you're using the correct private key:
   ```bash
   ssh -vvv -i ~/.ssh/id_rsa Administrator@54.203.125.163
   ```

### Host Key Verification Failed
**Problem**: `Host key verification failed`

**Solutions**:
1. Remove old host key:
   ```bash
   ssh-keygen -R 54.203.125.163
   ```
2. Or use `-o StrictHostKeyChecking=no` option

### Timeout
**Problem**: `ssh: connect to host 54.203.125.163 port 22: Operation timed out`

**Solutions**:
1. Verify security group allows port 22 from your IP
2. Check instance is running:
   ```bash
   aws ec2 describe-instances --instance-ids i-0363b8ece02ab1221 --region us-west-2
   ```
3. Verify network connectivity:
   ```bash
   ping 54.203.125.163
   telnet 54.203.125.163 22
   ```

## Automated SSH Setup Script

Create a script to automate SSH key configuration:

```bash
#!/bin/bash
# setup-ssh-windows.sh

INSTANCE_ID="i-0363b8ece02ab1221"
REGION="us-west-2"
PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)

echo "Installing OpenSSH Server and configuring SSH key..."

aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --document-name "AWS-RunPowerShellScript" \
  --parameters "commands=[
    'Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0',
    'Start-Service sshd',
    'Set-Service -Name sshd -StartupType Automatic',
    'New-NetFirewallRule -Name sshd -DisplayName \"OpenSSH Server (sshd)\" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue',
    'New-Item -ItemType Directory -Path \"C:\\ProgramData\\ssh\" -Force | Out-Null',
    '\$pubKey = \"$PUBLIC_KEY\"',
    'Set-Content -Path \"C:\\ProgramData\\ssh\\administrators_authorized_keys\" -Value \$pubKey -Force',
    'icacls \"C:\\ProgramData\\ssh\\administrators_authorized_keys\" /inheritance:r',
    'icacls \"C:\\ProgramData\\ssh\\administrators_authorized_keys\" /grant \"SYSTEM:(F)\"',
    'icacls \"C:\\ProgramData\\ssh\\administrators_authorized_keys\" /grant \"BUILTIN\\Administrators:(F)\"',
    'Restart-Service sshd',
    'Write-Host \"SSH configured successfully!\"'
  ]" \
  --output text \
  --query 'Command.CommandId'
```

## Testing SSH Connection

### Quick Test Script
```bash
#!/bin/bash
# test-ssh-connection.sh

INSTANCE_IP="54.203.125.163"
SSH_KEY="~/.ssh/id_rsa"

echo "Testing SSH connection to Windows instance..."

# Test basic connectivity
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$SSH_KEY" \
   Administrator@"$INSTANCE_IP" "echo 'SSH connection successful!'" 2>/dev/null; then
    echo "✓ SSH connection working"
else
    echo "✗ SSH connection failed"
    exit 1
fi

# Test Docker
echo "Testing Docker..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" \
    Administrator@"$INSTANCE_IP" "docker version" 2>/dev/null && \
    echo "✓ Docker accessible" || echo "✗ Docker not accessible"

# Test HashiStack
echo "Testing HashiStack..."
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" \
    Administrator@"$INSTANCE_IP" "consul version && nomad version && vault version" 2>/dev/null && \
    echo "✓ HashiStack accessible" || echo "✗ HashiStack not accessible"
```

## Security Best Practices

### 1. Use Key-Based Authentication Only
Disable password authentication in `C:\ProgramData\ssh\sshd_config`:
```
PasswordAuthentication no
PubkeyAuthentication yes
```

### 2. Restrict SSH Access by IP
Update security group to allow only your IP:
```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP/32
```

### 3. Use SSH Agent
```bash
# Start SSH agent
eval "$(ssh-agent -s)"

# Add your key
ssh-add ~/.ssh/id_rsa

# Connect without specifying key
ssh Administrator@54.203.125.163
```

### 4. Enable SSH Logging
Configure logging in `C:\ProgramData\ssh\sshd_config`:
```
SyslogFacility AUTH
LogLevel INFO
```

### 5. Regular Key Rotation
Rotate SSH keys periodically:
```bash
# Generate new key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_new

# Update authorized_keys on server
# Remove old key from authorized_keys
```

## Integration with Packer

To include SSH setup in the AMI build, add to [`setup-windows.ps1`](../shared/packer/scripts/setup-windows.ps1):

```powershell
# Install OpenSSH Server
Write-Host "Installing OpenSSH Server..."
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Configure SSH service
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# Configure firewall
New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server (sshd)" `
  -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 `
  -ErrorAction SilentlyContinue

Write-Host "OpenSSH Server installed and configured"
```

## Verification Commands

### Check SSH Service Status
```powershell
Get-Service sshd | Format-List
```

### Check SSH Configuration
```powershell
Get-Content "C:\ProgramData\ssh\sshd_config"
```

### Check Authorized Keys
```powershell
Get-Content "C:\ProgramData\ssh\administrators_authorized_keys"
```

### Check SSH Logs
```powershell
Get-EventLog -LogName Application -Source OpenSSH -Newest 20
```

### Check Firewall Rules
```powershell
Get-NetFirewallRule -Name sshd | Format-List
```

## Additional Resources

- [OpenSSH for Windows Documentation](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_overview)
- [SSH Key Management](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement)
- [AWS EC2 Windows Instances](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/)

## Related Files
- [`WINDOWS_AMI_SUMMARY.md`](WINDOWS_AMI_SUMMARY.md) - Complete AMI implementation guide
- [`DOCKER_INSTALLATION_GUIDE.md`](DOCKER_INSTALLATION_GUIDE.md) - Docker installation instructions
- [`launch-windows-instance.sh`](launch-windows-instance.sh) - Instance launcher script

---
**Created**: 2025-12-13  
**Last Updated**: 2025-12-13  
**Status**: Tested and Verified  
**Instance**: i-0363b8ece02ab1221 (54.203.125.163)