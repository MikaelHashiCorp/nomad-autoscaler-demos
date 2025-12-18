# Build 6 Failure Analysis - Complete Summary

## Executive Summary

Build 6 (AMI: ami-042b1697a7084c956) **FAILED** to fix the EC2Launch v2 user-data execution issue. Through systematic investigation, I identified the **root cause**: the `agent-config.yml` file does not include the `executeScript` task required for user-data execution.

## Timeline

- **20:31 UTC**: Windows instance launched (i-0578b95e4c6882d57)
- **20:32 UTC**: Instance boot complete, console shows `IsUserDataScheduledPerBoot=false`
- **20:37 UTC**: Verified no Nomad nodes registered
- **20:38 UTC**: Discovered deployment is Windows-only (no Linux clients)
- **20:39 UTC**: Began due diligence investigation
- **20:40 UTC**: Used SSM to examine actual agent-config.yml file
- **20:40 UTC**: **ROOT CAUSE IDENTIFIED**

## Root Cause Analysis

### What We Thought Was Wrong
We believed the `agent-config.yml` had `frequency: once` that needed to be changed to `frequency: always`.

### What Was Actually Wrong
The `agent-config.yml` file **does not include the `executeScript` task at all**. User-data execution is not configured in the file.

### Evidence

**Current agent-config.yml (from running instance):**
```yaml
version: "1.0"
config:
  - stage: boot
    tasks:
      - task: extendRootPartition
  - stage: preReady
    tasks:
      - task: activateWindows
      - task: setDnsSuffix
      - task: setAdminAccount
      - task: setWallpaper
  - stage: postReady
    tasks:
      - task: startSsm
```

**Missing:** No `executeScript` task anywhere!

### Why Our Fix Failed

**Our Packer provisioner (lines 270-283):**
```powershell
$config = $config -replace 'frequency: once', 'frequency: always'
```

**Why it didn't work:**
1. The string `frequency: once` doesn't exist in the file
2. The `executeScript` task isn't present at all
3. We need to ADD the task, not modify it

## The Correct Fix

We need to **add** the `executeScript` task to the configuration:

```yaml
  - stage: postReady
    tasks:
      - task: executeScript
        inputs:
          - frequency: always
            type: powershell
            runAs: admin
      - task: startSsm
```

## Implementation Plan

### Step 1: Create Configuration File
Create `packer/config/ec2launch-agent-config.yml` with complete configuration including `executeScript` task.

### Step 2: Update Packer Provisioner
Replace the string replacement provisioner with a file provisioner:
```hcl
provisioner "file" {
  source      = "config/ec2launch-agent-config.yml"
  destination = "C:\\ProgramData\\Amazon\\EC2Launch\\config\\agent-config.yml"
}
```

### Step 3: Keep State Cleanup
Keep the existing state file cleanup provisioner (lines 285-300).

### Step 4: Rebuild and Test
1. Destroy current infrastructure
2. Rebuild Windows AMI with correct fix
3. Deploy and verify user-data executes

## Lessons Learned

### 1. Verify Before Fixing
**Mistake**: Assumed the configuration had a `frequency` setting to change
**Lesson**: Always examine the actual file content before implementing a fix

### 2. Understand the System Architecture
**Mistake**: Didn't understand EC2Launch v2 uses task-based configuration
**Lesson**: Research the system architecture thoroughly before making changes

### 3. Test Assumptions
**Mistake**: Trusted Packer's "success" message without verification
**Lesson**: Add verification steps after critical changes

### 4. Due Diligence Pays Off
**Success**: Systematic investigation revealed the real problem
**Lesson**: When a fix doesn't work, investigate thoroughly before trying again

## Current Status

- ✅ Root cause identified
- ✅ Correct fix designed
- ⏳ Ready to implement
- ⏳ Awaiting approval to proceed

## Next Steps

1. Create the correct `ec2launch-agent-config.yml` file
2. Update Packer provisioner
3. Destroy current infrastructure
4. Rebuild Windows AMI (Build 7)
5. Deploy and verify

## Files Created During Investigation

- `EC2LAUNCH_V2_FIX_FAILURE_ANALYSIS.md` - Initial investigation plan
- `BUG_FIX_EC2LAUNCH_V2_ROOT_CAUSE.md` - Detailed root cause analysis
- `BUILD_6_FAILURE_SUMMARY.md` - This summary document

## Confidence Level

**VERY HIGH (98%)** - The root cause is definitively identified through direct examination of the configuration file on a running instance. The fix is straightforward and well-documented in AWS documentation.