# EC2Launch v2 Configuration Fix - Failure Analysis

## Problem Statement
The EC2Launch v2 configuration fix implemented in Build 6 (AMI: ami-042b1697a7084c956) did NOT work. Console output still shows `IsUserDataScheduledPerBoot=false`.

## Evidence

### 1. Console Output (Build 6 - ami-042b1697a7084c956)
```
2025/12/17 20:32:53Z: EC2LaunchTelemetry: IsUserDataScheduledPerBoot=false
```

### 2. Packer Build Output (Build 6)
```
==> windows.amazon-ebs.hashistack: Configuring EC2Launch v2 for user-data execution on every boot...
==> windows.amazon-ebs.hashistack: EC2Launch v2 configured: user-data will run on every boot
```

**CONTRADICTION**: Packer claimed success, but the AMI still has `IsUserDataScheduledPerBoot=false`

## Root Cause Investigation

### Hypothesis 1: Configuration File Path Incorrect
**Test**: Verify the actual path to agent-config.yml
- Expected path: `C:\ProgramData\Amazon\EC2Launch\config\agent-config.yml`
- Need to verify this is the correct path on Windows Server 2022

### Hypothesis 2: Configuration Change Didn't Persist
**Possible causes**:
1. Sysprep reset the configuration after our provisioner ran
2. EC2Launch v2 has a different configuration mechanism
3. The configuration file is regenerated during AMI creation

### Hypothesis 3: Wrong Configuration Key
**Test**: Verify the actual YAML structure
- We're replacing `frequency: once` with `frequency: always`
- Need to verify this is the correct key and value format

### Hypothesis 4: Timing Issue
**Possible causes**:
1. Our provisioner ran before EC2Launch v2 was fully configured
2. Sysprep runs after our provisioner and resets the config
3. Need to run the fix as part of Sysprep preparation

## Investigation Steps Required

### Step 1: Verify Configuration File Exists and Path
Use AWS Systems Manager to connect to the running instance and check:
```powershell
Test-Path "C:\ProgramData\Amazon\EC2Launch\config\agent-config.yml"
Get-Content "C:\ProgramData\Amazon\EC2Launch\config\agent-config.yml"
```

### Step 2: Check Actual Configuration Content
```powershell
# View the entire config file
Get-Content "C:\ProgramData\Amazon\EC2Launch\config\agent-config.yml" -Raw
```

### Step 3: Check EC2Launch v2 Documentation
Research the official AWS documentation for:
- Correct configuration file location
- Correct YAML structure for user-data frequency
- Proper way to configure user-data execution on every boot

### Step 4: Check Sysprep Timing
Determine if Sysprep runs after our provisioner and resets the configuration

## Next Actions

1. **IMMEDIATE**: Use SSM to connect to running Windows instance (i-0578b95e4c6882d57)
2. **VERIFY**: Check if agent-config.yml exists and its current content
3. **RESEARCH**: Review AWS EC2Launch v2 documentation for correct configuration method
4. **DOCUMENT**: Record findings and determine correct fix approach
5. **IMPLEMENT**: Apply correct fix based on findings
6. **TEST**: Rebuild AMI and verify fix works

## Lessons Learned (So Far)

1. **Don't Trust Success Messages**: Packer said "configured" but it didn't persist
2. **Verify After Changes**: Should have added a verification provisioner to check the config
3. **Research First**: Should have researched EC2Launch v2 configuration more thoroughly
4. **Test Persistence**: Need to verify changes survive the AMI creation process

## Status
🔍 **INVESTIGATING** - Need to connect to instance and verify actual configuration state