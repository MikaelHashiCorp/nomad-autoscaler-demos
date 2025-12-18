# Bug Fix: EC2Launch v2 User-Data Configuration Issue

## Date
2025-12-17

## Problem Summary
Windows client instances are still not executing user-data despite removing EC2Launch v2 state files. The console output shows `IsUserDataScheduledPerBoot=false`, indicating that EC2Launch v2 is configured to NOT run user-data on every boot.

## Root Cause Analysis

### Discovery Process
1. **Previous Fix**: Removed `.run-once` and `state.json` files in Packer build
2. **Current Symptom**: Console output shows user-data detected but not executed
3. **Key Finding**: `IsUserDataScheduledPerBoot=false` in EC2Launch v2 telemetry
4. **Root Cause**: EC2Launch v2 `agent-config.yml` has user-data frequency set to "once" instead of "always"

### Evidence from Console Output
```
2025/12/17 20:00:17Z: User data format: xml
2025/12/17 20:00:23Z: EC2LaunchTelemetry: IsUserDataScheduledPerBoot=false
2025/12/17 20:00:23Z: EC2LaunchTelemetry: AgentCommandErrorCode=0
```

The telemetry clearly shows:
- User-data was detected (format: xml)
- But `IsUserDataScheduledPerBoot=false` means it won't execute
- No error occurred - EC2Launch v2 is working as configured

## EC2Launch v2 Configuration System

### Configuration File Location
`C:\ProgramData\Amazon\EC2Launch\config\agent-config.yml`

### User-Data Execution Control
The `agent-config.yml` file contains a `stage` section with `postReadyUserData` tasks. Each task has a `frequency` setting:
- `once`: Execute only on first boot (default)
- `always`: Execute on every boot

### Default Configuration (Problem)
```yaml
stage:
  postReadyUserData:
    - task: executeScript
      inputs:
        - frequency: once  # <-- THIS IS THE PROBLEM
          type: powershell
          runAs: admin
```

### Required Configuration (Solution)
```yaml
stage:
  postReadyUserData:
    - task: executeScript
      inputs:
        - frequency: always  # <-- MUST BE "always"
          type: powershell
          runAs: admin
```

## Solution

### Fix Required
Modify the Packer build to update EC2Launch v2's `agent-config.yml` file to set user-data frequency to "always":

```powershell
# Configure EC2Launch v2 to execute user-data on every boot
provisioner "powershell" {
  inline = [
    "Write-Host 'Configuring EC2Launch v2 for user-data execution on every boot...'",
    "$configPath = 'C:\\ProgramData\\Amazon\\EC2Launch\\config\\agent-config.yml'",
    "$config = Get-Content $configPath -Raw",
    "$config = $config -replace 'frequency: once', 'frequency: always'",
    "Set-Content -Path $configPath -Value $config -Force",
    "Write-Host 'EC2Launch v2 configured to run user-data on every boot'"
  ]
}
```

### Complete Fix Strategy
1. **Configure EC2Launch v2**: Set user-data frequency to "always" in `agent-config.yml`
2. **Reset State Files**: Remove `.run-once` and `state.json` (already implemented)
3. **Verify Configuration**: Check that changes persist in the AMI

### Files to Modify
- [`packer/aws-packer.pkr.hcl`](packer/aws-packer.pkr.hcl) - Add EC2Launch v2 configuration provisioner BEFORE the state reset provisioner

## Testing Required
1. Rebuild Windows AMI with the configuration fix
2. Launch new instance from the AMI
3. Check console output for `IsUserDataScheduledPerBoot=true`
4. Verify user-data executes (check for Consul/Nomad services)
5. Verify node registers with Nomad cluster

## Key Learnings

### EC2Launch v2 Has Two Separate Controls
1. **Configuration** (`agent-config.yml`): Controls WHAT runs and WHEN
   - Sets frequency: once vs always
   - This is the primary control
2. **State Files** (`.run-once`, `state.json`): Tracks execution history
   - Only matters if frequency is "once"
   - Secondary control

### Previous Fix Was Incomplete
- We only addressed state files (secondary control)
- We didn't address the configuration (primary control)
- Result: EC2Launch v2 correctly followed its configuration to NOT run user-data

### Correct Fix Order
1. **First**: Configure EC2Launch v2 to run user-data "always"
2. **Then**: Reset state files (for cleanliness)
3. **Result**: User-data will execute on every boot

## Prevention
- Always configure EC2Launch v2 frequency settings in Windows AMI builds
- Don't rely solely on state file removal
- Test user-data execution on instances launched from AMIs
- Check console output for `IsUserDataScheduledPerBoot` telemetry

## References
- [EC2Launch v2 Configuration](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch-v2-settings.html)
- [EC2Launch v2 agent-config.yml](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch-v2-settings.html#ec2launch-v2-task-configuration)
- Previous fix attempt: [`BUG_FIX_EC2LAUNCH_V2.md`](BUG_FIX_EC2LAUNCH_V2.md)

## Related Issues
- **Bug #1**: EC2Launch v2 state files (partially fixed - state files removed)
- **Bug #2**: EC2Launch v2 configuration (this fix - frequency setting)
- **Bug #3**: PowerShell UTF-8 characters (fixed)
- **Bug #4**: Consul config duplicate (fixed)