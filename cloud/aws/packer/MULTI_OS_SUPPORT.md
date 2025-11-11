# Multi-OS Support: Ubuntu, RedHat, and Windows Server

This codebase now supports building AMIs with **Ubuntu**, **RedHat Enterprise Linux (RHEL)**, or **Windows Server 2025** as the base operating system.

## Overview of Changes

The following modifications enable multi-OS support while maintaining the original folder structure and following best practices of tight cohesion and loose coupling:

### 1. Packer Configuration (`aws/packer/`)

#### `variables.pkr.hcl`
The OS-related variables remain unchanged and work for all operating systems:
- `variable "os"` - Set to "Ubuntu", "RedHat", or "Windows"
- `variable "os_version"` - OS version (e.g., "24.04" for Ubuntu, "9.6.0" for RHEL, "2025" for Windows)
- `variable "os_name"` - OS codename (e.g., "noble" for Ubuntu, "" for RHEL/Windows)

#### `aws-packer.pkr.hcl`
- **AMI source filter**: Conditionally selects base AMI based on `var.os`
  - Ubuntu: Uses Canonical's AMIs (owner ID: 099720109477)
  - RedHat: Uses Red Hat's AMIs (owner ID: 309956199498)
  - Windows: Uses Amazon's Windows Server AMIs (owner ID: 801119661308)
- **Communicator**: Automatically set to "ssh" for Linux or "winrm" for Windows
- **Username**: Automatically set to "ubuntu", "ec2-user", or "Administrator" based on OS
- **Windows WinRM**: Configured with self-signed certificate via `windows-userdata.txt`
- **OS variable**: Passed to provisioning scripts via `TARGET_OS` environment variable

### 2. Provisioning Scripts (`shared/packer/scripts/`)

#### `os-detect.sh` (Modified)
Central OS detection and configuration script that:
- Detects OS from `/etc/os-release` or `TARGET_OS` environment variable
- Exports OS-specific variables:
  - `HOME_DIR`: "ubuntu", "ec2-user", or "Administrator"
  - `PKG_MANAGER`: "apt-get", "dnf", or "choco"
  - `PKG_UPDATE`: OS-specific update command
  - `PKG_INSTALL`: OS-specific install command
  - `JAVA_HOME`: OS-specific Java path
- Provides helper functions: `pkg_update()`, `pkg_install()`, `log()`
- **Note**: For Windows, this script is included for reference only; Windows uses PowerShell scripts

#### Linux Provisioning Scripts

##### `setup.sh` (Modified)
- Sources `os-detect.sh` at the beginning
- Uses OS-agnostic package management functions
- Conditional logic for OS-specific installations:
  - **Ubuntu**: apt-get, software-properties-common, ec2-instance-connect
  - **RedHat**: dnf, epel-release
- Docker installation adapted for both OS types
- Java installation uses appropriate repositories

##### `client.sh` and `server.sh` (Modified)
- Source `os-detect.sh` to get `HOME_DIR` and `JAVA_HOME`
- Use dynamic `HOME_DIR` instead of hardcoded "ubuntu"
- Use dynamic `JAVA_HOME` from OS detection
- **systemd-resolved compatibility**: Conditional DNS configuration for RedHat 9+ which uses systemd-resolved
  - Creates symbolic link from `/run/systemd/resolve/resolv.conf` to `/etc/resolv.conf` if systemd-resolved is active
  - Restarts systemd-resolved to apply dnsmasq configuration
  - Ensures Docker containers can resolve `.consul` domains

#### Windows Provisioning Scripts

##### `setup.ps1` (New)
PowerShell script for Windows Server provisioning:
- Installs Chocolatey package manager
- Downloads and installs Consul, Nomad, CNI plugins (Windows versions)
- Installs Docker for Windows (container runtime)
- Configures Windows Firewall rules for HashiCorp services
- Copies Windows-specific configuration files
- Sets up logging to `C:\provision.log`

