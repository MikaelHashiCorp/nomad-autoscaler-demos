# Bug Fix: EC2Launch v2 executeScript Missing Content Field

## Date
2025-12-17 21:15 UTC

## Build Number
Build 8 (Previous: Build 7 - ami-01e2ce4401811ed59)

## Severity
**CRITICAL** - Service crash preventing all user-data execution

## Bug Description

### Symptom
EC2Launch v2 service crashes on boot with error:
```
Error: Error initializing C:\ProgramData\Amazon\EC2Launch\config\agent-config.yml: 
Expected required field 'content' for executeScript task
```

Console output shows:
```
2025-12-17 21:08:30 Console: Message: Error EC2Launch service is stopping. See instance logs for detail
```

### Root Cause
The `executeScript` task in [`agent-config.yml`](packer/config/ec2launch-agent-config.yml:30) was missing the required `content` field. According to AWS EC2Launch v2 documentation, the `executeScript` task requires a `content` field to specify what to execute.

**Incorrect Configuration (Build 7)**:
```yaml
- task: executeScript
  inputs:
    - frequency: always
      type: powershell
      runAs: admin
      # MISSING: content field
```

**Error from agent.log**:
```
2025-12-17 21:08:30 Error: Error initializing C:\ProgramData\Amazon\EC2Launch\config\agent-config.yml: 
Expected required field 'content' for executeScript task
```

### Investigation Process

1. **Console Output Check**: Noticed "Error EC2Launch service is stopping" message
2. **SSM Investigation**: Used AWS SSM to read `C:\ProgramData\Amazon\EC2Launch\log\agent.log`
3. **Error Identification**: Found "Expected required field 'content' for executeScript task"
4. **Documentation Review**: Confirmed `content` field is required for `executeScript` task
5. **Solution**: Add `content: <userdata>` to tell EC2Launch v2 to execute user-data

## Fix Implementation

### File Modified
[`packer/config/ec2launch-agent-config.yml`](packer/config/ec2launch-agent-config.yml:30)

### Changes Made
```yaml
- task: executeScript
  inputs:
    - frequency: always
      type: powershell
      runAs: admin
      content: <userdata>  # ADDED: Required field to execute user-data
```

The `<userdata>` placeholder tells EC2Launch v2 to execute the user-data script provided at instance launch.

## AWS Documentation Reference

From AWS EC2Launch v2 documentation:
- The `executeScript` task requires a `content` field
- Use `content: <userdata>` to execute the user-data script
- The `frequency: always` setting ensures execution on every boot
- The `type: powershell` specifies PowerShell script execution
- The `runAs: admin` ensures administrative privileges

## Impact

**Before Fix**:
- EC2Launch v2 service crashes on boot
- User-data never executes
- Consul and Nomad services never start
- Windows client cannot join cluster

**After Fix**:
- EC2Launch v2 service starts successfully
- User-data executes on every boot
- Consul and Nomad services start
- Windows client joins cluster

## Testing Plan

1. Destroy current infrastructure
2. Rebuild Windows AMI with corrected configuration (Build 8)
3. Deploy infrastructure
4. Verify EC2Launch v2 service starts without errors
5. Verify user-data execution
6. Verify Windows client joins Nomad cluster

## Lessons Learned

### What Went Wrong
1. **Incomplete AWS Documentation Review**: Did not thoroughly read the `executeScript` task requirements
2. **Insufficient Testing**: Packer build succeeded but didn't validate the configuration would work at runtime
3. **Missing Validation**: Should have tested the configuration file syntax before building AMI

### What Went Right
1. **Systematic Investigation**: Used SSM to examine actual log files
2. **Clear Error Messages**: AWS provided clear error message identifying the missing field
3. **Quick Identification**: Found root cause within minutes of seeing the error

### Improvements for Future
1. **Validate Configuration Files**: Test YAML syntax and required fields before building
2. **Read Complete Documentation**: Review all required fields for AWS services
3. **Runtime Testing**: Test AMI configuration in a running instance before full deployment
4. **Configuration Templates**: Use AWS-provided templates as starting point

## Related Files
- [`packer/config/ec2launch-agent-config.yml`](packer/config/ec2launch-agent-config.yml) - Fixed configuration
- [`packer/aws-packer.pkr.hcl`](packer/aws-packer.pkr.hcl:268) - File provisioner that copies configuration
- [`BUG_FIX_EC2LAUNCH_V2_ROOT_CAUSE.md`](BUG_FIX_EC2LAUNCH_V2_ROOT_CAUSE.md) - Previous EC2Launch v2 fix
- [`EC2LAUNCH_V2_COMPLETE_IMPLEMENTATION.md`](EC2LAUNCH_V2_COMPLETE_IMPLEMENTATION.md) - Implementation guide

## Status
✅ **FIXED** - Configuration updated with required `content: <userdata>` field

## Next Steps
1. Destroy current infrastructure
2. Build new Windows AMI (Build 8) with corrected configuration
3. Deploy and verify Windows client joins cluster