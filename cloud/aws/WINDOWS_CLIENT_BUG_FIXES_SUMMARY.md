# Windows Client Bug Fixes - Complete Summary

## Session Date
2025-12-17

## Overview
This document summarizes all bugs discovered and fixed during the Windows client implementation for the Nomad Autoscaler demo environment.

## Bugs Fixed

### Bug #1: EC2Launch v2 State Management
**File**: `packer/aws-packer.pkr.hcl`  
**Status**: ✅ Fixed  
**Documentation**: `BUG_FIX_EC2LAUNCH_V2.md`

**Problem**: EC2Launch v2 wasn't executing user-data on instances launched from custom AMIs because the `.run-once` file prevented re-execution.

**Solution**: Added EC2Launch v2 state reset in Packer provisioner:
```powershell
Remove-Item -Path "C:\ProgramData\Amazon\EC2Launch\state\.run-once" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\ProgramData\Amazon\EC2Launch\state\state.json" -Force -ErrorAction SilentlyContinue
```

### Bug #2: PowerShell UTF-8 Checkmark Characters
**File**: `../shared/packer/scripts/client.ps1`  
**Status**: ✅ Fixed  
**Documentation**: `BUG_FIX_POWERSHELL_UTF8_CHARACTERS.md` (to be created)

**Problem**: UTF-8 checkmark characters (`✓`) on lines 103 and 161 caused PowerShell parser errors:
```
Line 179: The string is missing the terminator: ".
Line 160: Missing closing '}' in statement block or type definition.
Line 102: Missing closing '}' in statement block or type definition.
```

**Root Cause**: PowerShell parser interpreted the UTF-8 checkmark as a string terminator, causing syntax errors.

**Solution**: Replaced UTF-8 checkmarks with ASCII text:
- Line 103: `"  ✓ Consul service is running"` → `"  [OK] Consul service is running"`
- Line 161: `"  ✓ Nomad service is running"` → `"  [OK] Nomad service is running"`

### Bug #3: Duplicate retry_join in Consul Config
**File**: `../shared/packer/config/consul_client.hcl`  
**Status**: ✅ Fixed  
**Documentation**: `BUG_FIX_CONSUL_CONFIG_DUPLICATE.md`

**Problem**: Template file contained duplicate `retry_join` entries:
- Line 8: Hardcoded `retry_join = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]`
- Line 15: Template variable `retry_join = ["RETRY_JOIN"]`

This caused HCL syntax errors and Consul service startup failures.

**Solution**: Removed the hardcoded `retry_join` entry from line 8, keeping only the template variable.

## Investigation Timeline

### Initial Deployment (Attempt 1)
- Deployed infrastructure with Windows AMI
- **Result**: Windows client didn't join cluster
- **Finding**: EC2Launch v2 not executing user-data

### EC2Launch v2 Fix (Attempt 2-4)
- Attempted multiple EC2Launch v2 configuration approaches
- **Attempt 2**: Tried modifying existing stage (failed - stage didn't exist)
- **Attempt 3**: Tried complex configuration changes (failed - overcomplicated)
- **Attempt 4**: Simplified to just removing state files (SUCCESS)
- **Result**: User-data executed but script failed

### PowerShell Syntax Investigation (Attempt 4 continued)
- User-data executed in 1 second (suspiciously fast)
- Nomad service running in wrong mode (server instead of client)
- **Finding**: client.ps1 script never actually ran
- **Root Cause**: PowerShell syntax errors from UTF-8 checkmarks

### Consul Service Investigation (Attempt 5)
- Fixed UTF-8 characters, rebuilt AMI
- User-data executed successfully
- client.ps1 ran and created transcript log
- **Finding**: Consul service failed to start
- **Root Cause**: Duplicate `retry_join` in config template

## Files Modified

1. `packer/aws-packer.pkr.hcl` - EC2Launch v2 state reset
2. `../shared/packer/scripts/client.ps1` - UTF-8 checkmark removal
3. `../shared/packer/config/consul_client.hcl` - Duplicate retry_join removal

## Testing Strategy

### Verification Steps
1. ✅ EC2Launch v2 logs show user-data execution
2. ✅ User-data transcript log created
3. ✅ client-config.log created
4. ⏳ Consul service starts successfully
5. ⏳ Nomad service starts successfully
6. ⏳ Windows client joins Nomad cluster

### Remaining Tests (from TESTING_PLAN.md)
- Section 4.4 Test 1: Verify Windows clients join cluster
- Section 4.4 Test 2: Verify node attributes
- Section 4.4 Test 3: Deploy Windows-targeted job
- Section 4.5: Test Windows autoscaling
- Section 4.6: Test dual AMI cleanup

## Lessons Learned

### 1. EC2Launch v2 Behavior
- Default AMIs don't have all EC2Launch v2 stages configured
- State files prevent user-data re-execution on custom AMIs
- Simple state reset is more reliable than complex configuration changes

### 2. PowerShell Encoding
- UTF-8 special characters can cause subtle parsing errors
- Always use ASCII characters in PowerShell scripts
- PowerShell parser errors can be cryptic and point to wrong lines
- Use `[System.Management.Automation.PSParser]::Tokenize()` for syntax validation

### 3. Configuration Templates
- Never mix hardcoded values with template variables
- Duplicate HCL keys cause syntax errors
- Always validate generated configuration files
- Service startup failures require checking both service status AND config validity

### 4. Debugging Methodology
- Check logs in order: EC2Launch v2 → user-data → application logs
- Missing log files are important clues (client-config.log didn't exist initially)
- Fast execution times can indicate script failures (1 second for complex script)
- Service status alone doesn't reveal configuration errors

### 5. Bob-Instructions Compliance
- Always use `source ~/.zshrc` before commands
- Always use `logcmd` wrapper for all AWS CLI and tool commands
- Follow established procedures consistently
- Read existing documentation thoroughly before implementing fixes

## Next Steps

1. Complete current terraform destroy
2. Rebuild Windows AMI with all three fixes
3. Deploy infrastructure
4. Verify Windows client joins Nomad cluster
5. Complete remaining tests from TESTING_PLAN.md
6. Update final documentation

## Success Criteria

- [ ] Windows clients successfully join Nomad cluster
- [ ] Windows node attributes correctly identified
- [ ] Windows-targeted jobs deploy successfully
- [ ] Windows autoscaling functions correctly
- [ ] Dual AMI cleanup works on destroy
- [ ] Documentation complete and accurate

## Related Documentation

- `BUG_FIX_EC2LAUNCH_V2.md` - EC2Launch v2 fix details
- `BUG_FIX_CONSUL_CONFIG_DUPLICATE.md` - Consul config fix details
- `TASK_REQUIREMENTS.md` - Overall project requirements
- `TESTING_PLAN.md` - Comprehensive testing procedures
- `WINDOWS_CLIENT_ARCHITECTURE.md` - Architecture overview