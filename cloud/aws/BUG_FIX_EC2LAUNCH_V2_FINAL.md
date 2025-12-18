# EC2Launch v2 User-Data Execution Bug - Final Fix

## Date
2025-12-17

## Problem Summary
Windows client instances launched from the AMI were not joining the Nomad cluster because EC2Launch v2 was not executing user-data scripts on boot.

## Root Cause Analysis

### Investigation Timeline
1. **Initial Symptom**: Windows instances launched but never registered with Nomad cluster
2. **First Discovery**: Console output showed `IsUserDataScheduledPerBoot=false`
3. **Second Discovery**: EC2Launch v2 logs showed `Skipping task postReadyUserData-executeScript-0`
4. **Third Discovery**: `.run-once` state file existed in the AMI, preventing re-execution
5. **Fourth Discovery**: Default `agent-config.yml` had `postReadyUserData` stage with `frequency: once`

### Root Causes Identified
1. **Default EC2Launch v2 Configuration**: The `postReadyUserData` stage in `agent-config.yml` defaults to `frequency: once`, meaning user-data only executes on first boot
2. **State File Persistence**: The `.run-once` file created during Packer build was baked into the AMI
3. **Invalid Fix Attempts**: Multiple attempts to add custom `executeScript` tasks failed due to missing required `content` field

## Failed Fix Attempts

### Attempt 1: Add executeScript task with type and runAs
```powershell
$executeScript = "      - task: executeScript`n        inputs:`n          - frequency: always`n            type: powershell`n            runAs: admin"
```
**Result**: ❌ Error: `Expected required field 'content' for executeScript task`

### Attempt 2: Simplified executeScript task
```powershell
$executeScript = "      - task: executeScript`n        inputs:`n          - frequency: always"
```
**Result**: ❌ Same error: `Expected required field 'content' for executeScript task`

## Final Solution

### Approach
Instead of adding a new `executeScript` task, modify the existing `postReadyUserData` stage configuration to change `frequency: once` to `frequency: always`.

### Implementation

#### File: `packer/aws-packer.pkr.hcl` (lines 263-276)

```hcl
# Configure EC2Launch v2 to execute user-data on every boot
# The default config has postReadyUserData stage with frequency=once
# We need to change it to frequency=always
provisioner "powershell" {
  inline = [
    "Write-Host 'Configuring EC2Launch v2 for user-data execution on every boot...'",
    "$configPath = 'C:\\ProgramData\\Amazon\\EC2Launch\\config\\agent-config.yml'",
    "$config = Get-Content $configPath -Raw",
    "# Change postReadyUserData stage frequency from 'once' to 'always'",
    "$config = $config -replace '(- stage: postReadyUserData[\\s\\S]*?frequency:\\s+)once', '`${1}always'",
    "Set-Content $configPath -Value $config",
    "Write-Host 'EC2Launch v2 configured to execute user-data on every boot'",
    "# Verify the change",
    "Get-Content $configPath | Select-String -Pattern 'postReadyUserData' -Context 0,5"
  ]
}
```

#### File: `packer/aws-packer.pkr.hcl` (lines 278-297)

```hcl
# Reset EC2Launch v2 state to allow user-data execution on new instances
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

### Key Changes
1. **Regex Pattern**: `(- stage: postReadyUserData[\\s\\S]*?frequency:\\s+)once` - Matches the postReadyUserData stage and captures everything up to and including "frequency: "
2. **Replacement**: `${1}always` - Replaces "once" with "always" while preserving the captured prefix
3. **State Reset**: Removes `.run-once` and `state.json` files to ensure clean state in deployed instances

## Expected Behavior After Fix

### During Packer Build
1. EC2Launch v2 executes user-data (windows-userdata.ps1) on first boot
2. Provisioner modifies `agent-config.yml` to set `frequency: always`
3. Provisioner removes `.run-once` and `state.json` files
4. AMI is created with clean state

### During Instance Launch
1. EC2Launch v2 reads `agent-config.yml` with `frequency: always`
2. User-data script executes on every boot
3. Nomad client starts and joins cluster
4. Instance registers with node class `hashistack-windows`

## Verification Steps

### 1. Check EC2Launch v2 Configuration
```powershell
Get-Content C:\ProgramData\Amazon\EC2Launch\config\agent-config.yml | Select-String -Pattern "postReadyUserData" -Context 0,5
```
**Expected**: Should show `frequency: always`

### 2. Check State Files
```powershell
Test-Path C:\ProgramData\Amazon\EC2Launch\state\.run-once
```
**Expected**: `False` (file should not exist in AMI)

### 3. Check Console Output
```bash
aws ec2 get-console-output --instance-id <id>
```
**Expected**: Should show `IsUserDataScheduledPerBoot=true`

### 4. Check Nomad Registration
```bash
export NOMAD_ADDR=http://<server-lb>:4646
nomad node status
```
**Expected**: Should show Windows node with class `hashistack-windows`

## Technical Details

### EC2Launch v2 Configuration Structure
```yaml
version: 1.0
config:
  - stage: boot
    tasks:
      # ... boot tasks ...
  - stage: network
    tasks:
      # ... network tasks ...
  - stage: preReady
    tasks:
      # ... preReady tasks ...
  - stage: postReadyUserData
    tasks:
      - task: executeScript
        inputs:
          - frequency: once  # ← This needs to be 'always'
            type: powershell
            runAs: admin
  - stage: postReady
    tasks:
      - task: startSsm
```

### State Files
- **Location**: `C:\ProgramData\Amazon\EC2Launch\state\`
- **`.run-once`**: Marker file indicating user-data has been executed
- **`state.json`**: Stores execution state for various tasks

## References
- [EC2Launch v2 Documentation](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch-v2.html)
- [EC2Launch v2 Settings](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch-v2-settings.html)
- [User Data Execution](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2-windows-user-data.html)

## Status
- ✅ Fix implemented in `packer/aws-packer.pkr.hcl`
- ✅ Syntax validated
- ⏳ Awaiting final AMI build and deployment test