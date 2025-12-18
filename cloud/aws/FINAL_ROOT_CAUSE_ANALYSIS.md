# Final Root Cause Analysis - Windows Client Deployment Failure

## Date: 2025-12-17

## Executive Summary

Windows client instances fail to join the Nomad cluster due to a **PowerShell syntax error in the shared client.ps1 script**, NOT due to EC2Launch v2 configuration issues.

## Timeline of Investigation

### Initial Hypothesis (INCORRECT)
- Believed EC2Launch v2 wasn't executing user-data
- Attempted multiple fixes to EC2Launch v2 configuration
- All attempts failed

### Breakthrough Discovery
- Simplified EC2Launch v2 fix (removing `.run-once` file) **WORKED**
- User-data executed successfully
- But Windows client still didn't join cluster

### Final Root Cause
PowerShell syntax error in `../shared/packer/scripts/client.ps1` at line 179:

```
ParserError: The string is missing the terminator: ".
At C:\ops\scripts\client.ps1:179 char:41
+ Write-Host "  Client Config: $($LogFile)"
+                                         ~
```

## Evidence Chain

### ✅ EC2Launch v2 (WORKING)
```
2025-12-17 18:34:29 Info: PowerShell content detected
2025-12-17 18:34:29 Info: User-data conversion completed.
2025-12-17 18:34:33 Info: Type: powershell
2025-12-17 18:34:39 Info: Stage: postReadyUserData completed.
```

### ✅ User-Data Script (WORKING)
```
Starting Windows Nomad Client configuration...
Timestamp: 2025-12-17 18:34:38
Executing client configuration script...
  Script: C:\ops\scripts\client.ps1
  Cloud Provider: aws
  Retry Join: provider=aws tag_key=ConsulAutoJoin tag_value=auto-join
  Node Class: hashistack-windows

Client configuration completed successfully  ← FALSE SUCCESS (caught error)
```

### ❌ client.ps1 Script (BROKEN)
- Script has PowerShell syntax error
- Cannot be parsed by PowerShell
- Fails immediately before creating transcript log
- Error caught by try-catch in user-data script
- False success message printed

## Impact

1. **EC2Launch v2 Fix**: ✅ **SUCCESSFUL** - User-data now executes on every boot
2. **Windows Client Deployment**: ❌ **BLOCKED** - Syntax error prevents configuration
3. **Nomad Service**: Running in wrong mode (server config from AMI, no retry_join)

## Solution Required

Fix PowerShell syntax error in `../shared/packer/scripts/client.ps1` around line 179-180.

The issue appears to be with string quoting/escaping in the logging section:
```powershell
Write-Host "  Client Config: $($LogFile)"
Write-Host '  Consul:        C:\HashiCorp\Consul\logs'
Write-Host '  Nomad:         C:\HashiCorp\Nomad\logs'
```

## Test Instance Details

- **Instance ID**: i-09b5bd8aa4a0e7cb6
- **AMI**: ami-0b347d32e8ffa30c9 (with simplified EC2Launch v2 fix)
- **Launch Time**: 2025-12-17 18:33:04
- **User-Data Execution**: ✅ SUCCESS (18:34:38-18:34:39)
- **client.ps1 Execution**: ❌ SYNTAX ERROR (immediate failure)

## Lessons Learned

1. **EC2Launch v2 was not the problem** - The simplified fix (removing state files) works perfectly
2. **Error handling masked the real issue** - Try-catch block printed success despite failure
3. **Syntax errors fail fast** - PowerShell won't even start a script with syntax errors
4. **Always check for transcript logs** - Missing log file was the key clue

## Next Steps

1. Fix PowerShell syntax error in client.ps1
2. Test script locally or via SSM before rebuilding AMI
3. Rebuild AMI with fixed script
4. Redeploy infrastructure
5. Verify Windows client joins cluster

## Packer Fix Status

✅ **EC2Launch v2 State Reset** - WORKING
```hcl
provisioner "powershell" {
  inline = [
    "Write-Host 'Resetting EC2Launch v2 state...'",
    "$statePath = 'C:\\ProgramData\\Amazon\\EC2Launch\\state'",
    "if (Test-Path \"$statePath\\.run-once\") {",
    "  Remove-Item \"$statePath\\.run-once\" -Force",
    "  Write-Host 'Removed .run-once file'",
    "}",
    "if (Test-Path \"$statePath\\state.json\") {",
    "  Remove-Item \"$statePath\\state.json\" -Force",
    "  Write-Host 'Removed state.json file'",
    "}",
    "Write-Host 'EC2Launch v2 state reset complete'"
  ]
}
```

✅ **Packer Instance Naming** - WORKING
```hcl
run_tags = {
  Name = format("%s-packer-build-%s", var.name_prefix, var.os)
}
```

## Conclusion

The Windows client deployment issue was caused by a PowerShell syntax error in the shared client.ps1 script, NOT by EC2Launch v2 configuration. The simplified EC2Launch v2 fix successfully allows user-data to execute, but the broken client.ps1 script prevents proper Nomad client configuration.