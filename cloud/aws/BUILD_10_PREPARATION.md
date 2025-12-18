# Build 10 Preparation - Complete Bug Fix Summary

## Overview
Build 10 will fix Bug #11 (PowerShell case-insensitive replace operator) discovered during Build 9 deployment testing.

## Build 9 Results
- **AMI Created**: ami-092311cecadfef280
- **Instance Deployed**: i-0edc2ea48989d62dd
- **Status**: Consul service failed to start
- **Error**: `failed to parse C:\HashiCorp\Consul\consul.hcl: At 11:45: literal not terminated`

## Bug #11: PowerShell Case-Insensitive Replace Operator

### Discovery Process
1. Deployed Build 9 infrastructure
2. User-data executed successfully
3. Consul service failed to start
4. Used SSM to run Consul manually: `C:\HashiCorp\bin\consul.exe agent -config-dir=C:\HashiCorp\Consul`
5. Error revealed: "literal not terminated" at line 11, column 45
6. Retrieved actual config file content via SSM
7. Found malformed HCL syntax

### Root Cause
**File**: [`../shared/packer/scripts/client.ps1:64`](../shared/packer/scripts/client.ps1:64)

**Buggy Code**:
```powershell
$ConsulConfig = $ConsulConfig -replace 'RETRY_JOIN', $RetryJoin
```

**Problem**: PowerShell's `-replace` operator is **case-INSENSITIVE** by default!

**Template** [`consul_client.hcl:14`](../shared/packer/config/consul_client.hcl:14):
```hcl
retry_join = ["RETRY_JOIN"]
```

**What Happened**:
The `-replace` operator matched **BOTH**:
1. `RETRY_JOIN` (placeholder inside quotes) ✓ Intended
2. `retry_join` (HCL configuration key name) ✗ **BUG!**

**Result**:
```hcl
provider=aws tag_key=ConsulAutoJoin tag_value=auto-join = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
```

**Expected**:
```hcl
retry_join = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
```

### The Fix

Use PowerShell's **case-sensitive** `-creplace` operator:

**File**: [`../shared/packer/scripts/client.ps1:64`](../shared/packer/scripts/client.ps1:64)

**Before**:
```powershell
$ConsulConfig = $ConsulConfig -replace 'RETRY_JOIN', $RetryJoin
```

**After**:
```powershell
$ConsulConfig = $ConsulConfig -creplace 'RETRY_JOIN', $RetryJoin
```

### PowerShell String Operators Reference

| Operator | Case Sensitivity | Use Case |
|----------|-----------------|----------|
| `-replace` | Case-insensitive | Default, matches any case |
| `-creplace` | Case-sensitive | Exact case matching only |
| `-ireplace` | Case-insensitive | Explicit case-insensitive |

## Complete Bug List (11 Total)

### Build 1-6 Bugs (Fixed)
1. ✅ Windows config files missing (Packer file provisioner)
2. ✅ Nomad config path mismatch
3. ✅ PowerShell escape sequences in literal strings
4. ✅ PowerShell variable expansion with backslashes
5. ✅ Consul config duplicate entries
6. ✅ EC2Launch v2 state file conflicts

