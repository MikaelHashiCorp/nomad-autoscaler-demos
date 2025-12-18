# Bug Fix: UTF-8 BOM in HCL Configuration Files

## Date
2025-12-17 22:54 UTC

## Severity
**CRITICAL** - Prevents Consul service from starting

## Bug Description

### Symptom
Consul service crashes immediately after starting with error:
```
==> failed to parse C:\HashiCorp\Consul\consul.hcl: At 1:1: illegal char
```

### Root Cause
PowerShell's `Out-File -Encoding UTF8` adds a UTF-8 Byte Order Mark (BOM) to files. The BOM bytes (`EF BB BF`) appear at the beginning of the file and cause HCL parser to fail with "illegal char" error.

**Evidence**:
```
First 10 bytes (hex): ef bb bf 23 20 43 6f 70 79 72
                      ^^^^^^^
                      UTF-8 BOM
```

### Impact
- Consul service cannot start
- Nomad service depends on Consul, so it also cannot start
- Windows client cannot join cluster
- Complete deployment failure

## Technical Details

### PowerShell Encoding Behavior
```powershell
# WRONG - Adds BOM
$content | Out-File -FilePath $file -Encoding UTF8

# CORRECT - No BOM
[System.IO.File]::WriteAllText($file, $content, [System.Text.UTF8Encoding]::new($false))
```

### Why HCL Parsers Reject BOM
- HCL (HashiCorp Configuration Language) expects pure UTF-8 without BOM
- BOM is not part of the UTF-8 standard (it's optional)
- Most parsers treat BOM as an illegal character
- Consul, Nomad, Vault all use HCL and reject BOM

## Fix Implementation

### Files Modified
[`../shared/packer/scripts/client.ps1`](../shared/packer/scripts/client.ps1)

### Changes Made

**Line 70 - Consul Config** (BEFORE):
```powershell
$ConsulConfig | Out-File -FilePath $ConsulConfigFile -Encoding UTF8 -Force
```

**Line 70 - Consul Config** (AFTER):
```powershell
[System.IO.File]::WriteAllText($ConsulConfigFile, $ConsulConfig, [System.Text.UTF8Encoding]::new($false))
```

**Line 128 - Nomad Config** (BEFORE):
```powershell
$NomadConfig | Out-File -FilePath $NomadConfigFile -Encoding UTF8 -Force
```

**Line 128 - Nomad Config** (AFTER):
```powershell
[System.IO.File]::WriteAllText($NomadConfigFile, $NomadConfig, [System.Text.UTF8Encoding]::new($false))
```

## Verification

### Before Fix
```bash
$ hexdump -C consul.hcl | head -1
00000000  ef bb bf 23 20 43 6f 70  79 72 69 67 68 74 20 28  |...# Copyright (|
          ^^^^^^^
          BOM present
```

### After Fix
```bash
$ hexdump -C consul.hcl | head -1
00000000  23 20 43 6f 70 79 72 69  67 68 74 20 28 63 29 20  |# Copyright (c) |
          No BOM - starts with '#'
```

## Related Issues

This bug was discovered while investigating Build 8 failure. The investigation revealed:
1. ✅ EC2Launch v2 was executing user-data successfully
2. ❌ Consul service was crashing due to BOM in config file
3. ❌ Nomad service couldn't start (depends on Consul)

## Lessons Learned

### PowerShell File Writing
1. **Never use `Out-File -Encoding UTF8`** for configuration files
2. **Always use `[System.IO.File]::WriteAllText()`** with explicit encoding
3. **Test with `hexdump`** to verify no BOM is present

### HCL Configuration Files
1. HCL parsers are strict about file encoding
2. UTF-8 without BOM is the only acceptable encoding
3. BOM causes "illegal char" errors at line 1, column 1

### Testing Strategy
1. Check file encoding after writing
2. Test service startup immediately after config generation
3. Use `hexdump` or similar tools to verify binary content

## Prevention

### Code Review Checklist
- [ ] No `Out-File -Encoding UTF8` for HCL files
- [ ] Use `[System.IO.File]::WriteAllText()` with BOM-free encoding
- [ ] Test file encoding in CI/CD pipeline
- [ ] Verify service startup after config changes

### Best Practices
```powershell
# For HCL, JSON, YAML, and other config files
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($path, $content, $utf8NoBom)

# For text files where BOM is acceptable
$content | Out-File -FilePath $path -Encoding UTF8
```

## Status
✅ **FIXED** - Ready for Build 9

## Next Steps
1. Destroy Build 8 infrastructure
2. Rebuild Windows AMI with BOM fix (Build 9)
3. Deploy and verify Consul/Nomad services start successfully
4. Verify Windows client joins cluster

## Related Documentation
- [`BUILD_8_FAILURE_ANALYSIS.md`](BUILD_8_FAILURE_ANALYSIS.md) - Complete Build 8 analysis
- [`../shared/packer/scripts/client.ps1`](../shared/packer/scripts/client.ps1) - Fixed script
- [PowerShell Encoding Documentation](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/out-file)