##### `server.ps1` (New)
Windows server configuration script:
- Installs NSSM (Non-Sucking Service Manager) for Windows service management
- Registers Consul and Nomad as Windows services
- Configures services to start automatically
- Sets up service logging

##### `client.ps1` (New)
Windows client configuration script:
- Installs NSSM for service management
- Registers Consul client and Nomad client as Windows services
- Configures Docker service
- Sets environment variables for Nomad plugins
- Verifies Docker service is running

### 3. Configuration Files (`shared/packer/config/`)

#### Linux Configuration Files
- `consul.hcl` / `consul_client.hcl` - Consul configuration with Unix paths
- `nomad.hcl` / `nomad_client.hcl` - Nomad configuration with Unix paths
- `consul_{aws,azure,gcp}.service` - systemd service files for Consul
- `nomad.service` - systemd service file for Nomad
- `10-consul.dnsmasq` - dnsmasq configuration for Consul DNS
- `99-default.dnsmasq.{aws,azure,gcp}` - Cloud-specific DNS fallback

#### Windows Configuration Files (New)
- `consul_windows.hcl` - Consul server configuration with Windows paths (`C:\opt\consul`)
- `consul_client_windows.hcl` - Consul client configuration with Windows paths
- `nomad_windows.hcl` - Nomad server configuration with Windows paths (`C:\opt\nomad`)
- `nomad_client_windows.hcl` - Nomad client configuration with Windows paths
- Services managed via NSSM (Non-Sucking Service Manager) instead of systemd
- No dnsmasq on Windows - uses native Windows DNS

### 4. Terraform Compatibility

The Terraform modules remain mostly unchanged as they:
- Don't directly depend on OS type
- Use the same HashiCorp binary installations (Consul, Nomad, Vault)
- Rely on user-data scripts that call the OS-aware provisioning scripts
- Support Windows with validation in `variables.tf` (valid values: Ubuntu, RedHat, Windows)

## Usage Examples

### Building Ubuntu AMI (Default)

```bash
cd aws/packer/
source env-pkr-var.sh
packer init .
packer validate .
packer build .
```

Or with explicit variables:
```bash
packer build \
  -var 'os=Ubuntu' \
  -var 'os_version=24.04' \
  -var 'os_name=noble' \
  -var 'region=us-west-2' \
  .
```

### Building RedHat AMI

Update `variables.pkr.hcl` or pass variables via command line:
```bash
packer build \
  -var 'os=RedHat' \
  -var 'os_version=9.6.0' \
  -var 'os_name=' \
  -var 'region=us-west-2' \
  .
```

Or create an `auto.pkrvars.hcl` file:
```hcl
os         = "RedHat"
os_version = "9.6.0"
os_name    = ""
```

### Building Windows Server AMI

#### Windows Server 2025 (Latest)
```bash
packer build \
  -var 'os=Windows' \
  -var 'os_version=2025' \
  -var 'os_name=' \
  -var 'region=us-west-2' \
  .
```

#### Windows Server 2022 (Recommended for Production)
```bash
packer build \
  -var 'os=Windows' \
  -var 'os_version=2022' \
  -var 'os_name=' \
  -var 'region=us-west-2' \
  .
```

#### Windows Server 2019
```bash
packer build \
  -var 'os=Windows' \
  -var 'os_version=2019' \
  -var 'os_name=' \
  -var 'region=us-west-2' \
  .
```

Or create an `auto.pkrvars.hcl` file:
```hcl
os         = "Windows"
os_version = "2022"  # or "2025", "2019"
os_name    = ""
```

**Note**: Windows builds use WinRM instead of SSH and may take longer due to Windows updates and software installations. The AMI filter automatically selects the most recent base image for the specified version.

#### Verify Available Windows AMIs

To check available Windows Server AMIs in your region:

**Check HashiCorp AMIs (Priority 1):**
```bash
# Windows Server 2025 from HashiCorp account
aws ec2 describe-images \
  --owners 730335318773 \
  --filters "Name=name,Values=windows_server_2025_core_base*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].[Name,ImageId,CreationDate,OwnerId]' \
  --output table
```

