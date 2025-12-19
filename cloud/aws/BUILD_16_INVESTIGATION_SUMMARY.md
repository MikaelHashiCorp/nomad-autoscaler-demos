# Build 16 Investigation Summary - Bug #17 Analysis

## Current Status: 🔍 INVESTIGATING

**Build**: 16 (Windows-only deployment)
**Date**: 2025-12-18 14:56 PST
**Issue**: Bug #17 - Permission denied on client RPC calls

## What We Know

### ✅ What's Working
1. **Windows AMI Build**: ami-02054fbc641a08fce built successfully (~20 minutes)
2. **Infrastructure Deployment**: Server + Windows ASG deployed correctly
3. **Windows Node Registration**: Node EC2AMAZ-83M26RG (050a6322) joined cluster
4. **Node Health**: Node shows "ready" status in cluster
5. **Docker Service**: Healthy, Windows containers supported
6. **Service Discovery**: Consul working, node registered

### ❌ What's NOT Working
1. **Job Allocations**: All allocations stuck in "pending" state
2. **Client RPC**: Permission denied errors when querying server
3. **Workload Execution**: No jobs can run on Windows node

## The Critical Error

```
[ERROR] client.rpc: error performing RPC to server: 
  error="rpc error: Permission denied" 
  rpc=Node.GetClientAllocs 
  server=172.31.51.1:4647

[ERROR] client: error querying node allocations: 
  error="rpc error: Permission denied"
```

## Key Observation: Build 15 vs Build 16

### Build 15 (WORKED) ✅
- **Configuration**: Mixed OS deployment
  - `client_count = 1` (Linux client present)
  - `windows_client_count = 1` (Windows client present)
- **Result**: Windows node joined AND received allocations
- **Jobs**: All jobs ran successfully on appropriate nodes

### Build 16 (FAILED) ❌
- **Configuration**: Windows-only deployment
  - `client_count = 0` (NO Linux clients)
  - `windows_client_count = 1` (Windows client only)
- **Result**: Windows node joined BUT cannot receive allocations
- **Jobs**: All allocations stuck in "pending"

## Critical Discovery

**THE ONLY DIFFERENCE IS THE ABSENCE OF LINUX CLIENTS!**

This strongly suggests one of the following:

### Hypothesis A: ACL Bootstrap Issue
- ACLs may be enabled on the server
- Bootstrap process might require a Linux client to complete
- Windows client lacks proper ACL token to authenticate
- Without Linux client, ACL bootstrap never completes

### Hypothesis B: Server Initialization Race Condition
- Server may depend on having at least one client for full initialization
- Some server-side process might not complete without a client
- Windows client arrives but server isn't fully ready
- Permission system not properly initialized

### Hypothesis C: Configuration Dependency
- Server configuration might have hardcoded assumptions about Linux clients
- Some initialization script might only run when Linux clients are present
- Windows-only deployment triggers different code path with bugs

## Investigation Plan

### Step 1: Check Server Configuration
```bash
# SSH to server
ssh ubuntu@35.86.214.111

# Check if ACLs are enabled
grep -i acl /etc/nomad.d/nomad.hcl

# Check server logs for ACL-related messages
sudo journalctl -u nomad | grep -i acl

# Check for bootstrap status
curl -s http://localhost:4646/v1/acl/bootstrap
```

### Step 2: Compare Server Logs
```bash
# Get server logs from Build 15 (worked)
# Compare with Build 16 logs (failed)
# Look for differences in initialization sequence
```

### Step 3: Check Client Configuration
```powershell
# Via SSM to Windows instance
Get-Content C:\HashiCorp\Nomad\config\nomad.hcl

# Look for ACL token configuration
Select-String -Path C:\HashiCorp\Nomad\config\nomad.hcl -Pattern "acl"
```

### Step 4: Test Workaround
Deploy Build 17 with minimal Linux client to verify theory:
```hcl
client_count         = 1  # Add one Linux client
windows_client_count = 1  # Keep Windows client
```

If this works, it confirms the issue is related to Windows-only deployment.

## Potential Root Causes

### 1. ACL System Not Initialized
- Server ACLs enabled but not bootstrapped
- Bootstrap requires client connection
- Windows client can't bootstrap (permission denied)
- Linux client would bootstrap successfully

### 2. Gossip Encryption Issue
- Consul gossip encryption key mismatch
- Windows client can register but can't authenticate for RPC
- Linux client has correct key, Windows doesn't

