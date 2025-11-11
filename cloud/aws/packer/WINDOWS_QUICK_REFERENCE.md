# Windows Server Quick Reference

This document provides a quick reference for building and deploying HashiStack on Windows Server (2019, 2022, or 2025).

## Building Windows AMI

### Prerequisites
- AWS credentials configured (via Doormat)
- Packer installed
- Navigate to `cloud/aws/packer/`

### AMI Source Priority
Packer will automatically select Windows AMIs using a three-tier priority system:
1. **HashiCorp account AMIs** (730335318773) - First priority, optimized for HashiCorp workloads
2. **IBM account AMIs** (764552833819) - Second priority, enterprise compatibility (currently no Windows AMIs)
3. **Amazon public AMIs** (801119661308) - Third priority, always available fallback

This ensures you get optimized HashiCorp AMIs when available, with automatic fallback through IBM (future) to Amazon's official AMIs.

### Build Commands

Choose your Windows Server version:

**Windows Server 2022 (Recommended for Production)**
```bash
cd cloud/aws/packer/
source env-pkr-var.sh
packer build \
  -var 'os=Windows' \
  -var 'os_version=2022' \
  -var 'os_name=' \
  -var 'region=us-west-2' \
  .
```

**Windows Server 2025 (Latest)**
```bash
cd cloud/aws/packer/
source env-pkr-var.sh
packer build \
  -var 'os=Windows' \
  -var 'os_version=2025' \
  -var 'os_name=' \
  -var 'region=us-west-2' \
  .
```

**Windows Server 2019**
```bash
cd cloud/aws/packer/
source env-pkr-var.sh
packer build \
  -var 'os=Windows' \
  -var 'os_version=2019' \
  -var 'os_name=' \
  -var 'region=us-west-2' \
  .
```

### Expected Build Time
- **20-30 minutes** (longer than Linux due to Windows initialization)

### What Gets Installed
- ✅ Consul (Windows binary)
- ✅ Nomad (Windows binary)
- ✅ CNI plugins (Windows versions, if available)
- ✅ Docker for Windows
- ✅ Chocolatey package manager
- ✅ Basic tools: 7zip, curl, wget, jq, git
- ✅ NSSM (service manager)

## Deploying with Terraform

### Update terraform.tfvars

```hcl
# Basic configuration
owner_name  = "your_name"
owner_email = "your_email@example.com"
region      = "us-west-2"
key_name    = "your-ec2-key"

# Windows-specific settings
packer_os         = "Windows"
packer_os_version = "2022"  # or "2025", "2019"
packer_os_name    = ""
```

### Deploy

```bash
cd cloud/aws/terraform/control/
terraform init
terraform apply
```

## Accessing Windows Instances

### Option 1: RDP (Remote Desktop)
1. Get public IP from Terraform outputs or AWS console
2. Get Windows password from EC2 console (decrypt with your key pair)
3. Connect via RDP client:
   - **macOS**: Microsoft Remote Desktop from App Store
   - **Windows**: Built-in Remote Desktop Connection (mstsc.exe)
   - **Linux**: Remmina or rdesktop

### Option 2: AWS Systems Manager Session Manager
```bash
# List instances
aws ec2 describe-instances --filters "Name=tag:Name,Values=hashistack-*" --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name'].Value|[0],State.Name]" --output table

# Start session
aws ssm start-session --target <instance-id>
```

## Verifying Installation

### Check Services

```powershell
# Check service status
Get-Service -Name Consul, Nomad

# Should show:
# Status   Name               DisplayName
# ------   ----               -----------
# Running  Consul             HashiCorp Consul
# Running  Nomad              HashiCorp Nomad
```

### Check Consul

```powershell
# Add to PATH if not already
$env:Path += ";C:\opt\consul"

# Check Consul members
C:\opt\consul\consul.exe members

# Check Consul UI (from browser)
# http://<server-public-ip>:8500/ui
```

### Check Nomad

```powershell
# Add to PATH if not already
$env:Path += ";C:\opt\nomad"

# Check Nomad nodes
C:\opt\nomad\nomad.exe node status

# Check Nomad UI (from browser)
# http://<server-public-ip>:4646/ui
```

### Check Docker

```powershell
# Check Docker service
Get-Service docker

# List Docker containers
docker ps

# Test Docker
docker run hello-world
```

## Log Locations

| Service | Log Location |
|---------|-------------|
| Provision | `C:\provision.log` |
| Consul | `C:\opt\consul\consul.log` |
| Consul Errors | `C:\opt\consul\consul-error.log` |
| Nomad | `C:\opt\nomad\nomad.log` |
| Nomad Errors | `C:\opt\nomad\nomad-error.log` |

### View Logs