**Check IBM AMIs (Priority 2):**
```bash
# Windows Server from IBM account (currently none available)
aws ec2 describe-images \
  --owners 764552833819 \
  --filters "Name=name,Values=*Windows*Server*" \
  --query 'Images | sort_by(@, &CreationDate) | [-5:].[Name,ImageId,CreationDate,OwnerId]' \
  --output table
```

**Check Amazon Public AMIs (Priority 3 - Fallback):**
```bash
# Windows Server 2022 (recommended for production)
aws ec2 describe-images \
  --owners 801119661308 \
  --filters "Name=name,Values=Windows_Server-2022-English-*-Base-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].[Name,ImageId,CreationDate]' \
  --output table

# Windows Server 2025 (Amazon public)
aws ec2 describe-images \
  --owners 801119661308 \
  --filters "Name=name,Values=Windows_Server-2025-English-*-Base-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].[Name,ImageId,CreationDate]' \
  --output table

# Windows Server 2019
aws ec2 describe-images \
  --owners 801119661308 \
  --filters "Name=name,Values=Windows_Server-2019-English-*-Base-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].[Name,ImageId,CreationDate]' \
  --output table
```

**Check which AMI Packer will use (all three sources):**
```bash
# This shows all matching AMIs from HashiCorp, IBM, and Amazon
aws ec2 describe-images \
  --owners 730335318773 764552833819 801119661308 \
  --filters "Name=name,Values=windows_server_2025_core_base*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].[Name,ImageId,CreationDate,OwnerId]' \
  --output table

# Or check with Amazon's naming pattern (for 2022/2019)
aws ec2 describe-images \
  --owners 730335318773 764552833819 801119661308 \
  --filters "Name=name,Values=Windows_Server-2022-English-*-Base-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].[Name,ImageId,CreationDate,OwnerId]' \
  --output table
```

### Deploying Infrastructure

The Terraform workflow remains the same:
```bash
cd aws/terraform/control/
terraform init
terraform apply
```

The `aws-nomad-image` module will automatically build the correct AMI based on the Packer variables.

#### Deploying with Windows AMI

To deploy infrastructure with Windows Server:

```hcl
# In terraform.tfvars
packer_os         = "Windows"
packer_os_version = "2025"
packer_os_name    = ""
```

Then run:
```bash
cd aws/terraform/control/
terraform init
terraform apply
```

**Note**: Windows instances may take longer to boot and initialize compared to Linux instances.

#### AMI Cleanup Control

You can control whether AMIs are preserved or deleted during `terraform destroy`:

```hcl
# In terraform.tfvars
cleanup_ami_on_destroy = false  # Set to false to keep AMI when running terraform destroy
```

**Default behavior**: AMIs are deregistered and snapshots deleted during destroy (cleanup_ami_on_destroy = true)

**Preserve AMIs**: Set to `false` to keep AMIs for later reuse, saving rebuild time for future deployments

## Key Design Decisions

1. **OS Detection**: Centralized in `os-detect.sh` for Linux; PowerShell environment for Windows
2. **Minimal Refactoring**: Original folder structure preserved
3. **Backward Compatibility**: Default values in `variables.pkr.hcl` maintain Ubuntu as default
4. **Loose Coupling**: Scripts don't hardcode OS-specific values; they derive them from detection
5. **Tight Cohesion**: All OS-specific logic contained within provisioning scripts
6. **Dual Scripting**: Separate script paths for Linux (bash) and Windows (PowerShell) with conditional provisioners
7. **Communicator Flexibility**: Automatic selection between SSH (Linux) and WinRM (Windows) based on OS type
8. **Path Abstraction**: Configuration files use OS-appropriate paths (Unix: `/opt`, Windows: `C:\opt`)

## Supported OS Versions

### Ubuntu
- 24.04 LTS (Noble) - Default
- 22.04 LTS (Jammy)
- 20.04 LTS (Focal)

