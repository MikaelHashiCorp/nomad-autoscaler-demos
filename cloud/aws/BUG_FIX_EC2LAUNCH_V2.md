# Bug Fix: EC2Launch v2 User-Data Execution Issue

## Date
2025-12-16

## Problem Summary
Windows client instances were not joining the Nomad cluster because the user-data script was not executing on newly launched instances.

## Root Cause Analysis

### Discovery Process
1. **Initial Symptom**: `nomad node status` showed no registered nodes despite Windows instance running
2. **Investigation**: Used AWS Systems Manager to check logs on the Windows instance
3. **Key Finding**: EC2Launch v2 log showed: `Warning: Skipping task postReadyUserData-executeScript-0`

### Root Cause
Windows Server 2022 uses **EC2Launch v2** (not the older EC2Launch). EC2Launch v2 has a state management system that prevents user-data from running multiple times:

1. During Packer build, user-data executes and EC2Launch v2 creates a `.run-once` file
2. This state file is baked into the AMI
3. When new instances launch from the AMI, EC2Launch v2 sees the `.run-once` file and skips user-data execution
4. Result: `client.ps1` never runs, Consul/Nomad services never start, node never joins cluster

### Evidence from Logs
```
2025-12-16 06:15:58 Info: Frequency is set to: once
2025-12-16 06:15:58 Info: Run as user is set to: 'admin'.
2025-12-16 06:16:00 Info: Run-once already exists: C:\ProgramData\Amazon\EC2Launch\state\.run-once
2025-12-16 06:16:00 Warning: Skipping task postReadyUserData-executeScript-0
```

## Solution

### Fix Applied
Added a PowerShell provisioner at the end of the Packer build to reset EC2Launch v2 state:

```powershell
# Reset EC2Launch v2 state to allow user-data execution on new instances
provisioner "powershell" {
  inline = [
    "Write-Host 'Resetting EC2Launch v2 state for user-data execution...'",
    "Remove-Item -Path 'C:\\ProgramData\\Amazon\\EC2Launch\\state\\.run-once' -Force -ErrorAction SilentlyContinue",
    "Remove-Item -Path 'C:\\ProgramData\\Amazon\\EC2Launch\\state\\state.json' -Force -ErrorAction SilentlyContinue",
    "Write-Host 'EC2Launch v2 state reset complete - user-data will execute on new instances'"
  ]
}
```

### Files Modified
- [`packer/aws-packer.pkr.hcl`](packer/aws-packer.pkr.hcl:228-236) - Added EC2Launch v2 state reset provisioner

## Testing Required
1. Rebuild Windows AMI with the fix
2. Launch new instance from the AMI
3. Verify user-data executes (check `C:\ProgramData\user-data.log`)
4. Verify Consul and Nomad services start
5. Verify node registers with Nomad cluster

## Related Issues
- **Bug #1**: Missing `client.ps1` script (fixed by creating the script)
- **Bug #2**: EC2Launch v2 state not reset (this fix)

## Key Learnings

### EC2Launch vs EC2Launch v2
- **Windows Server 2016/2019**: Uses EC2Launch (older version)
- **Windows Server 2022**: Uses EC2Launch v2 (newer version)
- Different configuration mechanisms and state management
- User-data execution behavior differs between versions

### AMI Baking Best Practices for Windows
1. **Always reset EC2Launch v2 state** before creating AMI
2. **Test user-data execution** on instances launched from the AMI
3. **Don't assume Linux patterns work on Windows** - different boot processes
4. **Use SSM for debugging** - console logs are minimal on Windows

### Debugging Windows Instances
- Console output is minimal compared to Linux
- Use AWS Systems Manager Session Manager for access
- Key log locations:
  - EC2Launch v2: `C:\ProgramData\Amazon\EC2Launch\log\agent.log`
  - User-data: `C:\ProgramData\user-data.log` (if script creates it)
  - Application logs: `C:\ProgramData\<app>\logs\`

## Prevention
- Add this pattern to all Windows Packer builds that use user-data
- Document EC2Launch v2 state management in Windows AMI guides
- Include user-data execution verification in Windows AMI testing

## References
- [EC2Launch v2 Documentation](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch-v2.html)
- [EC2Launch v2 Settings](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch-v2-settings.html)
- Previous bug fix: [`BUG_FIX_WINDOWS_DEPLOYMENT.md`](BUG_FIX_WINDOWS_DEPLOYMENT.md)