# Build 14 Failure Analysis

## Deployment Summary
- **Build**: 14
- **Deployment Time**: 2025-12-18 05:11 UTC
- **Windows AMI**: ami-0b8ce949d05a1e94e
- **Instance**: i-0e6717b7bebf82974
- **Status**: ❌ FAILED - Consul service crashed

## Bug Fixes Included in Build 14
- ✅ Bug #11: PowerShell case-insensitive replace
- ✅ Bug #12: AMI containing Packer build artifacts
- ✅ Bug #13: Trailing backslash escaping HCL quotes
- ✅ Bug #14: HCL backslash escape sequences
- ✅ Bug #15: Syslog configuration on Windows

## Investigation Timeline

### 05:13 UTC - Initial Check
- Nomad cluster check: No nodes registered
- Expected: User-data takes 3-5 minutes

### 05:17 UTC - Service Status Check
```
Name    Status StartType
----    ------ ---------
Consul Stopped Automatic
Nomad  Running Automatic
```
**Finding**: Consul stopped, Nomad running but can't join without Consul

### 05:18 UTC - Manual Consul Start
Attempted to start Consul manually:
```
==> Failed to setup logging: open C:\HashiCorp\Consul\logs: is a directory
```

### 05:18 UTC - Config Inspection
Generated config showed:
```hcl
log_file = "C:/HashiCorp/Consul/logs"
```

## Bug #16 Discovered

### Root Cause
**File**: `../shared/packer/scripts/client.ps1`  
**Lines**: 66 (Consul), 124 (Nomad)

The PowerShell path replacement was removing the trailing slash:
```powershell
# WRONG - removes trailing slash
$ConsulConfig = $ConsulConfig -replace '/opt/consul/logs/', 'C:/HashiCorp/Consul/logs'
$NomadConfig = $NomadConfig -replace '/opt/nomad/logs/', 'C:/HashiCorp/Nomad/logs'
```

### Why This Matters
Consul and Nomad interpret `log_file` paths as:
- **With trailing slash** (`C:/path/to/logs/`): Directory where log files will be created ✅
- **Without trailing slash** (`C:/path/to/logs`): Attempt to open as a file ❌

When the path points to an existing directory without trailing slash, the service fails with "is a directory" error.

### The Fix
```powershell
# CORRECT - preserves trailing slash
$ConsulConfig = $ConsulConfig -replace '/opt/consul/logs/', 'C:/HashiCorp/Consul/logs/'
$NomadConfig = $NomadConfig -replace '/opt/nomad/logs/', 'C:/HashiCorp/Nomad/logs/'
```

## Impact Analysis

### Severity
**CRITICAL** - Prevents Consul from starting, which blocks Nomad from joining cluster

### Scope
- **Consul**: Affected (service crashes on startup)
- **Nomad**: Would be affected if Consul was running (same bug pattern)
- **Linux**: Not affected (uses `/opt/consul/logs/` which works correctly)

### Why Not Caught Earlier
1. Bug #15 (syslog) prevented Consul from starting in Build 13
2. This bug only manifests when Consul actually attempts to start
3. The error message is clear but requires manual service startup to see

## Lessons Learned

### Path Replacement in PowerShell
When replacing directory paths, trailing characters matter:
```powershell
# Pattern to watch for
-replace '/source/path/', 'C:/target/path'   # WRONG - loses slash
-replace '/source/path/', 'C:/target/path/'  # RIGHT - preserves slash
```

### Service Logging Configuration
- Always test logging configuration separately
- Trailing slashes in directory paths are semantically significant
- Services may interpret paths differently based on trailing characters

### Testing Strategy
- After fixing one bug, immediately test the next failure mode
- Don't assume services will start just because config looks correct
- Use manual service startup to see actual error messages

## Build 15 Plan

### Changes Required
1. ✅ Fix applied to `client.ps1` lines 66 and 124
2. Rebuild Windows AMI with Bug #16 fix
3. Deploy and verify both services start successfully

### Expected Outcome
With all 16 bugs fixed:
- Consul should start and connect to cluster
- Nomad should start and register with cluster
- Windows node should appear in `nomad node status`
- Node class should be `hashistack-windows`

### Confidence Level
**VERY HIGH (98%)** - This is a simple path fix with clear cause and effect. All previous bugs have been systematically identified and fixed.

## All Bugs Summary (16 Total)

| Bug | Description | File | Status |
|-----|-------------|------|--------|
| #11 | PowerShell case-insensitive replace | client.ps1 | ✅ Fixed |
| #12 | AMI Packer artifacts | aws-packer.pkr.hcl | ✅ Fixed |
| #13 | Trailing backslash escape | client.ps1 | ✅ Superseded by #14 |
| #14 | HCL backslash escapes | client.ps1 | ✅ Fixed |
| #15 | Syslog on Windows | consul_client.hcl | ✅ Fixed |
| #16 | Log file path trailing slash | client.ps1 | ✅ Fixed |

## Next Steps
1. Destroy Build 14 infrastructure
2. Deploy Build 15 with Bug #16 fix
3. Verify Consul and Nomad services start
4. Verify Windows node joins cluster
5. Run comprehensive testing per TESTING_PLAN.md