### RedHat Enterprise Linux
- RHEL 9.6 (Recommended)
- RHEL 9.x series
- RHEL 8.x series

### Windows Server
- **Windows Server 2025** (Latest, released November 2024)
  - Long-term Servicing Channel (LTSC)
  - Support until 2034
  - Best for new deployments and testing latest features
  
- **Windows Server 2022** (Recommended for Production)
  - Long-term Servicing Channel (LTSC)
  - Extended support until October 2031
  - Most stable for production workloads
  - Wide ecosystem support
  
- **Windows Server 2019**
  - Long-term Servicing Channel (LTSC)
  - Extended support until January 2029
  - Mature and stable platform

### Windows AMI Selection

The Packer configuration uses a **three-tier prioritized fallback system** for Windows Server AMIs:

#### Priority Order:
1. **HashiCorp Account AMIs** (Owner: `730335318773`) - **First Priority**
   - Custom Windows Server 2025 Core Base AMIs
   - Pre-configured for HashiCorp workloads
   - Available in: us-west-2 and other select regions
   - Naming pattern: `windows_server_2025_core_base*`
   - **5 AMIs currently available** (as of Nov 2025)

2. **IBM Account AMIs** (Owner: `764552833819`) - **Second Priority**
   - Reserved for IBM-built Windows Server AMIs
   - Currently no Windows Server base AMIs published by IBM
   - Included for future compatibility if IBM publishes Windows images
   - Will be checked if HashiCorp AMIs are unavailable

3. **Amazon Public AMIs** (Owner: `801119661308`) - **Third Priority (Fallback)**
   - Official Amazon Windows Server AMIs
   - Available in all AWS regions
   - Naming pattern: `Windows_Server-{version}-English-*-Base-*`
   - Supports Windows Server 2019, 2022, and 2025
   - Always available as final fallback

#### How It Works:
```hcl
# For Windows Server 2025:
owners = ["730335318773", "764552833819", "801119661308"]
name   = "windows_server_2025_core_base*"  # Matches HashiCorp AMIs first

# For Windows Server 2022 and 2019:
owners = ["730335318773", "764552833819", "801119661308"]
name   = "Windows_Server-{version}-English-*-Base-*"  # Checks all three sources
```

The `most_recent = true` setting ensures you get the latest AMI from the first owner that has a matching image.

**Selection Logic:**
1. Check HashiCorp account → If match found, use it (most recent)
2. If not found, check IBM account → If match found, use it
3. If not found, check Amazon → Use Amazon AMI (always available)

**Core vs Full Edition:**
- **Core**: Smaller footprint (~10GB), no GUI, PowerShell management only
- **Full**: Includes Desktop Experience GUI (~30GB), full admin tools
- **HashiCorp AMIs**: Core edition optimized for Nomad/Consul workloads

**Benefits of HashiCorp AMIs:**
- ✅ Pre-tested with HashiCorp tooling
- ✅ Optimized for Nomad and Consul
- ✅ Regular updates and security patches
- ✅ Smaller footprint for faster deployments

**Note**: You can also use custom Windows AMIs from your organization by:
1. Pre-building a Windows AMI with your requirements
2. Setting `ami` variable in `terraform.tfvars` to skip Packer build
3. Ensuring WinRM is configured if using Packer to customize further

## Notable Differences