### 3. TLS/mTLS Configuration
- Server expects TLS but Windows client not configured
- Or vice versa - Windows client uses TLS but server doesn't
- Authentication fails at RPC layer

### 4. Server-Side Bug
- Server code has bug in Windows-only scenario
- Initialization path differs when no Linux clients present
- Permission system not properly initialized

## Next Steps (Prioritized)

### Immediate (Do Now)
1. ✅ Document Bug #17 (completed)
2. ⏳ SSH to server and check ACL configuration
3. ⏳ Review server logs for ACL/permission messages
4. ⏳ Compare Build 15 vs Build 16 server configurations

### Short-term (Today)
5. ⏳ Test workaround: Deploy with 1 Linux + 1 Windows client
6. ⏳ If workaround succeeds, confirms Windows-only deployment issue
7. ⏳ Investigate server initialization code
8. ⏳ Check for ACL bootstrap requirements

### Medium-term (This Week)
9. ⏳ Identify root cause
10. ⏳ Implement fix
11. ⏳ Test Windows-only deployment again
12. ⏳ Complete remaining tests (Test 5: Autoscaling, Test 6: Dual AMI cleanup)

## Impact Assessment

### Severity: HIGH
- Blocks Windows-only deployment model
- Affects production readiness
- All Windows workloads stuck in pending state

### Scope: LIMITED
- Only affects Windows-only deployments
- Mixed OS deployments work fine (Build 15 proved this)
- Workaround available (add Linux client)

### Business Impact: MEDIUM
- Windows-only deployment is a nice-to-have, not critical
- Mixed OS deployment (Build 15) meets primary requirements
- Can proceed with mixed OS model while investigating

## Recommendations

### Option 1: Quick Win - Use Mixed OS Model
**Recommended for immediate progress**
- Revert to Build 15 configuration (1 Linux + 1 Windows)
- Complete remaining tests (Test 5 & 6)
- Document as "Mixed OS deployment model"
- Mark Windows-only as "known limitation"

### Option 2: Deep Investigation - Fix Windows-Only
**Recommended for long-term solution**
- Investigate server ACL configuration
- Identify root cause of permission issue
- Implement fix for Windows-only deployment
- Test and validate
- Document as "Windows-only deployment model"

### Option 3: Hybrid Approach
**Recommended for balanced progress**
1. Complete testing with mixed OS model (Build 15 config)
2. Document mixed OS as primary deployment model
3. Investigate Windows-only issue in parallel
4. Fix and test when root cause identified
5. Document both deployment models

## Files to Review

### Server Configuration
- `/etc/nomad.d/nomad.hcl` (on server)
- `terraform/modules/aws-hashistack/templates/user-data-server.sh`

### Client Configuration
- `C:\HashiCorp\Nomad\config\nomad.hcl` (on Windows client)
- `../shared/packer/scripts/client.ps1`
- `terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1`

### Terraform Configuration
- `terraform/control/terraform.tfvars` (current: client_count=0)
- `terraform/modules/aws-hashistack/variables.tf`

## Related Documentation
- [`BUILD_16_STATUS.md`](BUILD_16_STATUS.md) - Deployment timeline
- [`BUILD_16_BUG_17_PERMISSION_DENIED.md`](BUILD_16_BUG_17_PERMISSION_DENIED.md) - Bug details
- [`BUILD_15_SUCCESS_SUMMARY.md`](BUILD_15_SUCCESS_SUMMARY.md) - Working configuration
- [`TASK_REQUIREMENTS.md`](TASK_REQUIREMENTS.md) - Project requirements
- [`TESTING_PLAN.md`](TESTING_PLAN.md) - Testing procedures

## Timeline
- **22:21 UTC**: Build 16 deployed (Windows-only)
- **22:25 UTC**: Windows node joined cluster
- **22:54 UTC**: Bug #17 discovered (permission denied)
- **22:56 UTC**: Investigation started
- **Current**: Awaiting server configuration analysis

## Conclusion

Build 16 has revealed a NEW bug (#17) that prevents Windows-only deployments from functioning. The Windows node successfully joins the cluster but cannot receive work assignments due to permission denied errors on RPC calls.

The key insight is that Build 15 (mixed OS) worked perfectly, while Build 16 (Windows-only) fails with the same Windows AMI. This strongly suggests the issue is related to server initialization or ACL configuration when no Linux clients are present.

**Recommended immediate action**: SSH to server and check ACL configuration to determine if this is an ACL bootstrap issue.