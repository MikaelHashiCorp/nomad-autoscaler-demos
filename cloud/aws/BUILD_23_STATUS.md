# Build 23 Status - Environment Variable Fix

## Date: 2025-12-19

## Objective
Deploy Linux-only infrastructure to validate the environment variable passing fix before attempting Windows Server 2016 deployment.

## Issues Identified

### Issue 1: Packer Environment Variables Not Passed to Shell Provisioner
**Problem**: The `packer/aws-packer.pkr.hcl` file had environment variables removed from the shell provisioner (line 143 comment: "Version environment variables removed to allow script to auto-fetch latest versions"), but the `setup.sh` script uses `set -u` which treats unbound variables as errors.

**Root Cause**: When `env-pkr-var.sh` is sourced in the terraform module, those bash environment variables are NOT automatically passed to Packer's shell provisioner. Packer requires explicit `environment_vars` parameter.

**Fix Applied**: Added `environment_vars` to shell provisioner in `packer/aws-packer.pkr.hcl:140-145`:
```hcl
provisioner "shell" {
  script = "../../shared/packer/scripts/setup.sh"
  environment_vars = [
    "TARGET_OS=${var.os}",
    "CONSULVERSION=${var.consul_version}",
    "NOMADVERSION=${var.nomad_version}",
    "VAULTVERSION=${var.vault_version}"
  ]
}
```

### Issue 2: Windows PowerShell Provisioner Path Issue
**Problem**: Windows build fails with `scp: c:/Windows/Temp: No such file or directory` when trying to upload environment variable script.

**Status**: Not yet addressed - this is a separate Windows-specific issue that needs investigation.

## Previous Build Results

### Build 22 (Failed)
- **Linux Build**: Failed with "CONSULVERSION: unbound variable" at line 77 of setup.sh
- **Windows Build**: Failed with SCP path error for c:/Windows/Temp
- **Duration**: Linux 1m32s, Windows 6m11s before failure
- **Timestamp**: 2025-12-19 15:53:48 (Linux), 15:59:00 (Windows)

## Current Status

### Completed Actions
1. ✅ Identified root cause of environment variable issue
2. ✅ Applied fix to `packer/aws-packer.pkr.hcl` for Linux shell provisioner
3. ✅ Applied fix to `packer/aws-packer.pkr.hcl` for Windows PowerShell provisioner (lines 172-181)
4. ✅ Created Windows user-data template (`terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1`)
5. ✅ Manually deleted orphaned ELBs that were blocking security group deletion

### Pending Actions
1. ⏳ Trigger new terraform apply to test the fix
2. ⏳ Verify Linux AMI builds successfully with correct Nomad version (1.11.1)
3. ⏳ Deploy infrastructure and verify cluster formation
4. ⏳ Address Windows build SCP path issue (if needed for Windows deployment)

## Next Steps

### Immediate (Build 23)
1. Run `terraform apply` to trigger new Packer build with environment variable fix
2. Monitor Packer build logs to confirm:
   - Environment variables are passed correctly
   - Nomad 1.11.1 is installed (not 1.10.5)
   - AMI is created successfully
3. Verify infrastructure deployment:
   - 1 server (Nomad 1.11.1)
   - 1 Linux client (Nomad 1.11.1)
   - Cluster forms correctly

### If Build 23 Succeeds
- Proceed with Windows Server 2016 deployment (Build 24)
- Address Windows SCP path issue
- Continue with KB validation testing

### If Build 23 Fails
- Analyze new error messages
- Consider alternative approaches:
  - Pass versions as Packer CLI variables instead of using `env()` function
  - Modify `setup.sh` to not use `set -u` for version variables
  - Use Packer's `-var` flag to pass versions directly

## Technical Notes

### Environment Variable Flow
1. `packer/env-pkr-var.sh` - Fetches latest versions, sets bash environment variables
2. `packer/variables.pkr.hcl` - Defines Packer variables with `env()` function fallbacks
3. `terraform/modules/aws-nomad-image/image.tf` - Sources env-pkr-var.sh before running packer
4. `packer/aws-packer.pkr.hcl` - Must explicitly pass variables to provisioners via `environment_vars`

### Key Files Modified
- `packer/aws-packer.pkr.hcl` (lines 140-145, 172-181)
- `terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1` (created)

### Lessons Learned
1. Bash environment variables don't automatically pass to Packer provisioners
2. Both shell and PowerShell provisioners need explicit `environment_vars` parameter
3. The `env()` function in Packer variables.pkr.hcl reads bash environment, but provisioners need separate configuration
4. Windows SCP paths may need special handling in Packer

## Cost Tracking
- Current session cost: $88.03
- Failed builds: 2 (Build 21, Build 22)
- Successful builds: 1 (Build 20)