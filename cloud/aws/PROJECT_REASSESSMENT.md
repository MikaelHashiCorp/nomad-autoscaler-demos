
# Project Reassessment - What Are We Building?

## Current Situation

### What I Did Wrong
I changed `client_count` from 0 to 1, which:
- Defeats the purpose of testing Windows-only deployment
- Works around Bug #17 instead of fixing it
- Doesn't align with the project goal

### What We're Actually Building
**Goal**: Windows-only client deployment (per TASK_REQUIREMENTS.md Option 2)
- `client_count = 0` (NO Linux clients)
- `windows_client_count = 1` (Windows clients only)
- Infrastructure jobs modified to run on Windows nodes
- All workloads running on Windows

### Current Status
- **Build 16**: Windows-only deployment attempted
- **Result**: Bug #17 discovered - Windows clients can't retrieve allocations
- **Configuration**: `client_count=0`, `windows_client_count=1` ✅ CORRECT

## The Problem: Bug #17

### What's Happening
- Windows node joins cluster successfully ✅
- Jobs are submitted and assigned to Windows node ✅  
- Windows client CANNOT retrieve allocations from server ❌
- Error: `rpc error: Permission denied` on `Node.GetClientAllocs`
- All allocations stuck in "pending" state

### Root Cause (Suspected)
RPC communication failure between Windows client and Nomad server when no Linux clients are present. Possible causes:
1. TLS/mTLS configuration mismatch
2. Consul gossip encryption key issue
3. Node secret/authentication problem
4. Server initialization dependency on Linux clients

## Decision Point

### Option A: Fix Bug #17 (Align with Project Goal)
**Pros**:
- Achieves Windows-only deployment goal
- Solves the actual problem
- Enables true Windows-only architecture

**Cons**:
- Requires deep investigation
- May take significant time
- Root cause unclear

**Actions**:
1. Investigate TLS configuration on server and Windows client
2. Check Consul gossip encryption keys
3. Compare server initialization between Build 15 (worked) and Build 16 (failed)
4. Fix identified issue
5. Test Windows-only deployment again

### Option B: Document Limitation and Proceed (Pragmatic)
**Pros**:
- Unblocks remaining tests (Test 5 & 6)
- Documents known limitation
- Completes project deliverables

**Cons**:
- Doesn't achieve Windows-only goal
- Leaves Bug #17 unresolved
- Mixed OS becomes the only supported model

**Actions**:
1. Document Bug #17 as known limitation
2. Change to mixed OS configuration (`client_count=1`)
3. Complete Test 5: Windows autoscaling
4. Complete Test 6: Dual AMI cleanup
5. Mark Windows-only as "future work"

### Option C: Hybrid Approach (Recommended)
**Pros**:
- Makes progress on testing
- Keeps Bug #17 investigation open
- Delivers working solution

**Cons**:
- Requires managing two parallel tracks

**Actions**:
1. **Short-term**: Use mixed OS to complete Tests 5 & 6
2. **Parallel**: Investigate Bug #17 root cause
3. **Long-term**: Fix and retest Windows-only when root cause found
4. **Documentation**: Support both deployment models

## Recommendation

**I recommend Option C (Hybrid Approach)** because:

1. **Immediate Value**: Complete remaining tests with proven mixed OS configuration
2. **Project Goal**: Keep Windows-only investigation active
3. **Risk Management**: Don't block deliverables on unknown timeline
4. **Flexibility**: Support both deployment models based on use case

### Implementation Plan

#### Phase 1: Complete Testing (Mixed OS)
```hcl
