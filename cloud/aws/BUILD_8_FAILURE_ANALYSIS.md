# Build 8 Failure Analysis - EC2Launch v2 User-Data Execution

## Date
2025-12-17 22:06 UTC

## Build Information
- **Build Number**: Build 8
- **AMI ID**: ami-00fb221f488bcf6f9
- **Instance ID**: i-031f4337072cd1e9c
- **Launch Time**: 2025-12-17 21:38:52 UTC

## Status
❌ **FAILED** - User-data executed but with critical errors

## Critical Findings

### Finding #1: `<userdata>` Treated as Literal Text
**Error from EC2Launch89857614/err.tmp**:
```
< : The term '<' is not recognized as the name of a cmdlet
At C:\Windows\system32\config\systemprofile\AppData\Local\Temp\EC2Launch89857614\UserScript.ps1:1 char:1
+ <userdata>
```

**Root Cause**: The `content: <userdata>` in [`agent-config.yml`](packer/config/ec2launch-agent-config.yml:35) was being written literally to the PowerShell script file instead of being replaced with actual user-data content.

**Why This Happened**: The `<userdata>` placeholder is NOT a valid EC2Launch v2 syntax. According to AWS documentation, EC2Launch v2 handles user-data execution automatically - you don't need to configure it in agent-config.yml.

### Finding #2: Consul Service Failed to Start
**Error from EC2Launch4059263741/err.tmp**:
```
Start-Service : Failed to start service 'Consul (Consul)'.
At C:\ops\scripts\client.ps1:97 char:1
+ Start-Service -Name "Consul"
```

**Analysis**: This is a secondary issue - the Consul service exists but failed to start. This needs investigation but is separate from the EC2Launch v2 configuration issue.

## EC2Launch v2 User-Data Execution - How It Actually Works

### Incorrect Approach (Build 7 & 8)
```yaml
- stage: postReady
  tasks:
    - task: executeScript
      inputs:
        - frequency: always
          type: powershell
          runAs: admin
          content: <userdata>  # ❌ This doesn't work!
```

### Correct Approach
**EC2Launch v2 handles user-data automatically!** You don't need to configure it in agent-config.yml. The service:
1. Automatically fetches user-data from EC2 metadata
2. Detects the format (PowerShell, batch, etc.)
3. Executes it according to the format
4. Respects the frequency setting in the user-data itself

### What We Actually Need
The ONLY thing we need in agent-config.yml is to ensure state files are cleaned up so user-data runs on every boot. This is already handled by our state cleanup provisioner in [`packer/aws-packer.pkr.hcl`](packer/aws-packer.pkr.hcl:303).

## The Real Solution

**Remove the `executeScript` task entirely** from agent-config.yml. EC2Launch v2 will handle user-data execution automatically.

**Corrected Configuration**:
```yaml
version: "1.0"
config:
  - stage: boot
    tasks:
      - task: extendRootPartition
  
  - stage: preReady
    tasks:
      - task: activateWindows
        inputs:
          activation:
            type: amazon
      
      - task: setDnsSuffix
        inputs:
          suffixes:
            - $REGION.ec2-utilities.amazonaws.com
      
      - task: setAdminAccount
        inputs:
          password:
            type: random
      
      - task: setWallpaper
        inputs:
          path: C:\Windows\Web\Wallpaper\Windows\img0.jpg
  
  - stage: postReady
    tasks:
      - task: startSsm
```

## Evidence from Logs

### EC2Launch v2 Agent Log
```
2025-12-17 21:40:15 Info: Getting user data
2025-12-17 21:40:15 Info: Try parsing user data in YAML format.
2025-12-17 21:40:15 Info: Parsing failed, fall back to XML format.
2025-12-17 21:40:15 Info: Converting user data to YAML format.
2025-12-17 21:40:15 Info: Frequency is set to: once
2025-12-17 21:40:15 Console: EC2LaunchTelemetry: IsUserDataScheduledPerBoot=false
2025-12-17 21:40:22 Info: Start script.
2025-12-17 21:41:05 Error: Script produced error output.
```

**Key Points**:
- ✅ EC2Launch v2 **did** fetch and execute user-data
- ✅ User-data format was detected (PowerShell)
- ❌ Script execution failed due to errors
- ❌ `IsUserDataScheduledPerBoot=false` (expected - user-data has `frequency: once`)

## Next Steps for Build 9

1. **Remove `executeScript` task** from agent-config.yml ✅ (Already done)
2. **Investigate Consul service failure** - Why did Consul fail to start?
3. **Rebuild AMI** with corrected configuration
4. **Deploy and verify** Windows client joins cluster

## Lessons Learned

### Critical Mistake
Trying to configure user-data execution in agent-config.yml when EC2Launch v2 handles it automatically.

### What We Should Have Done
1. Read AWS EC2Launch v2 documentation more carefully
2. Understood that user-data execution is automatic
3. Focused only on state file cleanup for "run on every boot" behavior

### Key Insight
**EC2Launch v2 is NOT like EC2Config or EC2Launch v1**. It has a completely different architecture:
- User-data execution is built-in and automatic
- The agent-config.yml is for configuring the agent itself, not user-data
- State file management is the key to controlling execution frequency

## Related Documentation
- [`BUG_FIX_EC2LAUNCH_V2_CONTENT_FIELD.md`](BUG_FIX_EC2LAUNCH_V2_CONTENT_FIELD.md) - Build 7 failure (missing content field)
- [`EC2LAUNCH_V2_COMPLETE_IMPLEMENTATION.md`](EC2LAUNCH_V2_COMPLETE_IMPLEMENTATION.md) - Implementation guide
- [`packer/config/ec2launch-agent-config.yml`](packer/config/ec2launch-agent-config.yml) - Corrected configuration

## Status
✅ **Configuration Fixed** - Ready for Build 9
⏳ **Consul Issue** - Needs investigation