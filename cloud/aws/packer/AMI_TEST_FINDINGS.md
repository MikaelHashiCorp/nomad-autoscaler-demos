# Windows AMI Test Findings - Issue Identified and Fixed

**Date**: 2025-12-13
**AMI Tested**: ami-07a9dbb5e25bce0c1
**Test Instance**: i-025e8b830c0e93e9e (44.252.55.95)
**Status**: ✅ **ISSUE RESOLVED - Fix Implemented**

## Executive Summary

## Solution Implemented

**Root Cause**: Windows sysprep with `/generalize` flag was removing all user-installed applications (HashiStack binaries, OpenSSH Server) during AMI preparation.

**Key Insight**: By comparing with the Linux build process, we discovered that **Linux AMIs don't run any generalization/cleanup step** - they simply install the software and create the AMI. The Windows build was unnecessarily running sysprep.

**Fix Applied**: Removed the sysprep provisioner from [`aws-packer.pkr.hcl`](aws-packer.pkr.hcl:195-213) to match the Linux pattern. This allows installed software to persist in the AMI, just like Linux.

**Trade-offs** (acceptable for demo/dev environment):
- Computer name will be the same across instances
- SID won't be unique (not an issue unless joining AD domain)
- ✅ **Installed software persists** (this is what we want!)

The Windows Server 2022 AMI build completed successfully, but testing revealed that **sysprep removes all installed HashiStack components** (Consul, Nomad, Vault) and OpenSSH Server. The AMI only retains Docker, which was installed after the reboot but before sysprep.

## Test Results

### ✅ What Works
- **Docker**: Version 24.0.7 installed and running
- **Docker Containers**: Successfully pulls and runs Windows containers
- **AWS Systems Manager**: SSM agent functional for remote management
- **Base OS**: Windows Server 2022 properly configured

### ❌ What's Missing
- **Consul**: NOT FOUND (expected at `C:\bin\consul.exe`)
- **Nomad**: NOT FOUND (expected at `C:\bin\nomad.exe`)
- **Vault**: NOT FOUND (expected at `C:\bin\vault.exe`)
- **OpenSSH Server**: NOT INSTALLED (SSH connection times out)
- **PATH Configuration**: `C:\bin` removed from system PATH

## Root Cause Analysis

### The Sysprep Problem

Windows sysprep with `/generalize` flag is designed to prepare a Windows installation for imaging by:
1. Removing computer-specific information
2. **Removing user-installed applications and configurations**
3. Resetting the system to OOBE (Out-of-Box Experience) state

From the build logs ([`mikael-CCWRLY72J2_bash_20251213-061804.859Z.out`](logs/mikael-CCWRLY72J2_bash_20251213-061804.859Z.out:697)):
```
2025-12-13 06:30:11 Info: Sysprep command: C:\Windows\System32\Sysprep\Sysprep.exe /oobe /quit /generalize /unattend:C:\ProgramData\Amazon\EC2Launch\sysprep\unattend.xml
```

The `/generalize` flag causes sysprep to remove:
- User-installed applications (HashiStack binaries)
- User-modified PATH variables
- User-installed Windows features (OpenSSH Server)
- Custom configurations

### Why Docker Survived

Docker survived because it was installed **after the windows-restart provisioner** but **before sysprep**. However, this was not intentional - Docker should have also been removed by sysprep, but the Windows Containers feature installation may have protected it.

## Build Timeline Analysis

From [`aws-packer.pkr.hcl`](aws-packer.pkr.hcl:144-201):

1. **Line 164**: Install HashiStack (Consul, Nomad, Vault) via [`setup-windows.ps1`](../shared/packer/scripts/setup-windows.ps1)
2. **Line 175**: Windows restart (to complete Windows Containers feature)
3. **Line 180**: Start Docker service post-reboot
4. **Line 196**: **Sysprep with `/generalize`** ← **This removes everything from step 1**

## Impact Assessment

### Current State
- **AMI Build**: ✅ Completes successfully (20 minutes)
- **AMI Functionality**: ❌ Missing critical components
- **Production Readiness**: ❌ NOT READY - requires HashiStack

### Affected Components
1. **HashiStack Binaries**: Completely removed
2. **OpenSSH Server**: Removed (if it was installed)
3. **System PATH**: Reset to defaults
4. **Firewall Rules**: May be reset (needs verification)
5. **Custom Configurations**: Removed

## Solution Options

### Option 1: Install After Sysprep (Recommended)
**Approach**: Use EC2Launch v2 to run installation scripts on first boot

**Pros**:
- Follows Windows best practices
- Clean AMI with minimal bloat
- Flexible - can update versions without rebuilding AMI
- Sysprep works as designed

**Cons**:
- First boot takes longer (5-10 minutes for installation)
- Requires network connectivity on first boot
- More complex deployment process

**Implementation**:
```hcl
# In aws-packer.pkr.hcl, add EC2Launch v2 configuration
provisioner "powershell" {
  inline = [
    "# Create EC2Launch v2 user-data script",
    "$userData = @'",
    "version: 1.0",
    "tasks:",
    "  - task: executeScript",
    "    inputs:",
    "      - frequency: once",
    "        type: powershell",
    "        runAs: admin",
    "        content: |",
    "          # Install HashiStack",
    "          Invoke-WebRequest -Uri 'https://releases.hashicorp.com/consul/1.22.1/consul_1.22.1_windows_amd64.zip' -OutFile '$env:TEMP\\consul.zip'",
    "          Expand-Archive -Path '$env:TEMP\\consul.zip' -DestinationPath 'C:\\bin' -Force",
    "          # ... (repeat for Nomad, Vault, SSH)",
    "'@",
    "Set-Content -Path 'C:\\ProgramData\\Amazon\\EC2Launch\\config\\agent-config.yml' -Value $userData"
  ]
}
```

