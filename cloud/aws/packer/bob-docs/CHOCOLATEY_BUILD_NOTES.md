# Windows AMI Build - Chocolatey Docker Implementation

## Build Information
- **Date**: 2025-12-13
- **Instance ID**: i-05a0a657c7a323525
- **Public IP**: 44.248.14.68
- **Build Name**: windows.amazon-ebs.hashistack

## Key Changes from Previous Build

### 1. Installation Order (CRITICAL)
```
Previous: HashiStack → Docker → SSH (failed)
New:      SSH → HashiStack → Docker (current)
```

**Rationale**: SSH must be installed FIRST to ensure immediate connectivity and proper system integration before any other components.

### 2. Docker Installation Method
```
Previous: Manual download from docker.com (failed to persist in AMI)
New:      Chocolatey package manager (expected to persist)
```

**Why Chocolatey**:
- Package managers integrate better with Windows system state
- Similar to how Linux apt/dnf installations persist in AMIs
- Matches the pattern of HashiStack binaries (which DO persist)
- Better service registration and system integration

### 3. SSH Configuration Enhancements
- **RSA Key Support**: Explicitly enabled in sshd_config
- **PubkeyAuthentication**: Set to `yes`
- **PubkeyAcceptedKeyTypes**: Includes `+ssh-rsa`
- **Service Configuration**: Automatic startup with proper error handling

## Script Structure

### Step 1: OpenSSH Server (Lines 16-120)
- Install OpenSSH capability
- Configure for RSA key authentication
- Start and enable service
- Configure firewall rules
- **CRITICAL**: Fails build if SSH installation fails

### Step 2: HashiStack Components (Lines 122-240)
- Fetch latest versions (or use environment variables)
- Download and install Consul, Nomad, Vault
- Configure PATH
- Verify installations
- Configure firewall rules

### Step 3: Docker via Chocolatey (Lines 242-412)
- Install Windows Containers feature
- Install Chocolatey package manager
- Install docker-engine via Chocolatey
- Configure Docker service
- Set automatic startup
- Configure service recovery

## Expected Outcomes

### ✅ Should Persist in AMI:
1. OpenSSH Server (installed first, system-level)
2. Consul, Nomad, Vault binaries (proven to persist)
3. Docker (via Chocolatey package manager)
4. Chocolatey package manager itself
5. Windows Containers feature
6. All firewall rules
7. Service configurations

### 🔍 To Verify After Build:
1. SSH connectivity with RSA key pair
2. Docker service present and configured
3. Docker command available in PATH
4. Chocolatey installation present
5. All HashiStack binaries functional

## Testing Plan

After AMI creation:
1. Launch test instance from new AMI
2. Verify SSH connection with RSA key
3. Check Docker service status
4. Run `docker version` command
5. Verify HashiStack components
6. Check Chocolatey installation

## Previous Build Results (for comparison)

**AMI**: ami-06c4197a7d34335da (manual Docker installation)
- ✅ HashiStack: Present and functional
- ❌ Docker: Completely missing from AMI
- ❌ SSH: Installation failed during build

## Build Log Location
- Log file: `packer/logs/mikael-CCWRLY72J2_packer_20251213-212405.358Z.out`
- Note: Log file does not include timestamps (logcmd limitation)

## Next Steps After Build Completes
1. Note the new AMI ID
2. Launch test instance
3. Verify all three components (SSH, HashiStack, Docker)
4. Test SSH with RSA key pair
5. Document final results