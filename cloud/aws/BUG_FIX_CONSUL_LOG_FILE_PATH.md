# Bug #16: Consul log_file Path Missing Trailing Slash

## Discovery
**Date**: 2025-12-18 05:18 UTC (Build 14)  
**Instance**: i-0e6717b7bebf82974  
**Symptom**: Consul service stopped, preventing Windows node from joining cluster

## Error Message
```
==> Failed to setup logging: open C:\HashiCorp\Consul\logs: is a directory
```

## Root Cause Analysis

### The Problem
When Consul starts, it tries to open the path specified in `log_file` configuration. The config shows:
```hcl
log_file = "C:/HashiCorp/Consul/logs"
```

Consul interprets this as trying to open `C:\HashiCorp\Consul\logs` as a **FILE**, but it's actually a **DIRECTORY**, causing the error.

### Why This Happened
1. **Template file** (`../shared/packer/config/consul_client.hcl` line 11):
   ```hcl
   log_file = "/opt/consul/logs/"
   ```
   Has trailing slash (correct for Linux)

2. **PowerShell replacement** (`../shared/packer/scripts/client.ps1` line 66):
   ```powershell
   $ConsulConfig = $ConsulConfig -replace '/opt/consul/logs/', 'C:/HashiCorp/Consul/logs'
   ```
   **REMOVES the trailing slash** in the replacement string!

3. **Result**: Config becomes `log_file = "C:/HashiCorp/Consul/logs"` (no trailing slash)

### Consul log_file Behavior
According to Consul documentation, `log_file` can be:
1. **Empty string** `""` - Disables file logging
2. **Directory path WITH trailing slash** (e.g., `/var/log/consul/`) - Consul creates timestamped files inside
3. **Base filename** (e.g., `consul`) - Consul appends timestamps and creates in current directory

When you provide a path WITHOUT trailing slash that happens to be a directory, Consul tries to open it as a file and fails.

## The Fix

### File: `../shared/packer/scripts/client.ps1`
**Line 66** - Add trailing slash to replacement string:

```powershell
# Before (Bug #16)
$ConsulConfig = $ConsulConfig -replace '/opt/consul/logs/', 'C:/HashiCorp/Consul/logs'

# After (Fixed)
$ConsulConfig = $ConsulConfig -replace '/opt/consul/logs/', 'C:/HashiCorp/Consul/logs/'
```

### Why This Fix Works
- Consul will interpret `C:/HashiCorp/Consul/logs/` as a directory
- Consul will create log files inside with names like `consul-{timestamp}.log`
- Log rotation will work correctly with `log_rotate_duration` and `log_rotate_max_files`

## Verification Steps

1. **Check the generated config**:
   ```powershell
   Get-Content C:\HashiCorp\Consul\consul.hcl | Select-String log_file
   ```
   Should show: `log_file = "C:/HashiCorp/Consul/logs/"`

2. **Start Consul manually**:
   ```powershell
   cd C:\HashiCorp\bin
   .\consul.exe agent -config-dir=C:\HashiCorp\Consul
   ```
   Should start without "is a directory" error

3. **Check log files created**:
   ```powershell
   Get-ChildItem C:\HashiCorp\Consul\logs\
   ```
   Should show `consul-{timestamp}.log` files

## Impact
- **Severity**: CRITICAL - Prevents Consul from starting
- **Scope**: Windows clients only (Linux uses `/opt/consul/logs/` which works correctly)
- **Discovered**: Build 14 (after fixing Bug #15 syslog issue)

## Related Bugs
- **Bug #14**: HCL backslash escape sequences (fixed - use forward slashes)
- **Bug #15**: Syslog on Windows (fixed - disabled syslog)
- **Bug #16**: Missing trailing slash in log path (this bug)

## Lessons Learned

### PowerShell String Replacement
When replacing paths, be careful about trailing characters:
```powershell
# WRONG - loses trailing slash
-replace '/path/to/dir/', 'C:/Windows/Path'

# RIGHT - preserves trailing slash
-replace '/path/to/dir/', 'C:/Windows/Path/'
```

### Consul Logging Configuration
- Always use trailing slash for directory paths in `log_file`
- Consul is strict about path interpretation
- Test logging setup separately from other features

### Testing Strategy
- After fixing path-related bugs, always verify the EXACT generated config
- Test service startup manually before relying on Windows Service Manager
- Check for subtle differences like trailing slashes that affect behavior

## Build History
- **Build 13**: Fixed Bug #15 (syslog), but Bug #16 still present
- **Build 14**: Discovered Bug #16 (log_file path)
- **Build 15**: Will include Bug #16 fix

## Next Steps
1. Apply fix to `client.ps1` line 66
2. Check if Nomad has similar issue (verify nomad_client.hcl)
3. Rebuild AMI (Build 15)
4. Deploy and verify Consul starts successfully
5. Verify Windows node joins cluster