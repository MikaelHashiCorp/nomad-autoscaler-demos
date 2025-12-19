# Build 13 Failure Analysis

**Date**: 2025-12-18 03:57 UTC  
**Build**: 13  
**AMI**: ami-01684ca0a51b5d4f0  
**Instance**: i-04ee17fbb7deb2506  
**Status**: ❌ FAILED - Consul service crashes on startup

## Executive Summary

Build 13 was deployed with all four bug fixes (Bugs #11, #12, #13, #14) to test the complete solution. The deployment succeeded, user-data executed without errors, and both services were created. However, **Bug #15 was discovered**: Consul crashes immediately on startup due to syslog configuration incompatibility with Windows.

## Investigation Timeline

### 1. Initial Check (03:40 UTC)
- Verified infrastructure deployed: 30 resources created
- Checked instance status: Running
- Attempted to verify Nomad cluster registration: **Node not appearing**

### 2. Service Status Check (03:42 UTC)
```powershell
Get-Service consul,nomad
Name    Status StartType
----    ------ ---------
Consul  Running Automatic
Nomad   Running Automatic
```
**Initial observation**: Both services appeared to be running

### 3. Cluster Registration Check (03:43 UTC)
```bash
nomad node status
# No Windows node appeared in cluster
```

### 4. Consul Connectivity Check (03:44 UTC)
```powershell
consul catalog services
# Returned empty - Consul not connected to cluster!
```

### 5. Configuration Verification (03:45 UTC)
Verified configs were correct:
- ✅ Forward slashes in all paths (Bug #14 fix)
- ✅ `node_class = "hashistack-windows"` (Bug #11b fix)
- ✅ `retry_join` configured correctly (Bug #11a fix)
- ✅ Server has ConsulAutoJoin tag
- ✅ IAM role has ec2:DescribeInstances permission

### 6. Service Status Re-check (03:52 UTC)
```powershell
Get-Service consul
Name    Status StartType
----    ------ ---------
Consul Stopped Automatic
```
**CRITICAL**: Service had crashed! Initial check was misleading.

### 7. Executable Location Check (03:53 UTC)
```powershell
Test-Path C:\HashiCorp\Consul\consul.exe
False

Get-ChildItem C:\HashiCorp -Recurse -File | Where-Object {$_.Name -like "*.exe"}
FullName                       Length
--------                       ------
C:\HashiCorp\bin\consul.exe 188487560
C:\HashiCorp\bin\nomad.exe  150680968
C:\HashiCorp\bin\vault.exe  516030856
```
**Finding**: Executables are in `C:\HashiCorp\bin\`, service path is correct

### 8. Service Configuration Check (03:53 UTC)
```
SERVICE_NAME: consul
BINARY_PATH_NAME: C:\HashiCorp\bin\consul.exe agent -config-dir=C:\HashiCorp\Consul
```
**Finding**: Service configuration is correct

### 9. Manual Consul Startup (03:57 UTC)
```powershell
C:\HashiCorp\bin\consul.exe agent -config-dir=C:\HashiCorp\Consul
```
**ERROR OUTPUT**:
```
==> Syslog setup did not succeed within timeout (1m0s).
```

## Root Cause: Bug #15 - Syslog Configuration

**Bug #15**: Consul config has `enable_syslog = true` but Windows doesn't have syslog by default, causing Consul to timeout and crash on startup.

### Technical Details

**Config File**: `C:\HashiCorp\Consul\consul.hcl`
```hcl
enable_syslog  = true
log_level      = "TRACE"
log_file       = "C:/HashiCorp/Consul/logs"
```

**Problem**: 
- `enable_syslog = true` tells Consul to send logs to syslog
- Windows doesn't have syslog daemon by default
- Consul waits 1 minute for syslog connection
- After timeout, Consul exits with error
- Service crashes immediately on startup

**Why This Wasn't Caught Earlier**:
1. The config template is shared between Linux and Windows
2. Linux has syslog by default, so it works fine
3. Windows needs either:
   - `enable_syslog = false` (use file logging only)
   - A syslog daemon installed (e.g., nxlog, syslog-ng)

## Impact Assessment

### What Works ✅
1. Infrastructure deployment (30 resources)
2. AMI creation with all binaries
3. User-data execution (no errors)
4. Service creation (both Consul and Nomad)
5. Config file generation with correct syntax
6. All previous bug fixes (Bugs #11-14) are working

### What Fails ❌
1. Consul service crashes on startup
2. Nomad cannot discover servers (depends on Consul)
3. Windows node cannot join cluster
4. No cluster connectivity

## Bug #15 Details

| Property | Value |
|----------|-------|
| **Bug ID** | #15 |
| **Title** | Syslog configuration incompatible with Windows |
| **Severity** | Critical |
| **Component** | Consul configuration |
| **File** | `../shared/packer/config/consul_client.hcl` |
| **Line** | 6 |
| **Root Cause** | `enable_syslog = true` requires syslog daemon not present on Windows |
| **Impact** | Consul crashes immediately on startup |
| **Fix** | Set `enable_syslog = false` for Windows clients |

## Solution

### Option 1: Disable Syslog (Recommended)
Change `consul_client.hcl`:
```hcl
enable_syslog  = false  # Windows doesn't have syslog
log_level      = "TRACE"
log_file       = "C:/HashiCorp/Consul/logs"
```

### Option 2: Install Syslog Daemon (Not Recommended)
- Install nxlog or syslog-ng on Windows
- More complex, adds dependency
- Not necessary since file logging works fine

## Next Steps

1. **Fix Bug #15**: Update `consul_client.hcl` to disable syslog
2. **Apply Same Fix to Nomad**: Check if `nomad_client.hcl` has same issue
3. **Build 14**: Deploy with Bug #15 fix
4. **Verify**: Confirm services start and stay running
5. **Test**: Complete TESTING_PLAN.md validation

## Lessons Learned

1. **Platform-Specific Configs**: Shared configs between Linux/Windows need platform checks
2. **Service Monitoring**: Initial service status can be misleading - services may crash after starting
3. **Error Messages**: Syslog timeout error is clear but only visible when running manually
4. **Testing Strategy**: Need to verify services stay running, not just start successfully

## Build History Summary

| Build | Bugs Fixed | Result | Issue |
|-------|------------|--------|-------|
| 9 | - | ❌ Failed | Bug #11: Case-insensitive replace |
| 10 | #11 | ❌ Failed | Bug #12: AMI Packer artifacts |
| 11 | #11, #12 | ❌ Failed | Bug #13: Trailing backslash |
| 12 | #11, #12, #13 | ❌ Failed | Bug #14: HCL backslash escape |
| 13 | #11, #12, #13, #14 | ❌ Failed | Bug #15: Syslog on Windows |

## Conclusion

Build 13 successfully validated that Bugs #11-14 are fixed. The discovery of Bug #15 (syslog configuration) is the final blocker preventing Windows clients from joining the Nomad cluster. This is a simple configuration fix that should resolve the issue in Build 14.

**Status**: Ready to proceed with Bug #15 fix and Build 14 deployment.
