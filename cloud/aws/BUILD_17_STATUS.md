# Build 17 Status - Mixed OS Recovery from Bug #17

## Overview
**Build**: 17 (Recovery build - Mixed OS configuration)
**Date**: 2025-12-18 15:01 PST (23:01 UTC)
**Purpose**: Recover from Bug #17 by reverting to proven mixed OS configuration
**Strategy**: Scale Linux client ASG from 0 to 1 to match Build 15 success

## Background

### Build 16 Failure (Bug #17)
- **Configuration**: Windows-only (client_count=0, windows_client_count=1)
- **Issue**: Windows client could not retrieve allocations from server
- **Error**: `rpc error: Permission denied` on `Node.GetClientAllocs`
- **Impact**: All job allocations stuck in "pending" state
- **Root Cause**: RPC communication failure between Windows client and server when no Linux clients present

### Build 17 Solution
- **Configuration**: Mixed OS (client_count=1, windows_client_count=1)
- **Rationale**: Build 15 proved this configuration works
- **Action**: Scale Linux client ASG from 0 to 1
- **Expected Result**: Infrastructure jobs run on Linux, Windows available for Windows workloads

## Deployment Timeline

### 23:01 UTC - Configuration Change
```hcl
# terraform/control/terraform.tfvars
client_count = 1  # Changed from 0 to 1
windows_client_count = 1  # Unchanged
```

### 23:01 UTC - Terraform Apply
```bash
cd terraform/control
terraform apply -auto-approve
```

**Result**: 
- Plan: 0 to add, 1 to change, 0 to destroy
- Changed: aws_autoscaling_group.nomad_client_linux (desired_capacity: 0 → 1)
- Duration: 17 seconds
- Status: ✅ SUCCESS

### 23:01 UTC - Waiting for Linux Client
- Linux client instance launching via ASG
- Expected join time: 2-3 minutes
- Monitoring: nomad node status

## Infrastructure State

### AMIs
- **Linux AMI**: ami-08b1c89124bfa1498 (Ubuntu 24.04)
- **Windows AMI**: ami-02054fbc641a08fce (Build 16, all 16 bugs fixed)

### Server
- **Instance**: mws-scale-ubuntu-server-1
- **Public IP**: 35.86.214.111
- **Private IP**: 172.31.51.1
- **Status**: Running

### Clients
- **Linux Client**: Launching (ASG scaling up)
- **Windows Client**: i-0fbc89f47366babb0 (EC2AMAZ-83M26RG, Node ID: 050a6322)
  - Status: Running, joined cluster
  - Issue: Cannot retrieve allocations (Bug #17)

### Load Balancers
- **Server ELB**: mws-scale-ubuntu-server-934743196.us-west-2.elb.amazonaws.com
- **Client ELB**: mws-scale-ubuntu-client-935045096.us-west-2.elb.amazonaws.com

## Expected Outcomes

### Immediate (2-3 minutes)
1. ✅ Linux client instance launches
2. ✅ Linux client joins Nomad cluster
3. ✅ Infrastructure jobs (grafana, prometheus, webapp, traefik) start running on Linux client
4. ✅ Windows client remains in cluster
5. ✅ Bug #17 symptoms disappear (allocations no longer pending)

### Verification Steps
1. Check node status: `nomad node status`
   - Should show 2 nodes: 1 Linux (hashistack), 1 Windows (hashistack-windows)
2. Check job status: `nomad job status`
   - All jobs should show "running" with healthy allocations
3. Check allocation placement:
   - Infrastructure jobs on Linux node
   - Windows-specific jobs can run on Windows node

## Success Criteria

### Must Pass ✅
- [ ] Linux client joins cluster within 3 minutes
- [ ] Windows client remains in cluster
- [ ] All infrastructure jobs transition from "pending" to "running"
- [ ] Jobs are placed on appropriate nodes (Linux vs Windows)

### Should Pass ✅
- [ ] No "Permission denied" errors in Windows client logs
- [ ] Allocations are retrievable by clients
- [ ] Deployments marked as "successful" (not "failed")

## Comparison: Build 15 vs Build 16 vs Build 17

| Aspect | Build 15 | Build 16 | Build 17 |
|--------|----------|----------|----------|
| Linux Clients | 1 | 0 | 1 |
| Windows Clients | 1 | 1 | 1 |
| Configuration | Mixed OS | Windows-only | Mixed OS |
| Windows Node Join | ✅ SUCCESS | ✅ SUCCESS | ✅ SUCCESS |
| Job Allocations | ✅ Running | ❌ Pending | ⏳ Testing |
| RPC Communication | ✅ Working | ❌ Permission denied | ⏳ Testing |
| Overall Status | ✅ SUCCESS | ❌ FAILED (Bug #17) | ⏳ In Progress |

## Next Steps

### Immediate (After Linux Client Joins)
1. ⏳ Verify cluster status (2 nodes)
2. ⏳ Verify job status (all running)
3. ⏳ Check allocation placement
4. ⏳ Verify Windows client can now retrieve allocations

### Short-term (Today)
5. ⏳ Test Windows batch job execution
6. ⏳ Complete Test 5: Windows autoscaling (TESTING_PLAN.md Section 4.5)
7. ⏳ Complete Test 6: Dual AMI cleanup (TESTING_PLAN.md Section 4.6)

### Long-term (Future)
8. ⏳ Investigate Bug #17 root cause (TLS/gossip/node secrets)
9. ⏳ Fix Windows-only deployment if required
10. ⏳ Document mixed OS as primary deployment model

## Risk Assessment

### Low Risk ✅
- Configuration matches proven Build 15
- No code changes required
- Simple ASG scaling operation
- Rollback available (scale back to 0)

### Known Issues
- Bug #17 remains unresolved for Windows-only deployments
- Windows-only deployment model not supported until Bug #17 fixed

## Documentation References

- [`BUILD_16_BUG_17_FINAL_ANALYSIS.md`](BUILD_16_BUG_17_FINAL_ANALYSIS.md) - Complete Bug #17 investigation
- [`BUILD_15_SUCCESS_SUMMARY.md`](BUILD_15_SUCCESS_SUMMARY.md) - Proven working configuration
- [`TASK_REQUIREMENTS.md`](TASK_REQUIREMENTS.md) - Project requirements and status
- [`TESTING_PLAN.md`](TESTING_PLAN.md) - Remaining tests to complete

## Current Status

**⏳ IN PROGRESS** - Waiting for Linux client to join cluster (ETA: 2-3 minutes from 23:01 UTC)

**Next Update**: After Linux client joins and cluster status verified