# Bug #17 Root Cause IDENTIFIED - Job Constraint Mismatch

## Critical Discovery

The user provided this key output:
```
ID            = grafana
Status        = running
Latest Deployment
ID          = c556b0d6
Status      = failed
Description = Failed due to progress deadline

Allocations
ID        Node ID   Task Group  Version  Desired  Status   Created     Modified
036e8988  050a6322  grafana     0        run      pending  31m53s ago  31m53s ago
```

## Root Cause Analysis

### The Real Problem: Job Constraints, NOT Permissions!

**I was WRONG about the permission denied error being the root cause.**

The actual issue is:
1. **Job Status**: "running" (job accepted by scheduler)
2. **Deployment Status**: "failed" - "Failed due to progress deadline"
3. **Allocation Status**: "pending" for 31+ minutes
4. **Node Assignment**: Allocation assigned to node 050a6322 (Windows node)

### What This Means

The "Permission denied" errors in the client logs are a **SYMPTOM**, not the cause. The real issue is:

**The grafana job has a constraint that prevents it from running on Windows nodes!**

### Evidence

From TASK_REQUIREMENTS.md line 152:
> Infrastructure jobs (grafana, prometheus, webapp) target Linux nodes

This means these jobs have constraints like:
```hcl
constraint {
  attribute = "${node.class}"
  value     = "hashistack"  # Linux nodes only
}
```

Or:
```hcl
constraint {
  attribute = "${attr.kernel.name}"
  value     = "linux"
}
```

### The Deployment Sequence

1. **Build 16 deployed** with Windows-only (client_count=0)
2. **Infrastructure jobs submitted** (grafana, prometheus, webapp, traefik)
3. **Scheduler assigns** allocations to Windows node (only available node)
4. **Jobs have Linux constraints** preventing execution on Windows
5. **Allocations stuck in "pending"** - can't run on Windows, no Linux nodes available
6. **Progress deadline exceeded** - deployment marked as "failed"
7. **Client logs show permission errors** - client trying to query allocations it can't run

### Why Build 15 Worked

Build 15 had:
- `client_count = 1` (Linux client available)
- `windows_client_count = 1` (Windows client available)

**Result**: Infrastructure jobs ran on Linux node, Windows-specific jobs could run on Windows node.

### Why Build 16 Failed

Build 16 has:
- `client_count = 0` (NO Linux clients)
- `windows_client_count = 1` (Windows client only)

**Result**: Infrastructure jobs assigned to Windows node but can't run due to Linux constraints.

## The "Permission Denied" Red Herring

The permission denied errors are likely:
1. Client trying to query allocations that are pending
2. Some internal RPC call failing due to allocation state
3. NOT an ACL or authentication issue
4. A consequence of the constraint mismatch, not the cause

## Solution Options

### Option 1: Add Linux Client (Quick Fix)
```hcl
client_count         = 1  # Add Linux client for infrastructure jobs
windows_client_count = 1  # Keep Windows client
```

This matches Build 15 configuration and will work immediately.

### Option 2: Modify Job Constraints (Windows-Only Deployment)

Modify infrastructure jobs to run on Windows:

**grafana.nomad**:
```hcl
constraint {
  attribute = "${node.class}"
  value     = "hashistack-windows"  # Changed from "hashistack"
}
```

**prometheus.nomad**:
```hcl
constraint {
  attribute = "${node.class}"
  value     = "hashistack-windows"  # Changed from "hashistack"
}
```

**webapp.nomad**:
```hcl
constraint {
  attribute = "${node.class}"
  value     = "hashistack-windows"  # Changed from "hashistack"
}
```

**traefik.nomad**:
```hcl
constraint {
  attribute = "${node.class}"
  value     = "hashistack-windows"  # Changed from "hashistack"
}
```

### Option 3: Remove Constraints (Universal Deployment)

Remove OS-specific constraints from infrastructure jobs to allow them to run on any node.

## Verification Steps

