# Bug #14: HCL Illegal Escape Sequences in Windows Paths

**Date**: 2025-12-18  
**Build**: Build 12  
**Status**: ✅ FIXED

## Problem

Consul service failed to start with error:
```
==> failed to parse C:\HashiCorp\Consul\consul.hcl: At 11:39: illegal char escape
```

The error occurred at line 11, character 39 in the Consul config file.

## Root Cause Analysis

### Investigation Steps

1. **Service Status Check**: Both Consul and Nomad services were stopped
2. **Manual Consul Execution**: Ran Consul manually to see the actual error
3. **Config File Inspection**: Retrieved the generated `consul.hcl` file

### The Actual Problem

Line 11 of the generated config showed:
```hcl
log_file       = "C:\HashiCorp\Consul\logs"
```

The error was at position 39, which is the `\l` in `\logs`. **In HCL, backslash is an escape character**, so `\l` is interpreted as an escape sequence. Since `\l` is not a valid HCL escape sequence (valid ones are `\n`, `\t`, `\r`, `\"`, `\\`, etc.), HCL throws an "illegal char escape" error.

### Why Bug #13 Didn't Fix This

Bug #13 removed the **trailing** backslash from paths like:
- `C:\HashiCorp\Consul\logs\` → `C:\HashiCorp\Consul\logs`

However, the problem is not the trailing backslash, but **any backslash followed by certain characters** in the path creates illegal escape sequences:
- `\l` in `\logs` → illegal escape
- `\C` in `\Consul` → illegal escape  
- `\H` in `\HashiCorp` → illegal escape
- `\N` in `\Nomad` → illegal escape

## The Fix

### Solution: Use Forward Slashes

Windows accepts both forward slashes (`/`) and backslashes (`\`) in file paths. HCL only treats backslash as an escape character, so **using forward slashes avoids all escape sequence issues**.

### Code Changes

**File**: `../shared/packer/scripts/client.ps1`

**Lines 65-66** (Consul paths):
```powershell
# BEFORE (Bug #14)
$ConsulConfig = $ConsulConfig -replace '/opt/consul/data', 'C:\HashiCorp\Consul\data'
$ConsulConfig = $ConsulConfig -replace '/opt/consul/logs/', 'C:\HashiCorp\Consul\logs'

# AFTER (Fixed)
$ConsulConfig = $ConsulConfig -replace '/opt/consul/data', 'C:/HashiCorp/Consul/data'
$ConsulConfig = $ConsulConfig -replace '/opt/consul/logs/', 'C:/HashiCorp/Consul/logs'
```

**Lines 123-124** (Nomad paths):
```powershell
# BEFORE (Bug #14)
$NomadConfig = $NomadConfig -replace '/opt/nomad/data', 'C:\HashiCorp\Nomad\data'
$NomadConfig = $NomadConfig -replace '/opt/nomad/logs/', 'C:\HashiCorp\Nomad\logs'

# AFTER (Fixed)
$NomadConfig = $NomadConfig -replace '/opt/nomad/data', 'C:/HashiCorp/Nomad/data'
$NomadConfig = $NomadConfig -replace '/opt/nomad/logs/', 'C:/HashiCorp/Nomad/logs'
```

## Technical Details

### HCL Escape Sequences

Valid HCL escape sequences:
- `\n` - newline
- `\r` - carriage return
- `\t` - tab
- `\"` - double quote
- `\\` - backslash
- `\uXXXX` - Unicode character

Any other `\x` combination is illegal.

### Windows Path Compatibility

Windows file system APIs accept both:
- Backslashes: `C:\Program Files\App`
- Forward slashes: `C:/Program Files/App`

This is a Windows feature for POSIX compatibility. All Windows programs, including Consul and Nomad, handle forward slashes correctly.

### Why This Matters for HCL

HCL (HashiCorp Configuration Language) is used by:
- Consul
- Nomad
- Terraform
- Vault
- Packer

All these tools parse HCL the same way, so **any Windows path in HCL config must use forward slashes or escaped backslashes**.

## Impact

**Severity**: CRITICAL  
**Scope**: All Windows path replacements in HCL config files

### Affected Components
- Consul `log_file` and `data_dir` paths
- Nomad `log_file` and `data_dir` paths
- Any future Windows path additions to HCL configs

### Symptoms
- Services fail to start
- HCL parse errors mentioning "illegal char escape"
- Error position points to backslash in path

## Verification

After applying the fix, the generated config should show:
```hcl
log_file = "C:/HashiCorp/Consul/logs"
data_dir = "C:/HashiCorp/Consul/data"
```

Instead of:
```hcl
log_file = "C:\HashiCorp\Consul\logs"  # ❌ Causes "illegal char escape"
data_dir = "C:\HashiCorp\Consul\data"  # ❌ Causes "illegal char escape"
```

## Lessons Learned

1. **HCL Escape Sequences**: Always use forward slashes for Windows paths in HCL
2. **Testing**: Should have tested the generated HCL config with `consul validate` or `nomad validate`
3. **Pattern Recognition**: Bug #13 fixed trailing backslashes, but the real issue was ANY backslash in the path
4. **Windows Compatibility**: Forward slashes work everywhere in Windows, making them safer for cross-platform configs

## Related Bugs

- **Bug #13**: Trailing backslash escapes HCL quote (different but related issue)
- Both bugs stem from HCL's interpretation of backslash as an escape character

## Prevention

### Pre-Build Validation (Updated)

Add to `BOB_COMMAND_RULES.md` Rule #4:

```markdown
#### 5. HCL Path Validation
- ❌ WRONG: Windows paths with backslashes in HCL: 'C:\path\to\dir'
- ✅ CORRECT: Windows paths with forward slashes in HCL: 'C:/path/to/dir'
- ✅ ALTERNATIVE: Escaped backslashes: 'C:\\path\\to\\dir'
```

### Testing Commands

```powershell
# Validate Consul config
consul validate C:\HashiCorp\Consul

# Validate Nomad config  
nomad config validate C:\HashiCorp\Nomad\config\nomad.hcl
```

## Build History

- **Build 9**: Bug #11 discovered (case-insensitive replace)
- **Build 10**: Bug #12 discovered (AMI Packer artifacts)
- **Build 11**: Bug #13 discovered (trailing backslash)
- **Build 12**: Bug #14 discovered (backslash escape sequences) ← Current

## Next Steps

1. ✅ Fix applied to `client.ps1`
2. ⏳ Destroy Build 12 infrastructure
3. ⏳ Deploy Build 13 with Bug #14 fix
4. ⏳ Verify services start successfully
5. ⏳ Complete testing plan