# Build #12 Failure Analysis

## Date
2025-12-15 11:28:48 PST

## Error Summary
Build #12 failed immediately with a JSON parsing error:
```
Error parsing JSON: invalid character '#' looking for beginning of value
At line 1, column 1 (offset 1):
    1: #
      ^
```

## Log File
`cloud/aws/packer/logs/mikael-CCWRLY72J2_packer_20251215-192847.491Z.out`

## Root Cause Analysis

The error indicates Packer is trying to parse a file that starts with `#` (a shell script comment). This suggests one of two issues:

1. **Incorrect file being passed to Packer**: The command might be picking up a shell script file instead of the HCL files
2. **Command expansion issue**: The `logcmd` function might be expanding the command incorrectly

## Test Script Command
From `test-ami-build12.sh` line 39:
```bash
logcmd "packer build -var-file=windows-2022.pkrvars.hcl aws-packer.pkr.hcl" "$LOG_FILE"
```

## Potential Issues

### Issue 1: Packer Auto-Loading Files
Packer automatically loads all `.pkr.hcl` and `.pkrvars.hcl` files in the current directory. If there are any problematic files, they might be causing issues.

Files in `cloud/aws/packer/`:
- `aws-packer.pkr.hcl` ✓ (main template)
- `variables.pkr.hcl` ✓ (variables definition)
- `windows-2022.pkrvars.hcl` ✓ (Windows variables)
- `rhel-8.10.pkrvars.hcl` (RHEL variables - might conflict)
- `rhel-9.5.pkrvars.hcl` (RHEL variables - might conflict)
- `rhel-9.6.pkrvars.hcl` (RHEL variables - might conflict)
- `ubuntu-22.04.pkrvars.hcl` (Ubuntu variables - might conflict)
- `ubuntu-24.04.pkrvars.hcl` (Ubuntu variables - might conflict)

### Issue 2: Shell Script Files
Shell scripts in the directory:
- `env-pkr-var.sh` (starts with `#!/bin/bash`)
- `check-instance-status.sh`
- `connect-and-install-docker.sh`
- `create-os-configs.sh`
- `install-docker-simple.sh`
- `launch-windows-instance.sh`
- `run-docker-install-winrm.sh`
- `run-with-timestamps.sh`
- `test-ami-build*.sh`
- `validate-running-instance.sh`
- `validate-ssh-key.sh`

## Solution Options

### Option 1: Use Explicit File Specification (RECOMMENDED)
Instead of relying on auto-loading, explicitly specify only the files needed:
```bash
packer build \
  -var-file=variables.pkr.hcl \
  -var-file=windows-2022.pkrvars.hcl \
  aws-packer.pkr.hcl
```

### Option 2: Move to Clean Directory
Create a clean build directory with only necessary files:
```bash
mkdir -p build-temp
cp aws-packer.pkr.hcl variables.pkr.hcl windows-2022.pkrvars.hcl build-temp/
cd build-temp
packer build -var-file=windows-2022.pkrvars.hcl aws-packer.pkr.hcl
```

### Option 3: Use Packer's -only Flag
Specify which build to run:
```bash
packer build \
  -only='windows.amazon-ebs.hashistack' \
  -var-file=windows-2022.pkrvars.hcl \
  aws-packer.pkr.hcl
```

### Option 4: Check for Hidden Files
There might be hidden files or temp files causing issues:
```bash
ls -la cloud/aws/packer/ | grep "^-"
```

## Recommended Fix

The most likely issue is that Packer is auto-loading all `.pkrvars.hcl` files, including the RHEL and Ubuntu ones, which might have conflicting variable definitions.

**Immediate Action**: Modify the test script to use explicit file specification and avoid auto-loading.

## Next Steps

1. Update `test-ami-build12.sh` to use explicit file specification
2. Verify no hidden or temp files exist
3. Re-run the build
4. If still fails, try Option 2 (clean directory approach)

## Previous Successful Build Command

From Build #11 log, the successful command was likely:
```bash
packer build -var-file=windows-2022.pkrvars.hcl aws-packer.pkr.hcl
```

This worked because it was run from the correct directory and Packer auto-loaded the necessary files without conflicts.

## Status
**FAILED** - Needs fix before proceeding