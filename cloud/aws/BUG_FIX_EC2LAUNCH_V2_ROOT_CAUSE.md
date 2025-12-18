# EC2Launch v2 User-Data Bug - ROOT CAUSE IDENTIFIED

## Critical Discovery

### The Real Problem
The `agent-config.yml` file **does NOT include the `executeScript` task** for user-data execution. Our previous fix attempted to change `frequency: once` to `frequency: always`, but this was looking for the wrong thing.

### Evidence from Running Instance (i-0578b95e4c6882d57)

**Current agent-config.yml content:**
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

**What's Missing:** No `executeScript` task anywhere in the configuration!

### Why Our Previous Fix Failed

**What we tried:**
```powershell
$config = $config -replace 'frequency: once', 'frequency: always'
```

**Why it failed:**
- The string `frequency: once` doesn't exist in the file
- User-data execution isn't configured at all
- We need to ADD the task, not modify it

## The Correct Fix

According to AWS EC2Launch v2 documentation, we need to add the `executeScript` task to the `postReady` stage:

```yaml
  - stage: postReady
    tasks:
      - task: executeScript
        inputs:
          - frequency: always
            type: powershell
            runAs: admin
            content: |-
              # This will execute user-data on every boot
      - task: startSsm
```

### Implementation Strategy

**Option 1: Replace Entire Config File**
- Create a complete agent-config.yml with executeScript task
- Copy it during Packer provisioning
- Pros: Clean, predictable
- Cons: Might override other AWS defaults

**Option 2: Append executeScript Task**
- Parse YAML and add the task programmatically
- Pros: Preserves other settings
- Cons: More complex, requires YAML manipulation

**Option 3: Use EC2Launch v2 Settings File**
- EC2Launch v2 supports a separate settings file for user-data
- Location: `C:\ProgramData\Amazon\EC2Launch\state\previous-state.json`
- Pros: Designed for this purpose
- Cons: Need to research exact format

## Recommended Approach

**Use Option 1** - Replace the entire config file with a known-good configuration that includes:
1. All the default tasks (extendRootPartition, activateWindows, etc.)
2. The `executeScript` task with `frequency: always`
3. Proper YAML formatting

### New Packer Provisioner

```hcl
provisioner "file" {
  source      = "config/ec2launch-agent-config.yml"
  destination = "C:\\ProgramData\\Amazon\\EC2Launch\\config\\agent-config.yml"
}
```

Where `config/ec2launch-agent-config.yml` contains:
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
      - task: executeScript
        inputs:
          - frequency: always
            type: powershell
            runAs: admin
      - task: startSsm
```

## Lessons Learned

1. **Read the Actual File First**: Should have checked the file content before assuming what to change
2. **Understand the System**: EC2Launch v2 uses a task-based configuration, not simple key-value pairs
3. **Verify Assumptions**: The "frequency" setting we were looking for didn't exist
4. **Due Diligence Matters**: Proper investigation revealed the real problem

## Next Steps

1. Create the correct agent-config.yml file
2. Update Packer provisioner to copy it
3. Remove the incorrect string replacement provisioner
4. Rebuild Windows AMI
5. Test that user-data executes on boot

## Status
✅ **ROOT CAUSE IDENTIFIED** - Ready to implement correct fix