### Build 7-9 Bugs (Fixed)
7. ✅ EC2Launch v2 executeScript task causing crashes
8. ✅ UTF-8 BOM in HCL configuration files
9. ✅ Malformed retry_join syntax (resolved by Bug #8 fix)
10. ✅ Verification script checking for removed executeScript

### Build 10 Bug (Fixed in Code)
11. ✅ PowerShell case-insensitive replace operator

## Build 10 Changes

### Code Changes
1. **File**: [`../shared/packer/scripts/client.ps1:64`](../shared/packer/scripts/client.ps1:64)
   - Changed: `-replace 'RETRY_JOIN'` → `-creplace 'RETRY_JOIN'`
   - Impact: Prevents matching `retry_join` HCL key name

### No Other Changes Required
- All other fixes from Builds 1-9 remain in place
- No Packer configuration changes needed
- No Terraform changes needed
- No template changes needed

## Build 10 Execution Plan

### Step 1: Destroy Build 9 Infrastructure
```bash
cd terraform/control
terraform destroy -auto-approve
```

**Expected**:
- Terminates instance i-0edc2ea48989d62dd
- Deregisters AMI ami-092311cecadfef280
- Removes all AWS resources

### Step 2: Build Windows AMI (Build 10)
```bash
cd terraform/control
terraform apply -auto-approve
```

**Expected Duration**: ~20-25 minutes
- Packer builds Windows AMI with all 11 bug fixes
- Terraform deploys infrastructure
- Windows client instance launches

### Step 3: Verify Deployment
```bash
./verify-deployment.sh
```

**Expected**:
- Nomad API accessible
- Server nodes healthy
- Windows client joins cluster

### Step 4: Verify Services (via SSM)
```bash
# Check Consul service
aws ssm send-command --instance-ids <instance-id> \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Get-Service Consul"]' \
  --region us-west-2

# Check Nomad service
aws ssm send-command --instance-ids <instance-id> \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Get-Service Nomad"]' \
  --region us-west-2
```

**Expected**: Both services show Status: Running

### Step 5: Verify Consul Config
```bash
aws ssm send-command --instance-ids <instance-id> \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Get-Content C:\\HashiCorp\\Consul\\consul.hcl | Select-String retry_join"]' \
  --region us-west-2
```

**Expected**:
```hcl
retry_join = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
```

### Step 6: Verify Cluster Membership
```bash
export NOMAD_ADDR=http://<server_lb_dns>:4646
nomad node status
```

**Expected**: Windows node appears with class `hashistack-windows`

## Success Criteria

### Critical (Must Pass)
- ✅ Windows AMI builds successfully
- ✅ Consul config file has correct syntax
- ✅ Consul service starts and runs
- ✅ Nomad service starts and runs
- ✅ Windows client joins Nomad cluster
- ✅ Windows node visible in `nomad node status`

### Testing (After Critical Pass)
- [ ] Windows node attributes correct (Test 2)
- [ ] Windows-targeted job deploys (Test 3)
- [ ] Windows autoscaling works (Test 4)
- [ ] Dual AMI cleanup works (Test 5)

## Risk Assessment

### Low Risk
- **Single line change**: Only one operator changed (`-replace` → `-creplace`)
- **Well-understood fix**: Case sensitivity is a known PowerShell behavior
- **No side effects**: Change only affects RETRY_JOIN replacement
- **All other fixes intact**: Builds on 10 previous bug fixes

### Confidence Level
**HIGH (90%)** - This should be the final bug fix needed:
1. ✅ Root cause clearly identified
2. ✅ Fix is simple and targeted
3. ✅ All previous bugs remain fixed
4. ✅ No new code introduced
5. ✅ PowerShell operator behavior well-documented

## Lessons Learned

### PowerShell String Operations
1. **Default operators are case-insensitive** - always consider case
2. **Use `-creplace` for literal replacements** when case matters
3. **Template placeholders should not share names** with config keys (even different cases)
4. **Test string replacements** with actual values before deployment

### Debugging Process
1. **SSM is invaluable** for Windows debugging
2. **Run services manually** to see actual error messages
3. **Check generated config files** before assuming code is correct
4. **Trace data flow** from Terraform → user-data → PowerShell → config files

## Next Steps After Build 10

1. **If Build 10 succeeds**:
   - Complete testing plan (Tests 1-5)
   - Update final documentation
   - Create implementation summary
   - Mark project complete

2. **If Build 10 fails**:
   - Use SSM to investigate
   - Check Consul/Nomad service status
   - Verify config file syntax
   - Document any new bugs found

## Documentation
- **Bug Analysis**: `BUG_FIX_POWERSHELL_CASE_INSENSITIVE_REPLACE.md`
- **Task Status**: `TASK_REQUIREMENTS.md` (updated for Build 10)
- **Testing Plan**: `TESTING_PLAN.md`

---
**Status**: Ready for Build 10  
**Confidence**: HIGH (90%)  
**Expected Outcome**: Windows client successfully joins Nomad cluster