```powershell
# View provision log
Get-Content C:\provision.log -Tail 50

# View Consul log
Get-Content C:\opt\consul\consul.log -Tail 50

# View Nomad log
Get-Content C:\opt\nomad\nomad.log -Tail 50

# Monitor in real-time
Get-Content C:\opt\nomad\nomad.log -Wait -Tail 20
```

## Configuration Files

| File | Location |
|------|----------|
| Consul Config | `C:\etc\consul.d\consul.hcl` |
| Consul Client Config | `C:\etc\consul.d\consul_client.hcl` |
| Nomad Config | `C:\etc\nomad.d\nomad.hcl` |
| Nomad Client Config | `C:\etc\nomad.d\nomad_client.hcl` |

## Common Tasks

### Restart Services

```powershell
# Restart Consul
Restart-Service -Name Consul

# Restart Nomad
Restart-Service -Name Nomad

# Restart both
Restart-Service -Name Consul, Nomad
```

### Check Service Configuration

```powershell
# View Consul service config
& nssm dump Consul

# View Nomad service config
& nssm dump Nomad
```

### Manually Start/Stop Services

```powershell
# Stop services
Stop-Service -Name Consul, Nomad

# Start services
Start-Service -Name Consul, Nomad
```

### Check Firewall Rules

```powershell
# List HashiCorp-related firewall rules
Get-NetFirewallRule | Where-Object DisplayName -like "*Consul*" | Select-Object DisplayName, Enabled, Direction, Action
Get-NetFirewallRule | Where-Object DisplayName -like "*Nomad*" | Select-Object DisplayName, Enabled, Direction, Action
```

### Check Network Connectivity

```powershell
# Test Consul HTTP
Test-NetConnection -ComputerName localhost -Port 8500

# Test Nomad HTTP
Test-NetConnection -ComputerName localhost -Port 4646

# Test DNS
Resolve-DnsName consul.service.consul
```

## Troubleshooting

### Issue: Services not starting

```powershell
# Check service status
Get-Service Consul, Nomad

# View error logs
Get-Content C:\opt\consul\consul-error.log
Get-Content C:\opt\nomad\nomad-error.log

# Check if binaries exist
Test-Path C:\opt\consul\consul.exe
Test-Path C:\opt\nomad\nomad.exe

# Try running manually
C:\opt\consul\consul.exe agent -config-dir=C:\etc\consul.d
```

### Issue: WinRM connection fails during Packer build

```powershell
# Check WinRM configuration
winrm get winrm/config

# Check firewall
Get-NetFirewallRule -Name "WinRM HTTPS"

# Check certificate
Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -like "*packer*"
```

### Issue: Docker not working

```powershell
# Check Docker service
Get-Service docker

# Start Docker if stopped
Start-Service docker

# Check Docker version
docker version

# Check Windows features
Get-WindowsFeature -Name Containers
```

### Issue: High memory usage

```powershell
# Check processes
Get-Process | Sort-Object -Descending WS | Select-Object -First 10 Name, Id, @{Name="Memory(MB)";Expression={"{0:N2}" -f ($_.WS / 1MB)}}

# Specifically check HashiCorp services
Get-Process consul, nomad | Select-Object Name, Id, @{Name="Memory(MB)";Expression={"{0:N2}" -f ($_.WS / 1MB)}}
```

## Key Differences from Linux

| Aspect | Linux | Windows |
|--------|-------|---------|
| Config Path | `/etc/{service}.d/` | `C:\etc\{service}.d\` |
| Binary Path | `/opt/{service}/{service}` | `C:\opt\{service}\{service}.exe` |
| Service Manager | systemd | NSSM (Windows Services) |
| Package Manager | apt/dnf | Chocolatey |
| Shell | bash | PowerShell |
| Line Endings | LF | CRLF |
| Path Separator | `/` | `\` (escaped as `\\` in HCL) |

## Best Practices

1. **Use Server Core**: Default Windows Server 2025 Core Base for smaller footprint
2. **Monitor Resources**: Windows requires more memory than Linux (minimum 2GB recommended)
3. **Update Regularly**: Keep Windows updates current via AWS Systems Manager
4. **Backup Configs**: Store configuration files in version control
5. **Use Systems Manager**: Prefer AWS Systems Manager over RDP for automation
6. **Security Groups**: Limit RDP access (port 3389) to trusted IPs
7. **Logs**: Regularly review `C:\provision.log` for setup issues
8. **Docker**: Use Windows containers for native performance

## Additional Resources

- [Nomad Windows Support](https://developer.hashicorp.com/nomad/docs/install/windows)
- [Consul Windows Service](https://developer.hashicorp.com/consul/docs/install/windows)
- [NSSM Documentation](https://nssm.cc/)
- [Windows Containers](https://learn.microsoft.com/en-us/virtualization/windowscontainers/)
- [AWS Windows Instances](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/)
