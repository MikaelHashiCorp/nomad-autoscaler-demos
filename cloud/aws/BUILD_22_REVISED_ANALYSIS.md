# Build 22 - Revised Analysis and Next Steps

## Understanding the Version Management System

### How It Works (Correctly)

1. **`env-pkr-var.sh`** exports bash environment variables:
   ```bash
   export NOMADVERSION=1.11.1
   ```

2. **Terraform** runs Packer with those variables:
   ```bash
   source env-pkr-var.sh && packer build ...
   ```

3. **`packer/variables.pkr.hcl`** reads from Packer's environment:
   ```hcl
   variable "nomad_version" {
     default = env("NOMADVERSION") != "" ? env("NOMADVERSION") : "1.10.5"
   }
   ```

4. **For Linux**: Bash scripts inherit environment variables automatically
   - `setup.sh` can read `$NOMADVERSION` directly
   - No need for Packer's `environment_vars` parameter

5. **For Windows**: PowerShell does NOT inherit bash environment variables
   - Must use Packer's `environment_vars` to pass them
   - PowerShell script reads `$env:NOMADVERSION`

### Current State

**Linux Provisioner** (lines 138-149):
```hcl
provisioner "shell" {
  script = "../../shared/packer/scripts/setup.sh"
  environment_vars = [
    "TARGET_OS=${var.os}"
  ]
  # Comment says versions removed to allow auto-fetch
}
```
- ✅ Works because bash inherits environment variables
- ✅ Script reads `$NOMADVERSION` from shell environment

**Windows Provisioner** (lines 172-181):
```hcl
provisioner "powershell" {
  script = "../../shared/packer/scripts/setup-windows.ps1"
  environment_vars = [
    "CONSULVERSION=${var.consul_version}",
    "NOMADVERSION=${var.nomad_version}",
    "VAULTVERSION=${var.vault_version}"
  ]
}
```
- ✅ Correctly passes variables to PowerShell
- ✅ Script reads `$env:NOMADVERSION`

## Why Build 22 Still Got Nomad 1.10.5

### Theory 1: Packer Variable Not Resolving
The `${var.nomad_version}` in `environment_vars` should resolve to the value from `packer/variables.pkr.hcl`, which reads `env("NOMADVERSION")`.

**Possible issue**: The `env()` function might not be reading the bash environment variable correctly.

### Theory 2: PowerShell Script Fetching Latest
Even with environment variable set, the PowerShell script might be fetching from API.

**Check needed**: Review Build 22 Packer logs for "Using Nomad version from environment" message.

### Theory 3: AMI Tags vs Actual Installation
The AMI tags might show 1.10.5 but the actual installation could be 1.11.1.

**Verification needed**: Launch instance from ami-046fd358b552d7104 and check actual version.

## The Missing Windows User-Data Template

**Current blocker**: `terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1` doesn't exist.

**Why it's needed**: Windows ASG launch template references this file to configure instances at boot.

**What it should do**:
1. Log output to `C:\ProgramData\user-data.log`
2. Call Windows client configuration script
3. Pass parameters: cloud provider, retry_join, node_class

## Revised Next Steps

### Step 1: Verify Build 22 AMI Actual Version (5 min)
```bash
# Launch test instance
aws ec2 run-instances \
  --image-id ami-046fd358b552d7104 \
  --instance-type t3a.medium \
  --key-name your-key \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test-build22}]'

# Wait for it to start, then SSH in
ssh Administrator@<instance-ip>

# Check actual Nomad version
C:\HashiCorp\Nomad\nomad.exe version

# Terminate when done
```

### Step 2: Create Windows User-Data Template (10 min)
Create `terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1`:

```powershell
<powershell>
# Log all output
Start-Transcript -Path "C:\ProgramData\user-data.log" -Append

Write-Host "Starting Windows client configuration..."
Write-Host "Cloud Provider: aws"
Write-Host "Retry Join: ${retry_join}"
Write-Host "Node Class: ${node_class}"

# Note: Windows clients are configured via EC2Launch v2
# The actual Nomad/Consul configuration happens automatically
# This user-data just logs the boot process

Write-Host "Windows client user-data complete"
Stop-Transcript
</powershell>
```

**Note**: Unlike Linux, Windows clients don't need to call a separate script because:
- Nomad/Consul are already installed in the AMI
- EC2Launch v2 handles the configuration automatically
- Services start on boot

### Step 3A: If Build 22 Has Correct Version
1. Create Windows user-data template
2. Run `terraform apply` to complete deployment
3. Verify Windows client joins cluster
4. Proceed with KB validation

### Step 3B: If Build 22 Has Wrong Version
1. Investigate why `env("NOMADVERSION")` didn't work
2. Consider alternative: Pass version as Packer CLI variable
3. Rebuild Windows AMI (Build 23)
4. Create Windows user-data template
5. Deploy and verify

## Alternative Fix: Pass Versions as CLI Variables

Instead of relying on `env()` function, pass versions explicitly:

**Modify `terraform/modules/aws-nomad-image/image.tf`**:
```hcl
command = <<EOF
source env-pkr-var.sh && \
  packer build -force \
    -var 'created_name=${var.owner_name}' \
    -var 'created_email=${var.owner_email}' \
    -var 'region=${var.region}' \
    -var 'name_prefix=${var.stack_name}' \
    -var 'os=${var.packer_os}' \
    -var 'os_version=${var.packer_os_version}' \
    -var 'os_name=${var.packer_os_name}' \
    -var "consul_version=$CONSULVERSION" \
    -var "nomad_version=$NOMADVERSION" \
    -var "vault_version=$VAULTVERSION" \
    .
EOF
```

This explicitly passes the versions from bash environment to Packer CLI, bypassing the `env()` function.

## Recommendation

**Immediate**: Execute Step 1 to verify Build 22 AMI actual version.

**If version is correct (1.11.1)**:
- Create Windows user-data template
- Deploy and test
- Total time: ~15 minutes

**If version is wrong (1.10.5)**:
- Implement CLI variable passing fix
- Rebuild AMI (Build 23)
- Create Windows user-data template  
- Deploy and test
- Total time: ~40 minutes

---

**Status**: Analysis complete, awaiting verification of Build 22 AMI  
**Next Action**: Launch test instance to check actual Nomad version  
**Build**: 22 (AMI built, deployment blocked)  
**Date**: 2025-12-19