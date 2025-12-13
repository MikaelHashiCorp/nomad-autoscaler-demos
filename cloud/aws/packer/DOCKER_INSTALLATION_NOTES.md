# Docker Installation on Windows Server 2022 AMI

## Issue Identified

Docker installation on Windows Server 2022 via `Install-Package -Name docker -ProviderName DockerMsftProvider` can take **10-20 minutes** or longer, and sometimes hangs indefinitely.

### Root Causes:
1. **Large download size**: Docker package is ~500MB+
2. **Windows Update dependencies**: May trigger Windows Update checks
3. **PowerShell Gallery connectivity**: Can be slow or timeout
4. **Module installation overhead**: DockerMsftProvider itself takes time

## Solution Implemented

### Default Behavior: Docker Installation DISABLED

The [`setup-windows.ps1`](../shared/packer/scripts/setup-windows.ps1:235) script now **skips Docker installation by default** to ensure fast AMI builds (< 10 minutes total).

```powershell
# Set to $false to skip Docker installation (default)
$InstallDocker = $false
```

### Benefits:
- ✅ **Fast builds**: AMI creation completes in ~8-10 minutes
- ✅ **Reliable**: No hanging on Docker installation
- ✅ **Flexible**: Docker can be installed post-launch if needed

## Enabling Docker Installation

If you need Docker pre-installed in the AMI, you have two options:

### Option 1: Enable in Script (Before Build)

Edit [`setup-windows.ps1`](../shared/packer/scripts/setup-windows.ps1:235):
```powershell
$InstallDocker = $true  # Enable Docker installation
```

**Note**: This will add 10-20 minutes to build time and includes:
- 5-minute timeout for DockerMsftProvider module
- 10-minute timeout for Docker package installation
- Automatic failure handling if timeouts occur

### Option 2: Install Docker After Launch

Launch an instance from the AMI and install Docker manually:

```powershell
# On the Windows instance
Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
Install-Package -Name docker -ProviderName DockerMsftProvider -Force

# Start Docker service
Start-Service Docker

# Verify installation
docker version
```

### Option 3: Use User Data Script

Include Docker installation in EC2 user data when launching instances:

```powershell
<powershell>
Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
Install-Package -Name docker -ProviderName DockerMsftProvider -Force
Start-Service Docker
</powershell>
```

## Alternative: Use Windows Container Feature

For faster Docker installation, consider using the Windows Container feature instead:

```powershell
# Faster alternative (requires reboot)
Install-WindowsFeature -Name Containers
# Then install Docker Engine directly
```

## Timeout Protection

When Docker installation is enabled, the script includes timeout protection:

- **DockerMsftProvider**: 5-minute timeout
- **Docker Package**: 10-minute timeout
- **Automatic cleanup**: Jobs are terminated if they exceed timeout
- **Graceful failure**: Build continues even if Docker installation fails

## Recommendations

### For Development/Testing AMIs:
- **Disable Docker** (default) for fast iteration
- Install Docker manually when needed on specific instances

### For Production AMIs:
- **Enable Docker** if all instances will need it
- Accept the longer build time (15-20 minutes total)
- Test the build completes successfully before relying on it

### For Nomad Workloads:
- Docker is **optional** for Nomad
- Nomad can run:
  - `exec` driver (no Docker needed)
  - `raw_exec` driver (no Docker needed)
  - `java` driver (no Docker needed)
  - `docker` driver (requires Docker)

## Build Time Comparison

| Configuration | Typical Build Time |
|--------------|-------------------|
| Without Docker (default) | 8-10 minutes |
| With Docker (enabled) | 18-25 minutes |
| With Docker (if it hangs) | 30+ minutes or timeout |

## Troubleshooting

### If Docker Installation Hangs:
1. Cancel the build (Ctrl+C or `pkill -f "packer build"`)
2. Verify `$InstallDocker = $false` in setup-windows.ps1
3. Restart the build

### If Docker is Needed Post-Build:
1. Launch instance from AMI
2. RDP to the instance
3. Run Docker installation commands manually
4. Create a new AMI from the configured instance

## Future Improvements

Consider these alternatives for faster Docker installation:

1. **Pre-download Docker**: Include Docker binaries in the AMI
2. **Use Chocolatey**: `choco install docker-desktop`
3. **Use Windows Features**: Install Containers feature first
4. **Custom Docker installer**: Download and install Docker directly without PowerShell Gallery