| Aspect | Ubuntu | RedHat | Windows |
|--------|--------|--------|---------|
| Default User | ubuntu | ec2-user | Administrator |
| Package Manager | apt-get | dnf | choco |
| Communicator | ssh | ssh | winrm |
| Shell | bash | bash | PowerShell |
| Config Path | /etc/{service}.d | /etc/{service}.d | C:\etc\{service}.d |
| Data Path | /opt/{service} | /opt/{service} | C:\opt\{service} |
| Service Manager | systemd | systemd | Windows Services (NSSM) |
| AMI Owner | Canonical (099720109477) | Red Hat (309956199498) | Amazon (801119661308) |
| AMI Naming | ubuntu/images/*ubuntu-{name}-{version}-amd64-server-* | RHEL-{version}_HVM-*-x86_64-*-Hourly2-GP3 | Windows_Server-{version}-English-Core-Base-* |
| DNS Resolver | resolvconf | systemd-resolved (RHEL 9+) | Windows DNS |
| Firewall | ufw | firewalld | Windows Firewall |

## Windows-Specific Considerations

### AMI Availability and Priority

The Packer configuration uses a **three-tier prioritized multi-source approach**:

**1. HashiCorp Account AMIs (Priority 1)**
- Owner ID: `730335318773`
- Windows Server 2025 Core Base (pre-configured)
- Available in: us-west-2, us-east-1, and select regions
- Optimized for HashiCorp Nomad and Consul workloads
- Regular security updates from HashiCorp
- **Currently available:** 5 Windows Server 2025 Core Base AMIs

**2. IBM Account AMIs (Priority 2)**
- Owner ID: `764552833819`
- Reserved for IBM-built Windows Server images
- **Current status:** No Windows Server base AMIs published
- Included for enterprise compatibility and future use
- Will be checked automatically if HashiCorp AMIs unavailable

**3. Amazon Public AMIs (Priority 3 - Fallback)**
- Owner ID: `801119661308`
- All Windows Server versions (2019, 2022, 2025)
- Available in all AWS regions worldwide
- Automatically updated by Amazon with security patches
- Compatible with AWS Free Tier eligible instances
- Always available as final fallback

**Automatic Selection Logic:**
```
Try HashiCorp AMI → Try IBM AMI → Use Amazon AMI
```
Packer automatically selects the most recent AMI from the first owner that has a matching image.

**Supported Versions:**
- Windows Server 2019: Amazon AMIs in all regions
- Windows Server 2022: Amazon AMIs in all regions (recommended for production)
- Windows Server 2025: HashiCorp AMIs (priority) or Amazon AMIs (fallback)

### WinRM Configuration
- Windows instances use WinRM (Windows Remote Management) instead of SSH
- Packer automatically configures WinRM via `windows-userdata.ps1`
- Self-signed certificate used for HTTPS (port 5986)
- Basic authentication enabled for Packer provisioning

### Service Management
- Consul and Nomad run as Windows Services via NSSM (Non-Sucking Service Manager)
- Services configured to start automatically on boot
- Service logs written to `C:\opt\{service}\{service}.log`
- Provision logs available at `C:\provision.log`

### Networking
- Windows Firewall automatically configured with rules for:
  - Consul: ports 8300-8302, 8500, 8600 (TCP/UDP)
  - Nomad: ports 4646-4648 (TCP/UDP)
  - Dynamic ports: 20000-32000 (TCP)
- No dnsmasq on Windows - Consul DNS must be configured via Windows DNS settings

### Docker on Windows
- Docker for Windows uses Windows containers by default
- Requires Windows Containers feature
- Linux containers on Windows (LCOW) require additional configuration
- Container networking uses Windows HNS (Host Network Service) instead of CNI

### File Paths
- All HashiCorp binaries: `C:\opt\{service}\{service}.exe`
- Configuration files: `C:\etc\{service}.d\`
- Data directories: `C:\opt\{service}\data\`
- Log directories: `C:\opt\{service}\logs\`

### Package Management
- Chocolatey used as package manager (installed during provisioning)
- Common tools installed: 7zip, curl, wget, jq, git
- Windows-specific binaries downloaded (e.g., `consul_windows_amd64.zip`)

### Performance Considerations
- Windows AMI builds take longer than Linux (typically 20-30 minutes)
- Larger AMI size due to Windows base system
- Higher memory requirements recommended (minimum 2GB)
- First boot may be slow due to Windows initialization

### Limitations
- CNI plugins may not be available for all Windows versions
- Some Nomad drivers may not support Windows (check driver documentation)
- Vault integration tested with basic HTTP (no TLS in demo)
- Windows Server Core Base used for smaller footprint (no GUI)

## Troubleshooting

### Issue: Packer fails with "source_ami not found"
- **Ubuntu**: Verify os_name matches a valid Ubuntu codename
- **RedHat**: Ensure os_version matches available RHEL versions in your region
- **Windows**: Verify Windows Server version is available in your region (2025, 2022, 2019)

### Issue: Windows WinRM connection timeout
- **Cause**: WinRM not properly configured or firewall blocking port 5986
- **Solution**: Check `windows-userdata.txt` is being applied and instance has internet access
- **Verification**: Check EC2 console for instance user data and security group rules

### Issue: Package installation fails
- **Linux**: Check that EPEL repository is enabled for RedHat (handled automatically in setup.sh)
- **Windows**: Ensure Chocolatey installed successfully and instance has internet access
- Verify package names are correct for the target OS

### Issue: Docker doesn't start
- **RedHat**: Ensure docker service is enabled and started (handled in setup.sh)
- **Windows**: Check Docker for Windows installed and Windows Containers feature enabled
- Check user permissions: ec2-user/Administrator must be in docker group

### Issue: DNS resolution fails for .consul domains (RedHat 9+)
- **Symptom**: Docker containers can't pull images, `dig @127.0.0.1 consul.service.consul` fails
- **Cause**: systemd-resolved conflict with dnsmasq
- **Solution**: Automatically handled in `client.sh` and `server.sh` - creates symlink and restarts systemd-resolved
- **Verification**: Check `/etc/resolv.conf` points to `/run/systemd/resolve/resolv.conf`

### Issue: Windows services not starting
- **Symptom**: Consul or Nomad services fail to start
- **Cause**: NSSM not installed or configuration file paths incorrect
- **Solution**: Check `C:\opt\consul\consul-error.log` and `C:\opt\nomad\nomad-error.log`
- **Verification**: Run `Get-Service -Name Consul` and `Get-Service -Name Nomad` in PowerShell

### Issue: CNI plugins not found on Windows
- **Cause**: CNI plugins for Windows may not be available for all versions
- **Solution**: This is expected - Windows containers use different networking (HNS)
- **Workaround**: Use Docker driver without CNI plugins for Windows workloads

## Testing

To verify the build works for all OS types:

1. Build Ubuntu AMI:
   ```bash
   packer build -var 'os=Ubuntu' -var 'os_version=24.04' -var 'os_name=noble' .
   ```

2. Build RedHat AMI:
   ```bash
   packer build -var 'os=RedHat' -var 'os_version=9.6.0' -var 'os_name=' .
   ```

3. Build Windows Server AMI (2019, 2022, or 2025):
   ```bash
   # Windows Server 2022 (recommended)
   packer build -var 'os=Windows' -var 'os_version=2022' -var 'os_name=' .
   
   # Or Windows Server 2025
   packer build -var 'os=Windows' -var 'os_version=2025' -var 'os_name=' .
   
   # Or Windows Server 2019
   packer build -var 'os=Windows' -var 'os_version=2019' -var 'os_name=' .
   ```

4. Deploy and verify:
   
   **Linux (Ubuntu/RedHat)**:
   - SSH into instances: `ssh ubuntu@<ip>` or `ssh ec2-user@<ip>`
   - Check `echo $HOME_DIR` matches expected user
   - Verify HashiCorp services: `consul members`, `nomad node status`
   - Test Docker: `docker ps`
   
   **Windows**:
   - RDP into instances or use AWS Systems Manager Session Manager
   - Check services: `Get-Service -Name Consul,Nomad` in PowerShell
   - Verify HashiCorp services: `C:\opt\consul\consul.exe members`, `C:\opt\nomad\nomad.exe node status`
   - Test Docker: `docker ps`
   - Check logs: `C:\opt\consul\consul.log`, `C:\opt\nomad\nomad.log`, `C:\provision.log`