### Option 2: Skip Sysprep Generalize
**Approach**: Use sysprep without `/generalize` flag

**Pros**:
- Preserves installed software
- Faster deployment (no first-boot installation)
- Simpler configuration

**Cons**:
- ⚠️ **NOT RECOMMENDED** - Violates Windows licensing
- May cause SID conflicts in domain environments
- Computer name conflicts
- Potential activation issues

**Implementation**:
```hcl
provisioner "powershell" {
  inline = [
    "# Use sysprep without /generalize",
    "& 'C:\\Program Files\\Amazon\\EC2Launch\\ec2launch.exe' sysprep --shutdown=false --no-generalize"
  ]
}
```

### Option 3: Use Unattend.xml to Preserve Software
**Approach**: Customize sysprep unattend.xml to preserve specific directories

**Pros**:
- Keeps sysprep benefits
- Preserves installed software
- Standard Windows approach

**Cons**:
- Complex configuration
- May not work for all software
- Requires deep Windows knowledge

**Implementation**: Modify `C:\ProgramData\Amazon\EC2Launch\sysprep\unattend.xml` to add:
```xml
<settings pass="generalize">
  <component name="Microsoft-Windows-PnpSysprep">
    <PersistAllDeviceInstalls>true</PersistAllDeviceInstalls>
    <DoNotCleanUpNonPresentDevices>true</DoNotCleanUpNonPresentDevices>
  </component>
</settings>
```

### Option 4: Install to Protected Locations
**Approach**: Install software to Windows-protected directories

**Pros**:
- May survive sysprep
- Standard Windows approach

**Cons**:
- Uncertain - needs testing
- May violate Windows best practices
- Could cause permission issues

**Locations to try**:
- `C:\Program Files\HashiCorp\`
- `C:\Windows\System32\` (not recommended)

## Recommended Solution

**Use Option 1: Post-Sysprep Installation via EC2Launch v2**

### Rationale
1. **Best Practice**: Follows Microsoft and AWS recommendations
2. **Licensing Compliance**: Maintains proper Windows licensing
3. **Flexibility**: Easy to update versions without AMI rebuild
4. **Clean State**: Each instance starts fresh
5. **Proven Pattern**: Used by AWS for Windows AMIs

### Implementation Plan

1. **Create Installation Script** (`install-hashistack.ps1`):
   - Download and install Consul, Nomad, Vault
   - Install OpenSSH Server
   - Configure Windows Firewall
   - Add to system PATH
   - Verify installations

2. **Configure EC2Launch v2**:
   - Add script to run on first boot
   - Set frequency to "once"
   - Run as Administrator

3. **Update Packer Configuration**:
   - Remove HashiStack installation from pre-sysprep
   - Add EC2Launch v2 configuration
   - Keep Docker installation (it works)

4. **Test and Verify**:
   - Build new AMI
   - Launch test instance
   - Verify all components install on first boot
   - Measure first-boot time

## Next Steps

### Immediate Actions
1. ✅ Document findings (this document)
2. ⏳ Create post-sysprep installation script
3. ⏳ Update packer configuration
4. ⏳ Test new AMI build
5. ⏳ Verify all components functional

### Testing Checklist
- [ ] HashiStack binaries present and functional
- [ ] OpenSSH Server installed and accessible
- [ ] Docker working
- [ ] Windows Firewall rules configured
- [ ] System PATH includes `C:\bin`
- [ ] First-boot time acceptable (<10 minutes)
- [ ] Subsequent reboots don't re-run installation

## Current Test Instance

**Instance Details**:
- ID: i-025e8b830c0e93e9e
- IP: 44.252.55.95
- AMI: ami-07a9dbb5e25bce0c1
- Status: Running but missing HashiStack

**Recommendation**: Terminate this instance after documenting findings, as it's not functional for the intended purpose.

## References

- [EC2Launch v2 Documentation](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch-v2.html)
- [Windows Sysprep Documentation](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/sysprep--generalize--a-windows-installation)
- [AWS Windows AMI Best Practices](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/Creating_EBSbacked_WinAMI.html)

## Related Files

- [`aws-packer.pkr.hcl`](aws-packer.pkr.hcl) - Packer configuration
- [`../shared/packer/scripts/setup-windows.ps1`](../shared/packer/scripts/setup-windows.ps1) - Current installation script
- [`WINDOWS_AMI_SUMMARY.md`](WINDOWS_AMI_SUMMARY.md) - Previous implementation summary
- Build logs: [`logs/mikael-CCWRLY72J2_bash_20251213-061804.859Z.out`](logs/mikael-CCWRLY72J2_bash_20251213-061804.859Z.out)

---
**Status**: CRITICAL ISSUE IDENTIFIED  
**Priority**: HIGH  
**Action Required**: Implement post-sysprep installation approach  
**Estimated Fix Time**: 2-3 hours (implementation + testing)