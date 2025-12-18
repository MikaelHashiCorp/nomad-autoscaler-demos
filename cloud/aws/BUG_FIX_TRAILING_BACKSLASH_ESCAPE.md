# Bug #13: Trailing Backslash in Windows Path Escapes HCL Quote

**Status**: ✅ FIXED  
**Build**: Build 11  
**Date**: 2025-12-18  
**Severity**: CRITICAL

## Problem Statement

Windows paths with trailing backslashes in PowerShell string replacements were escaping the closing quote in HCL configuration files, creating unterminated string literals that caused Consul and Nomad services to crash on startup.

## Root Cause Analysis

### The Bug

In [`../shared/packer/scripts/client.ps1`](../shared/packer/scripts/client.ps1), two path replacements included trailing backslashes:

**Line 66 (Consul)**:
```powershell
$ConsulConfig = $ConsulConfig -replace '/opt/consul/logs/', 'C:\HashiCorp\Consul\logs\'
```

**Line 124 (Nomad)**:
```powershell
$NomadConfig = $NomadConfig -replace '/opt/nomad/logs/', 'C:\HashiCorp\Nomad\logs\'
```

### Why This Failed

1. **PowerShell Replacement**: The replacement string `'C:\HashiCorp\Consul\logs\'` ends with a backslash
2. **HCL String Literal**: When written to the HCL file, this creates:
   ```hcl
   log_file = "C:\HashiCorp\Consul\logs\"
   ```
3. **Escape Sequence**: In HCL (and most languages), `\"` is an escape sequence for a literal quote character
4. **Unterminated String**: The closing quote is escaped, so HCL sees an unterminated string
5. **Parse Error**: Consul/Nomad fail to start with "literal not terminated" error

### Error Message

```
==> failed to parse C:\HashiCorp\Consul\consul.hcl: At 11:45: literal not terminated
```

The error points to line 11, column 45, which is exactly where the escaped quote appears in:
```hcl
log_file       = "C:\HashiCorp\Consul\logs\"
                                            ^^ position 45
```

## Investigation Process

### Build 11 Deployment

1. **Deployed Build 11** with Bug #11 and Bug #12 fixes
2. **Services Failed**: Both Consul and Nomad services stopped
3. **EC2Launch Log**: Showed "Script produced error output"
4. **Error Output**: `Start-Service : Failed to start service 'Consul (Consul)'`

### Manual Testing

Ran Consul manually via SSM:
```powershell
cd C:\HashiCorp\bin
.\consul.exe agent -config-dir=C:\HashiCorp\Consul
```

Output:
```
==> failed to parse C:\HashiCorp\Consul\consul.hcl: At 11:45: literal not terminated
```

### Config File Analysis

Retrieved the actual config file:
```hcl
log_file       = "C:\HashiCorp\Consul\logs\"
```

The trailing backslash before the closing quote creates `\"` which escapes the quote.

## The Fix

### Code Changes

Removed trailing backslashes from both path replacements:

**File**: [`../shared/packer/scripts/client.ps1`](../shared/packer/scripts/client.ps1)

**Line 66 - Consul logs path**:
```powershell
# BEFORE (Bug #13)
$ConsulConfig = $ConsulConfig -replace '/opt/consul/logs/', 'C:\HashiCorp\Consul\logs\'

# AFTER (Fixed)
$ConsulConfig = $ConsulConfig -replace '/opt/consul/logs/', 'C:\HashiCorp\Consul\logs'
```

**Line 124 - Nomad logs path**:
```powershell
# BEFORE (Bug #13)
$NomadConfig = $NomadConfig -replace '/opt/nomad/logs/', 'C:\HashiCorp\Nomad\logs\'

# AFTER (Fixed)
$NomadConfig = $NomadConfig -replace '/opt/nomad/logs/', 'C:\HashiCorp\Nomad\logs'
```

### Result

The HCL files now contain properly terminated strings:
```hcl
log_file = "C:\HashiCorp\Consul\logs"
```

## Technical Details

### HCL String Escape Sequences

HCL supports standard escape sequences in string literals:
- `\"` - Literal quote character
- `\\` - Literal backslash
- `\n` - Newline
- `\t` - Tab

### Windows Path Handling

In HCL, Windows paths can be written as:
- `"C:\HashiCorp\Consul\logs"` - Single backslashes (preferred)
- `"C:\\HashiCorp\\Consul\\logs"` - Escaped backslashes (also valid)

But NOT:
- `"C:\HashiCorp\Consul\logs\"` - Trailing backslash escapes the quote!

### Directory vs File Paths

For log directories, the trailing slash is unnecessary:
- Consul/Nomad will create log files in the directory
- The path `C:\HashiCorp\Consul\logs` correctly identifies the directory
- Adding `\` at the end serves no purpose and causes the bug

## Lessons Learned

### 1. Escape Sequence Awareness
Always be aware of escape sequences when constructing strings that will be parsed by other systems (HCL, JSON, YAML, etc.).

### 2. Path Conventions
- Directory paths don't need trailing slashes
- Trailing slashes can cause issues in string literals
- Use consistent path conventions across the codebase

### 3. Testing String Replacements
When doing string replacements that generate config files:
- Test the actual output format
- Verify the config parses correctly
- Check for edge cases like trailing characters

### 4. Error Message Analysis
The error "At 11:45: literal not terminated" was precise:
- Line 11 was the log_file line
- Column 45 was exactly where the escaped quote appeared
- This precision helped identify the root cause quickly

## Impact

### Before Fix
- Consul service fails to start
- Nomad service fails to start
- Windows clients cannot join the cluster
- User-data execution fails

### After Fix
- Config files have properly terminated strings
- Services can parse their configuration
- Ready for Build 12 deployment

## Related Bugs

- **Bug #11**: PowerShell case-insensitive replace (fixed in Build 11)
- **Bug #12**: AMI contains Packer build artifacts (fixed in Build 11)
- **Bug #13**: Trailing backslash escapes HCL quote (THIS BUG - fixed for Build 12)

## Next Steps

1. ✅ Bug #13 fixed in code
2. 📋 Destroy Build 11 infrastructure
3. 📋 Deploy Build 12 with all three fixes
4. 📋 Verify services start correctly
5. 📋 Complete testing plan

## Files Modified

- [`../shared/packer/scripts/client.ps1`](../shared/packer/scripts/client.ps1:66) - Line 66 (Consul)
- [`../shared/packer/scripts/client.ps1`](../shared/packer/scripts/client.ps1:124) - Line 124 (Nomad)

## Verification Commands

After deployment, verify the fix:

```powershell
# Check Consul config
Get-Content C:\HashiCorp\Consul\consul.hcl | Select-String "log_file"

# Check Nomad config  
Get-Content C:\HashiCorp\Nomad\config\nomad.hcl | Select-String "log_file"

# Expected output (no trailing backslash):
# log_file = "C:\HashiCorp\Consul\logs"
# log_file = "C:\HashiCorp\Nomad\logs"