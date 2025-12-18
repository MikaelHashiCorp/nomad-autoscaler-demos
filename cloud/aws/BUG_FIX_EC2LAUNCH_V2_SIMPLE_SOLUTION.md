# EC2Launch v2 User-Data Bug - The Simple Solution

## Date
2025-12-17

## The Real Root Cause (Finally!)

After multiple failed attempts, I discovered the truth by reading the existing documentation in `BUG_FIX_EC2LAUNCH_V2.md`:

**EC2Launch v2 AUTOMATICALLY executes `<powershell>` user-data on every boot by default.**

The ONLY problem is:
1. During Packer build, `windows-userdata.ps1` executes
2. EC2Launch v2 creates a `.run-once` state file
3. This file gets baked into the AMI
4. When new instances launch, EC2Launch v2 sees the file and skips user-data

## Why I Was Wrong

### Failed Approach 1-3: Modifying agent-config.yml
I tried to modify the EC2Launch v2 configuration file to change `frequency: once` to `frequency: always` or add a `postReadyUserData` stage.

**Why this was wrong:**
- EC2Launch v2 doesn't need configuration changes
- The `<powershell>` tag in user-data is automatically detected and executed
- I was solving a problem that didn't exist

### The Evidence
From the console output of the failed instance:
```
2025/12/17 08:25:03Z: EC2LaunchTelemetry: IsUserDataScheduledPerBoot=false
```

This doesn't mean user-data WON'T execute - it means it won't execute **again** because the `.run-once` file exists!

## The Simple Solution

**Just remove the `.run-once` file before creating the AMI. That's it.**

```hcl
# Reset EC2Launch v2 state to allow user-data execution on new instances
# EC2Launch v2 automatically executes <powershell> user-data on every boot
# The ONLY issue is the .run-once file created during Packer build gets baked into the AMI
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

## How EC2Launch v2 Actually Works

### User-Data Execution Flow
1. Instance boots
2. EC2Launch v2 starts
3. Checks for user-data in EC2 metadata
4. If user-data contains `<powershell>` tags, executes the script
5. Creates `.run-once` file to prevent re-execution
6. On subsequent boots, sees `.run-once` and skips user-data

### The Key Insight
The `<powershell>` tag format is the STANDARD way to execute PowerShell on Windows EC2 instances. EC2Launch v2 handles this automatically - no configuration needed!

## Why Multiple Builds?

You asked why I did so many builds. The answer: **I didn't understand the problem**.

I was treating symptoms (no user-data execution) instead of understanding the root cause (state file in AMI). Each "fix" was based on incomplete understanding:

1. **Attempt 1**: Tried to change frequency setting (wrong - setting doesn't exist)
2. **Attempt 2**: Tried to add executeScript task (wrong - missing required fields)
3. **Attempt 3**: Tried to modify postReadyUserData stage (wrong - stage doesn't exist)
4. **Attempt 4**: Tried to ADD postReadyUserData stage (wrong - not needed at all!)

The correct solution was documented in `BUG_FIX_EC2LAUNCH_V2.md` all along - just remove the state files!

## Lessons Learned

### 1. Read Existing Documentation First
The solution was already documented in the project. I should have read `BUG_FIX_EC2LAUNCH_V2.md` carefully before attempting fixes.

### 2. Understand the Technology
EC2Launch v2 automatically handles `<powershell>` user-data. No configuration changes needed. The AWS documentation clearly states this.

### 3. Question Assumptions
I assumed the problem was with EC2Launch v2 configuration. The real problem was state management.

### 4. Simpler is Better
The simplest solution (remove state files) is the correct one. Complex solutions (modifying YAML config) were unnecessary.

## References

- **Existing Documentation**: `BUG_FIX_EC2LAUNCH_V2.md` (had the answer all along!)
- **AWS Official Docs**: [EC2Launch v2](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch-v2.html)
- **User-Data Format**: [Windows User Data](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2-windows-user-data.html)

## Next Steps

1. ✅ Simplified fix implemented (removed unnecessary config changes)
2. ⏳ Build Windows AMI with simple fix
3. ⏳ Deploy and verify Windows client joins cluster
4. ⏳ Complete testing per TESTING_PLAN.md

## Files Modified

- `packer/aws-packer.pkr.hcl` (lines 263-276) - Removed unnecessary config changes, kept only state reset