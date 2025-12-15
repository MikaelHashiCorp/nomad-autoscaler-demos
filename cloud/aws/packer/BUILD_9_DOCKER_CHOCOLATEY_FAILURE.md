# Build #9: Docker via Chocolatey - FAILED

## Build Information
- **Date**: 2025-12-14 17:16:22 PST
- **Duration**: 12 minutes 18 seconds
- **Status**: ❌ FAILED
- **Exit Code**: 4294967295
- **Log File**: `logs/mikael-CCWRLY72J2_packer_20251215-011621.974Z.out`

## Objective
Test Docker installation via Chocolatey package manager instead of manual installation to reduce code complexity.

## Changes from Build #8
- Replaced manual Docker installation (92 lines) with Chocolatey-based installation (75 lines)
- Used `choco install docker-engine --version=24.0.7 -y --force`
- Pinned to version 24.0.7 to match previous manual installation
- Total script reduction: 76 lines (662 → 586 lines, 11.5% reduction)

## Build Results

### ✅ Successful Components
1. **HashiStack Installation**: All components installed successfully
   - Consul v1.22.1
   - Nomad v1.11.1
   - Vault v1.21.1

2. **Chocolatey Installation**: v2.6.0 installed successfully

3. **SSH Server Installation**: OpenSSH installed and configured via Chocolatey
   - Service running
   - Firewall configured (port 22)
   - RSA key authentication enabled
   - SSH key injection scheduled task created

4. **Windows Containers Feature**: Installed successfully
   - **WARNING**: "You must restart this server to finish the installation process"

5. **Docker Installation**: Chocolatey package installed successfully
   - Downloaded docker-24.0.7.zip (34.2 MB)
   - Extracted to C:\Program Files\Docker
   - Service registered
   - Administrator added to docker-users group

### ❌ Failed Component: Docker Service Startup

**Error Message**:
```
Docker installation encountered an issue:
  Error: error during connect: in the default daemon configuration on Windows, 
  the docker client must be run with elevated privileges to connect: 
  Get "http://%2F%2F.%2Fpipe%2Fdocker_engine/v1.24/version": 
  open //./pipe/docker_engine: The system cannot find the file specified.
```

**Exit Code**: 4294967295 (PowerShell script error)

## Root Cause Analysis

### Primary Issue: Windows Containers Requires Reboot
The Windows Containers feature installation explicitly warns:
```
WARNING: You must restart this server to finish the installation process.
```

**Timeline of Events**:
1. Windows Containers feature installed → **Reboot required**
2. Docker installed via Chocolatey → Service registered
3. Script attempts to start Docker service → **Fails** (named pipe not available)
4. Script attempts `docker version` verification → **Fails** (can't connect to daemon)
5. Error thrown, script exits with non-zero code

### Technical Details

**Named Pipe Issue**:
- Docker on Windows uses named pipe: `\\.\pipe\docker_engine`
- Named pipe is created when Docker daemon starts
- Docker daemon requires Windows Containers feature to be fully initialized
- Windows Containers feature requires reboot to complete initialization
- Without reboot: named pipe doesn't exist → Docker can't start → verification fails

**Error Handling Issue**:
The script has a try-catch block (lines 489-560), but the error was still thrown because:
1. The `docker version` command at line 539 failed
2. The error was caught and displayed
3. However, the script still exited with error code 4294967295

## Comparison: Manual vs Chocolatey Installation

### Build #7 & #8 (Manual Installation) ✅
- **Method**: Download ZIP, extract, register service manually
- **Result**: Docker persisted in AMI and worked correctly
- **Why it worked**: Manual installation included explicit reboot handling

### Build #9 (Chocolatey Installation) ❌
- **Method**: `choco install docker-engine --version=24.0.7`
- **Result**: Installation succeeded, but verification failed
- **Why it failed**: No reboot between Windows Containers and Docker verification

## Solution Options

### Option 1: Add Reboot After Windows Containers (RECOMMENDED)
**Approach**: Add explicit reboot step after Windows Containers installation
```powershell
# Install Windows Containers
Install-WindowsFeature -Name Containers -ErrorAction Stop

# Reboot to complete Windows Containers installation
Write-Host "Rebooting to complete Windows Containers installation..."
Restart-Computer -Force
```

**Pros**:
- Matches Windows best practices
- Ensures Docker can start properly
- Chocolatey installation is cleaner than manual

**Cons**:
- Adds reboot time to build (~2-3 minutes)
- Requires Packer restart provisioner configuration

### Option 2: Make Docker Verification Non-Fatal
**Approach**: Catch Docker verification error and continue
```powershell
try {
    $dockerVersion = & docker version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Docker is working correctly"
    } else {
        Write-Host "  [WARN] Docker verification failed - will work after first boot"
    }
} catch {
    Write-Host "  [WARN] Docker verification skipped - will work after first boot"
}
# Don't throw error - continue script
```

**Pros**:
- No reboot required during build
- Faster build time
- Docker will work after instance first boot

**Cons**:
- Can't verify Docker during build
- Relies on Docker working after AMI snapshot

### Option 3: Revert to Manual Installation (SAFEST)
**Approach**: Keep Build #8 configuration with manual Docker installation

**Pros**:
- Known working solution
- Already tested and verified
- No risk

**Cons**:
- More code (92 lines vs 75 lines)
- Less maintainable
- Misses code reduction benefit

## Recommendation

**Revert to Build #8 (Manual Installation)** for the following reasons:

1. **Proven Solution**: Build #8 is tested and working
2. **Risk vs Reward**: 17-line code reduction (18%) doesn't justify the risk
3. **Complexity**: Adding reboot handling adds complexity
4. **Time Pressure**: Manual installation works reliably

### Why Not Fix It?

While Option 1 (add reboot) would work, it introduces:
- Additional Packer configuration complexity (restart provisioner)
- Longer build times (reboot adds 2-3 minutes)
- More points of failure (reboot handling)
- Unproven in our environment

The manual installation is:
- Battle-tested (Builds #7 and #8)
- Reliable and predictable
- Well-documented
- Only 17 lines longer

## Next Steps

1. ✅ Document Build #9 failure (this document)
2. ⏳ Revert to Build #8 Docker installation method
3. ⏳ Validate packer configuration
4. ⏳ Keep Build #8 as production AMI (ami-0a7ba5fe6ab153cd6)

## Lessons Learned

1. **Windows Containers Requires Reboot**: Always reboot after installing Windows Containers feature
2. **Named Pipe Dependencies**: Docker daemon needs Windows Containers fully initialized
3. **Error Handling**: PowerShell exit codes can be tricky (4294967295 = -1 in unsigned)
4. **Code Reduction Trade-offs**: Simpler isn't always better if it introduces instability
5. **Stick with Working Solutions**: When you have a proven solution, the burden of proof is on the new approach

## Build Timeline

```
17:16:22 - Build started
17:24:52 - HashiStack installation complete (8m 30s)
17:25:54 - Chocolatey installation complete (1m 2s)
17:26:16 - SSH installation complete (22s)
17:27:36 - Docker installation complete (1m 20s)
17:27:39 - Docker verification FAILED
17:27:39 - Build terminated with error
17:28:41 - Cleanup complete
Total: 12m 18s
```

## Conclusion

Build #9 demonstrated that while Chocolatey can install Docker successfully, the Windows Containers feature requirement for a reboot creates a timing issue that's not worth solving for a 17-line code reduction. The manual installation method from Build #8 remains the recommended approach.

**Production AMI**: Build #8 (ami-0a7ba5fe6ab153cd6) remains the current production AMI.