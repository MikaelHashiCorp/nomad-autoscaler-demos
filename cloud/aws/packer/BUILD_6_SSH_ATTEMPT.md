# Build #6 - SSH Server Installation Attempt

## Build Information
- **AMI ID**: ami-0ef70213fa4488403
- **Build Name**: scale-mws-1765752151
- **Created**: 2025-12-14T22:56:26.000Z
- **Status**: Available
- **Build Duration**: ~15 minutes (14:41 - 14:56)

## Build Objectives (STEP 2)
Add OpenSSH Server installation to the Windows AMI with RSA key authentication support.

## Components Installed

### ✅ Successfully Installed
1. **HashiStack**
   - Consul 1.22.1
   - Nomad 1.11.1
   - Vault 1.21.1
   - All binaries in C:\HashiCorp\bin
   - Firewall rules configured (15 rules)

2. **Chocolatey Package Manager**
   - Version: 2.6.0
   - Installation path: C:\ProgramData\chocolatey
   - Successfully verified

3. **Windows Containers Feature**
   - Installed successfully
   - Required system reboot

4. **Docker Engine**
   - Version: 24.0.7
   - Installation path: C:\Program Files\Docker
   - Service registered and configured for automatic startup
   - **VERIFIED WORKING** after reboot
   - Docker version command successful

### ⚠️ Failed Installation
**OpenSSH Server**
- **Error**: "Access is denied"
- **Attempted**: Twice (before and after reboot)
- **Method Used**: `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0`
- **Impact**: Non-critical, build continued
- **Root Cause**: Insufficient permissions or Windows capability installation restrictions

## Key Findings

### 1. Docker Persistence SUCCESS! 🎉
The major breakthrough: Docker service is now **running and functional** after reboot:
```
Client:
 Version:           24.0.7
 API version:       1.43
 Go version:        go1.20.10

Server: Docker Engine - Community
 Engine:
  Version:          24.0.7
  API version:      1.43 (minimum version 1.24)
```

This is a significant improvement over previous builds where Docker disappeared from the AMI.

### 2. SSH Installation Failure
The `Add-WindowsCapability` cmdlet failed with "Access is denied" error. This suggests:
- The WinRM session may not have sufficient privileges
- Windows capability installation may require different approach
- Alternative methods needed (Chocolatey, manual installation, or different PowerShell approach)

### 3. Script Bug Identified
Line in final verification script references wrong path:
```powershell
Get-ChildItem C:\bin\*.exe  # WRONG - should be C:\HashiCorp\bin
```

## Build Log Issues
The updated `run-with-timestamps.sh` script did not capture build output to log file. Only validation output was logged. The terminal showed all output but `tee` didn't write to the log file properly. This needs investigation.

## Next Steps

### Immediate: Fix SSH Installation
**Priority**: Implement RSA key-based SSH authentication

**Option 1: Use Chocolatey** (Recommended)
```powershell
choco install openssh -y --params '"/SSHServerFeature"'
```

**Option 2: Manual Installation**
- Download OpenSSH-Win64.zip from GitHub releases
- Extract to C:\Program Files\OpenSSH
- Run install-sshd.ps1
- Configure service and firewall

**Option 3: Different PowerShell Approach**
- Use `Install-Module -Name OpenSSHUtils`
- Try elevated PowerShell session
- Use DISM instead of Add-WindowsCapability

### SSH Configuration Requirements
Once installed, configure for RSA key authentication:
1. Enable PubkeyAuthentication
2. Set PubkeyAcceptedKeyTypes to include ssh-rsa
3. Configure authorized_keys location
4. Set proper permissions on SSH directories
5. Restart sshd service

### Fix Script Bug
Update final verification script to use correct path:
```powershell
Get-ChildItem C:\HashiCorp\bin\*.exe
```

### Fix Logging
Investigate why `run-with-timestamps.sh` isn't writing to log file despite using `tee`.

## Comparison with Previous Builds

| Component | Build #5 (Chocolatey) | Build #6 (SSH Attempt) |
|-----------|----------------------|------------------------|
| HashiStack | ✅ Working | ✅ Working |
| Chocolatey | ✅ v2.6.0 | ✅ v2.6.0 |
| Docker | ✅ Working | ✅ Working (verified!) |
| SSH Server | ❌ Not attempted | ⚠️ Failed installation |
| Build Time | 20m 19s | ~15m |

## Conclusion
Build #6 successfully maintains all functionality from Build #5 and confirms Docker persistence after reboot. The SSH Server installation failure is a setback but non-critical. Multiple alternative approaches are available for the next build iteration.

**Status**: STEP 2 partially complete - Docker verified, SSH needs alternative approach
**Next Build**: STEP 2 retry with Chocolatey-based SSH installation