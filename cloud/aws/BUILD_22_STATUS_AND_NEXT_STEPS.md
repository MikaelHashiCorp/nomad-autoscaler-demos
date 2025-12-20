# Build 22 Status - Partial Success with Remaining Issues

## Current Situation

### ✅ Successes
1. **Packer Fix Applied**: Added `environment_vars` to Windows PowerShell provisioner in [`packer/aws-packer.pkr.hcl:172-180`](packer/aws-packer.pkr.hcl:172)
2. **Windows AMI Built**: ami-046fd358b552d7104 (Build 22, 25 minutes)
3. **Infrastructure Partially Deployed**: Server and Linux client running

### ❌ Current Blocker

**Terraform Deployment Failed** with error:
```
Error: Invalid function argument
  on ../modules/aws-hashistack/asg.tf line 90
  Invalid value for "path" parameter: no file exists at
  "../modules/aws-hashistack/templates/user-data-client-windows.ps1"
```

### 🔍 Root Cause Analysis

The Windows user-data template file is **missing** from the repository. This file should have been created during the Windows client implementation but appears to have been lost or never committed.

**Expected location**: `terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1`

**Current templates**:
- ✅ `user-data-client.sh` (Linux)
- ✅ `user-data-server.sh` (Linux)
- ❌ `user-data-client-windows.ps1` (MISSING)

## The Nomad Version Issue

### Problem Discovered
Even though we applied the Packer fix, **Build 22 AMI still has Nomad 1.10.5** (visible in AMI tags), not 1.11.1 as intended.

### Why This Happened
The fix I applied references Packer variables (`${var.nomad_version}`), which should read from environment variables set by `env-pkr-var.sh`. However, the AMI tags show Nomad 1.10.5, suggesting:

1. Either the environment variables weren't passed correctly to the PowerShell provisioner
2. Or the PowerShell script fetched versions before the environment variables were available
3. Or there's a timing issue with how Packer processes environment variables

### Verification Needed
We need to check the Packer build logs to see if the environment variables were actually passed:
```bash
grep -i "Using.*version from environment" packer/packer.log
```

If they weren't passed, we may need a different approach, such as:
- Passing versions as Packer command-line variables instead of environment variables
- Hardcoding Nomad 1.11.1 temporarily in the PowerShell script
- Using a different mechanism to ensure version consistency

## Immediate Next Steps

### Option A: Create Missing Template and Rebuild (Recommended)
1. **Create** `terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1`
2. **Verify** Packer environment variable passing works
3. **Destroy** current infrastructure
4. **Rebuild** Windows AMI (Build 23) with verified version pinning
5. **Deploy** and verify Windows client joins cluster

### Option B: Skip Windows Client for Now
1. **Modify** `terraform.tfvars` to set `windows_client_count = 0`
2. **Deploy** Linux-only infrastructure
3. **Fix** Windows template and version issues separately
4. **Redeploy** with Windows client later

### Option C: Manual Verification First
1. **Check** if Build 22 AMI actually has Nomad 1.11.1 despite tags showing 1.10.5
2. **Launch** a test instance from ami-046fd358b552d7104
3. **Verify** actual Nomad version installed
4. **Decide** if rebuild is necessary

## Windows User-Data Template Requirements

Based on the Linux template pattern, the Windows version should:

1. **Log output** to a file (e.g., `C:\ProgramData\user-data.log`)
2. **Call** a client configuration script (likely in `C:\ops\scripts\`)
3. **Pass parameters**:
   - Cloud provider: "aws"
   - Retry join address: `${retry_join}`
   - Node class: "hashistack-windows"
   - Nomad binary path: `${nomad_binary}`
   - Consul binary path: `${consul_binary}`

### Example Structure
```powershell
# Log all output
Start-Transcript -Path "C:\ProgramData\user-data.log" -Append

# Execute client configuration
$env:NOMAD_BINARY = "${nomad_binary}"
$env:CONSUL_BINARY = "${consul_binary}"
& "C:\ops\scripts\client-config.ps1" -CloudProvider "aws" -RetryJoin "${retry_join}" -NodeClass "${node_class}"

Stop-Transcript
```

## Files Modified in This Session

1. ✅ [`packer/aws-packer.pkr.hcl`](packer/aws-packer.pkr.hcl:172) - Added environment_vars to Windows provisioner
2. ✅ [`BUILD_22_BUG_FIX_NOMAD_VERSION.md`](BUILD_22_BUG_FIX_NOMAD_VERSION.md:1) - Documented the fix
3. ✅ [`BUILD_22_STATUS_AND_NEXT_STEPS.md`](BUILD_22_STATUS_AND_NEXT_STEPS.md:1) - This file

## Recommendation

**Proceed with Option A** - Create the missing Windows user-data template and rebuild:

1. This is the cleanest path forward
2. Ensures all Windows client infrastructure is properly configured
3. Allows us to verify the Nomad version fix works correctly
4. Gets us back on track for KB validation testing

**Estimated Time**: 
- Template creation: 10 minutes
- AMI rebuild: 25 minutes  
- Deployment: 5 minutes
- **Total**: ~40 minutes

## Success Criteria for Build 23

- ✅ Windows user-data template exists
- ✅ Windows AMI built with Nomad 1.11.1 (verified in tags)
- ✅ Infrastructure deploys successfully
- ✅ Windows client joins cluster
- ✅ `nomad node status` shows both Linux and Windows nodes
- ✅ Versions match: Server 1.11.1, Windows client 1.11.1
- ✅ Ready for KB validation testing

---

**Current Status**: Blocked on missing Windows user-data template  
**Next Action**: Create template or choose alternative path  
**Build**: 22 (partial - AMI built, deployment failed)  
**Date**: 2025-12-19