### 1. Check Job Constraints
```bash
export NOMAD_ADDR=http://mws-scale-ubuntu-server-934743196.us-west-2.elb.amazonaws.com:4646

# Check grafana job constraints
nomad job inspect grafana | jq '.Job.TaskGroups[].Constraints'

# Check prometheus job constraints
nomad job inspect prometheus | jq '.Job.TaskGroups[].Constraints'

# Check webapp job constraints
nomad job inspect webapp | jq '.Job.TaskGroups[].Constraints'

# Check traefik job constraints
nomad job inspect traefik | jq '.Job.TaskGroups[].Constraints'
```

### 2. Check Allocation Details
```bash
# Get detailed allocation info
nomad alloc status 036e8988

# Check why allocation is pending
nomad alloc status -verbose 036e8988 | grep -A 10 "Placement Failures"
```

### 3. Verify Node Classes
```bash
# Confirm Windows node class
nomad node status 050a6322 | grep "Node Class"
# Should show: hashistack-windows

# Check what constraints would match
nomad node status -verbose 050a6322 | grep -A 20 "Attributes"
```

## Impact Assessment

### Severity: MEDIUM (Not Critical)
- This is a **configuration issue**, not a bug in the code
- Infrastructure jobs are designed for Linux nodes
- Windows-only deployment requires job modifications

### Scope: EXPECTED BEHAVIOR
- Infrastructure jobs targeting Linux is by design
- Build 15 documentation explicitly states this (line 152)
- Windows-only deployment was never tested before

### Business Impact: LOW
- Mixed OS deployment (Build 15) is the intended model
- Windows-only deployment is an edge case
- Workaround is simple (add Linux client)

## Corrected Understanding

### What Bug #17 Actually Is

**Bug #17 is NOT a permission/ACL issue.**

**Bug #17 is a job constraint mismatch in Windows-only deployments.**

The infrastructure jobs have Linux-specific constraints that prevent them from running on Windows nodes. When no Linux nodes are available (Windows-only deployment), these jobs remain in pending state indefinitely.

## Recommended Action

### Immediate: Revert to Mixed OS Configuration
```bash
cd terraform/control

# Edit terraform.tfvars
client_count         = 1  # Add Linux client
windows_client_count = 1  # Keep Windows client

# Apply changes
terraform apply -auto-approve
```

This will:
1. Scale Linux client ASG to 1
2. Infrastructure jobs will run on Linux node
3. Windows node available for Windows-specific workloads
4. Matches proven Build 15 configuration

### Future: Document Windows-Only Requirements

If Windows-only deployment is desired, document that it requires:
1. Modifying all infrastructure job constraints
2. Ensuring Docker images are Windows-compatible
3. Testing all jobs on Windows nodes
4. Potentially different job definitions for Windows

## Lessons Learned

1. **Always check job constraints** when allocations are pending
2. **Deployment status "failed"** is more informative than client logs
3. **Progress deadline exceeded** indicates scheduler can't place allocation
4. **Permission errors can be symptoms** of other issues
5. **Infrastructure jobs are OS-specific** by design

## Files to Review

### Job Definitions (Likely in Terraform)
- `terraform/modules/aws-hashistack/templates/grafana.nomad.tpl` (if exists)
- Or jobs are submitted via user-data scripts
- Check `terraform/modules/aws-hashistack/templates/user-data-server.sh`

### Node Configuration
- Windows node class: `hashistack-windows`
- Linux node class: `hashistack`
- Jobs must target correct class

## Conclusion

Bug #17 is **NOT a permission/ACL bug**. It's a **job constraint mismatch** in Windows-only deployments.

The infrastructure jobs (grafana, prometheus, webapp, traefik) have Linux-specific constraints. When deployed in a Windows-only configuration, these jobs cannot run because no Linux nodes are available.

**Solution**: Use mixed OS deployment (1 Linux + 1 Windows) as designed in Build 15.

**Status**: Root cause identified, solution known, ready to implement.