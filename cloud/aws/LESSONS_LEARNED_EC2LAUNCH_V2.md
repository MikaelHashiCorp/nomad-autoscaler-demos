# Lessons Learned: EC2Launch v2 Deep Dive

## Critical Mistake: Incomplete Research

### What Went Wrong
When implementing the first EC2Launch v2 fix, I:
1. ✅ Identified the `.run-once` file issue
2. ✅ Removed state files in Packer
3. ❌ **FAILED to research the complete EC2Launch v2 system**
4. ❌ **FAILED to understand the configuration layer**
5. ❌ **FAILED to verify the fix would actually work**

### Root Cause of the Mistake
- **Assumed** removing state files was sufficient
- **Did not read** the complete EC2Launch v2 documentation
- **Did not understand** the two-layer control system:
  1. Configuration (`agent-config.yml`) - PRIMARY control
  2. State files (`.run-once`) - SECONDARY control

### The Complete Picture

#### EC2Launch v2 Architecture
```
┌─────────────────────────────────────────┐
│   EC2Launch v2 Control System           │
├─────────────────────────────────────────┤
│                                          │
│  Layer 1: Configuration (PRIMARY)        │
│  ├─ agent-config.yml                     │
│  ├─ frequency: once | always             │
│  └─ Controls: WHAT runs and WHEN        │
│                                          │
│  Layer 2: State (SECONDARY)              │
│  ├─ .run-once file                       │
│  ├─ state.json                           │
│  └─ Tracks: Execution history            │
│                                          │
└─────────────────────────────────────────┘
```

#### How It Actually Works
1. **Configuration Check** (PRIMARY):
   - EC2Launch v2 reads `agent-config.yml`
   - Checks `frequency` setting for user-data task
   - If `frequency: once` → Check state files
   - If `frequency: always` → Execute regardless of state

2. **State Check** (SECONDARY):
   - Only matters when `frequency: once`
   - Checks for `.run-once` file
   - If exists → Skip execution
   - If missing → Execute and create `.run-once`

### What I Should Have Done

#### Proper Research Process
1. **Read complete documentation** for EC2Launch v2
2. **Understand the architecture** before implementing fixes
3. **Identify all control mechanisms**:
   - Configuration files
   - State files
   - Environment variables
   - Command-line options
4. **Test the fix** in a controlled environment
5. **Verify with telemetry** (console output shows `IsUserDataScheduledPerBoot`)

#### Proper Fix Implementation
```powershell
# Step 1: Configure EC2Launch v2 (PRIMARY - REQUIRED)
provisioner "powershell" {
  inline = [
    "# Modify agent-config.yml to set frequency: always",
    "$config = Get-Content 'C:\\ProgramData\\Amazon\\EC2Launch\\config\\agent-config.yml' -Raw",
    "$config = $config -replace 'frequency: once', 'frequency: always'",
    "Set-Content -Path $configPath -Value $config -Force"
  ]
}

# Step 2: Clean up state files (SECONDARY - OPTIONAL but good practice)
provisioner "powershell" {
  inline = [
    "Remove-Item 'C:\\ProgramData\\Amazon\\EC2Launch\\state\\.run-once' -Force -ErrorAction SilentlyContinue",
    "Remove-Item 'C:\\ProgramData\\Amazon\\EC2Launch\\state\\state.json' -Force -ErrorAction SilentlyContinue"
  ]
}
```

## Key Lessons

### 1. Always Research Completely
- **Don't assume** you understand a system from one symptom
- **Read the full documentation** before implementing fixes
- **Understand the architecture** before making changes
- **Look for multiple control layers** in complex systems

### 2. Verify Your Understanding
- **Test your mental model** against documentation
- **Check for telemetry/logging** that confirms your understanding
- **Look for configuration files** that control behavior
- **Don't stop at the first fix** - ensure it's complete

### 3. Windows is Different from Linux
- **Different boot processes** and initialization systems
- **Multiple layers of control** (EC2Launch v2 has config + state)
- **Less visible logging** (console output is minimal)
- **Configuration-driven** rather than script-driven

### 4. AMI Baking Best Practices
When creating Windows AMIs that use user-data:
1. ✅ **Configure** EC2Launch v2 frequency settings
2. ✅ **Clean up** state files
3. ✅ **Test** user-data execution on launched instances
4. ✅ **Verify** with console output telemetry
5. ✅ **Document** the complete fix, not just symptoms

### 5. Debugging Methodology
1. **Identify symptom** (user-data not running)
2. **Research the system** (EC2Launch v2 documentation)
3. **Understand architecture** (config + state layers)
4. **Identify all controls** (frequency setting + state files)
5. **Implement complete fix** (address all layers)
6. **Verify with telemetry** (check console output)

## Prevention Strategies

### For Future Windows AMI Work
- [ ] Always read complete EC2Launch v2 documentation
- [ ] Check both configuration AND state management
- [ ] Verify fixes with console output telemetry
- [ ] Test user-data execution on launched instances
- [ ] Document the complete system, not just the fix

### For Any Complex System
- [ ] Research the complete architecture before fixing
- [ ] Identify all control layers and mechanisms
- [ ] Don't assume one fix solves everything
- [ ] Verify your understanding with documentation
- [ ] Test thoroughly before declaring success

## Cost of the Mistake
- **Time**: 2 additional build cycles (~40 minutes)
- **AWS Cost**: ~$3-4 in compute time
- **Opportunity Cost**: Could have been testing Windows workloads
- **Learning**: Invaluable - now understand EC2Launch v2 completely

## References
- [EC2Launch v2 Overview](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch-v2.html)
- [EC2Launch v2 Settings](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch-v2-settings.html)
- [EC2Launch v2 Task Configuration](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2launch-v2-settings.html#ec2launch-v2-task-configuration)
- [User Data Execution](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2-windows-user-data.html)