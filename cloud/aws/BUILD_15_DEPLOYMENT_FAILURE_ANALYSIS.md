# Build 15 Deployment Failure Analysis

## Critical Issue Discovered
**Status**: DEPLOYMENT FAILED ❌

## Job Status Summary (from user feedback)
```
ID                  Type     Priority  Status          Submit Date
grafana             service  50        pending         2025-12-18T06:56:25Z
prometheus          service  50        pending         2025-12-18T06:56:25Z
traefik             system   50        running         2025-12-18T06:56:25Z
webapp              service  50        pending         2025-12-18T06:56:25Z
windows-test        service  50        dead (stopped)  2025-12-18T07:18:27Z
windows-test-batch  batch    50        running         2025-12-18T07:18:40Z
```

## Problem Analysis

### What's Working ✅
1. **Windows node joined cluster** - Node registered successfully
2. **Traefik running** - System job deployed (runs on all nodes)
3. **Windows batch job running** - Proves Windows node can execute tasks

### What's Failing ❌
1. **Grafana**: pending (needs Linux client)
2. **Prometheus**: pending (needs Linux client)
3. **Webapp**: pending (needs Linux client)

## Root Cause

### Issue: No Linux Client Nodes Available

Looking at the terraform configuration:
```hcl
# From BUILD_15_STATUS.md
Windows ASG: mws-scale-ubuntu-client-windows (desired: 1) ✅
Linux ASG: mws-scale-ubuntu-client-linux (desired: 0) ❌
```

**The Linux client ASG has desired capacity of 0!**

This means:
- No Linux client nodes are running
- Jobs that target Linux nodes (grafana, prometheus, webapp) cannot be placed
- They remain in "pending" state waiting for eligible nodes

### Why This Happened

The infrastructure was deployed with:
- 1 Linux server (for Nomad/Consul control plane) ✅
- 0 Linux clients (for running workloads) ❌
- 1 Windows client (for Windows workloads) ✅

The demo jobs (grafana, prometheus, webapp) are configured to run on **client** nodes, not the server node.

## Verification Steps Needed

1. **Check ASG desired capacity**:
   ```bash
   aws autoscaling describe-auto-scaling-groups \
     --region us-west-2 \
     --auto-scaling-group-names mws-scale-ubuntu-client-linux \
     --query 'AutoScalingGroups[0].{Desired:DesiredCapacity,Min:MinSize,Max:MaxSize}'
   ```

2. **Check Nomad node status**:
   ```bash
   nomad node status
   # Should show: 1 server, 0 Linux clients, 1 Windows client
   ```

3. **Check job allocations**:
   ```bash
   nomad job status grafana
   nomad job status prometheus
   nomad job status webapp
   # All should show "No allocations placed"
   ```

## Solution

### Option 1: Scale Up Linux Clients (Recommended)
```bash
aws autoscaling set-desired-capacity \
  --region us-west-2 \
  --auto-scaling-group-name mws-scale-ubuntu-client-linux \
  --desired-capacity 1
```

### Option 2: Modify Jobs to Run on Server
Not recommended - server nodes should not run workloads

### Option 3: Accept Windows-Only Deployment
- Stop the Linux-targeted jobs
- Focus on Windows client validation only
- This proves Windows integration works

## Impact on Testing

### Tests Affected
- ❌ Test 3: Deploy Windows-targeted job (allocation pending issue)
- ❌ Test 4: Windows autoscaling (needs baseline workload)
- ❌ Test 5: Dual AMI cleanup (Linux AMI not being used)

### Tests Still Valid
- ✅ Test 1: Windows client joins cluster
- ✅ Test 2: Windows node attributes

## Updated Success Criteria

For a successful deployment, ALL jobs must be in "running" status:
- ✅ traefik: running (system job)
- ❌ grafana: must be running
- ❌ prometheus: must be running  
- ❌ webapp: must be running
- ✅ windows-test-batch: running (proves Windows works)

## Recommended Actions

1. **Immediate**: Scale Linux client ASG to 1
2. **Wait**: 5 minutes for Linux client to join cluster
3. **Verify**: All jobs transition to "running" status
4. **Test**: Deploy Windows-specific workload
5. **Document**: Update TESTING_PLAN.md with this requirement

## Lessons Learned

### Missing Validation Step
The deployment succeeded from Terraform's perspective, but we failed to validate:
- All ASGs have appropriate desired capacity
- All expected node types are present in cluster
- All infrastructure jobs are running

### Update Required: TESTING_PLAN.md
Add new validation step:
```markdown
## Pre-Test Validation
Before running any tests, verify:
1. All ASGs have desired capacity > 0
2. All node types present: nomad node status shows expected nodes
3. All infrastructure jobs running: nomad job status shows all "running"
```

## Next Steps

1. Check current ASG configuration
2. Scale Linux client ASG if needed
3. Wait for jobs to stabilize
4. Re-run Test 3 (Windows job deployment)
5. Complete remaining tests
6. Update documentation with new validation requirements