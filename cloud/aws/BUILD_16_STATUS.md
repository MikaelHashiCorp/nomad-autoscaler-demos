# Build 16 Status - Windows-Only Deployment

## Deployment Information

**Build Number**: 16
**Deployment Time**: 2025-12-18 14:21 PST (22:21 UTC)
**Configuration**: Windows-only clients (client_count=0, windows_client_count=1)
**Objective**: Verify Windows ASG only manages Windows instances

## AMI Information

### Linux AMI (Server Only)
- **ID**: ami-08b1c89124bfa1498
- **OS**: Ubuntu 24.04
- **Purpose**: Server instances only

### Windows AMI (Build 16)
- **ID**: ami-02054fbc641a08fce
- **OS**: Windows Server 2022
- **Build Time**: ~20 minutes
- **Components**:
  - Consul 1.21.4
  - Nomad 1.10.5
  - Vault 1.20.3
  - Docker 24.0.7
  - SSH Server (OpenSSH)

## Infrastructure Configuration

### terraform.tfvars
```hcl
client_count            = 0  # No Linux clients
windows_client_count    = 1  # 1 Windows client
```

### Expected Infrastructure
- 1 Linux Server (Nomad + Consul server)
- 0 Linux Clients
- 1 Windows Client (Nomad + Consul client)

### ASG Configuration
- **Linux Client ASG**: desired=0, min=0, max=10
- **Windows Client ASG**: desired=1, min=0, max=10

## Deployment Timeline

- **14:21 PST**: Terraform apply started
- **14:21-14:41 PST**: Windows AMI build (20 minutes)
- **14:41 PST**: Infrastructure deployment started
- **14:43 PST**: Server and ASGs created
- **14:44 PST**: Jobs deployed (grafana, prometheus, traefik, webapp)
- **14:49 PST**: Monitoring script started (5-minute wait)
- **14:54 PST**: Expected Windows node join time

## Monitoring Status

**Script**: `monitor-build16.sh`
**Status**: Running (waiting for Windows instance)
**Wait Time**: 5 minutes
**Expected Completion**: 14:54 PST

## Expected Outcomes

### Success Criteria
1. ✅ Windows instance launches from Windows ASG
2. ⏳ Windows node joins Nomad cluster (node_class: hashistack-windows)
3. ⏳ Infrastructure jobs status:
   - **Expected**: Jobs will be PENDING (no Linux clients to run on)
   - **Reason**: grafana, prometheus, webapp target hashistack-linux nodes
   - **This is CORRECT behavior** for Windows-only deployment

### Key Difference from Build 15
- **Build 15**: Mixed OS (1 Linux + 1 Windows client) - all jobs running
- **Build 16**: Windows-only (0 Linux + 1 Windows client) - Linux-targeted jobs pending

## Testing Plan

### Test 1: Verify Windows Node Joins Cluster
**Command**:
```bash
export NOMAD_ADDR=http://mws-scale-ubuntu-server-934743196.us-west-2.elb.amazonaws.com:4646
nomad node status
```

**Expected Output**:
```
ID        Node Pool  DC   Name              Class               Status
xxxxxxxx  default    dc1  EC2AMAZ-XXXXXXX   hashistack-windows  ready
```

### Test 2: Verify Job Status
**Command**:
```bash
nomad job status
```

**Expected Output**:
```
ID          Type     Status
grafana     service  pending  (no Linux nodes)
prometheus  service  pending  (no Linux nodes)
traefik     system   pending  (no Linux nodes)
webapp      service  pending  (no Linux nodes)
```

### Test 3: Deploy Windows-Targeted Job
**Purpose**: Verify Windows node can run workloads

**Command**:
```bash
nomad job run test-windows-job-batch.nomad
```

**Expected**: Job should run successfully on Windows node

### Test 4: Verify ASG Behavior
**Purpose**: Confirm Windows ASG only manages Windows instances

**Method**: Check ASG configuration and instance tags
- Windows ASG should only launch instances with Windows AMI
- Instance should have OS=Windows tag
- Node should have hashistack-windows class

## Known Behavior

### Infrastructure Jobs Will Be Pending
This is **EXPECTED** and **CORRECT** for Windows-only deployment:

**Why**:
- Infrastructure jobs (grafana, prometheus, webapp) have constraints:
  ```hcl
  constraint {
    attribute = "${node.class}"
    value     = "hashistack-linux"
  }
  ```
- With `client_count=0`, there are no Linux clients
- Jobs cannot be placed and remain in "pending" state

**This is NOT a failure** - it demonstrates:
1. Windows ASG is working correctly (only Windows instances)
2. Job constraints are working correctly (targeting specific node classes)
3. The architecture properly isolates Linux and Windows workloads

### Solutions for Production
If you need infrastructure jobs in Windows-only deployment:

**Option 1**: Modify jobs to target Windows nodes
```hcl
constraint {
  attribute = "${node.class}"
  value     = "hashistack-windows"
}
```

**Option 2**: Use mixed OS deployment
```hcl
client_count         = 1  # For infrastructure jobs
windows_client_count = 1  # For Windows workloads
```

## Next Steps

1. ⏳ Wait for monitoring script to complete
2. ⏳ Verify Windows node joined cluster
3. ⏳ Confirm infrastructure jobs are pending (expected)
4. ⏳ Deploy Windows-targeted test job
5. ⏳ Verify Windows job runs successfully
6. ⏳ Document results

## References

- **Previous Build**: BUILD_15_SUCCESS_SUMMARY.md
- **ASG Analysis**: ASG_ARCHITECTURE_ANALYSIS.md
- **Testing Plan**: TESTING_PLAN.md
- **Task Requirements**: TASK_REQUIREMENTS.md