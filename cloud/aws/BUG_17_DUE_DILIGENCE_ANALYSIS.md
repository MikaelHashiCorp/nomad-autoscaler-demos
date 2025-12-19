# Bug #17 - Due Diligence Analysis

**Date**: 2025-12-19  
**Analysis Type**: Root Cause Verification

---

## Question: Is the `servers` configuration the correct fix?

### Evidence Review

#### 1. Both Linux and Windows Use Same Template
**Finding**: Both client types use [`../shared/packer/config/nomad_client.hcl`](../shared/packer/config/nomad_client.hcl)
- Linux: Line 72 in `client.sh` copies this template
- Windows: Line 128 in `client.ps1` copies this template
- **Conclusion**: If the template is missing `servers`, BOTH are missing it

#### 2. Build 15 Success (Mixed OS)
**Configuration**: 1 Linux client + 1 Windows client
**Result**: ✅ Both clients worked, all allocations running
**Question**: Why did it work if both were missing `servers` config?

#### 3. Build 18 Failure (Windows-only)
**Configuration**: 0 Linux clients + 1 Windows client  
**Result**: ❌ Windows client failed, all allocations pending
**Question**: What's different about Windows-only vs mixed OS?

#### 4. Error Pattern Analysis
```
✅ Client heartbeat succeeds (every 12-20 seconds)
✅ Consul service discovery works
✅ Client finds server at 172.31.52.39:4647
✅ Node shows as "ready" and "eligible"
❌ Node.GetClientAllocs RPC fails with "Permission denied"
❌ Allocations stuck in "pending"
```

**Key Insight**: The client CAN communicate with the server (heartbeats work), but a SPECIFIC RPC call is being rejected.

---

## Alternative Hypotheses

### Hypothesis A: Missing `servers` Configuration (My Current Theory)
**Theory**: Without explicit `servers` config, Consul-based discovery doesn't establish proper RPC authentication.

**Problems with this theory**:
1. Build 15 worked with mixed OS using the SAME template (no `servers` config)
2. Heartbeats work fine (same RPC mechanism)
3. Only `Node.GetClientAllocs` fails, not all RPCs

**Strength**: Adding `servers` config is a documented best practice

### Hypothesis B: Server Bootstrap Timing Issue
**Theory**: When server boots with NO clients, it initializes differently than when clients are present.

**Evidence**:
- Build 15: Linux client likely started before/with Windows client
- Build 18: Only Windows client, may have timing issue with server bootstrap

**Test**: Check server startup logs for initialization differences

### Hypothesis C: Gossip Encryption or TLS Issue
**Theory**: Some security mechanism is not properly initialized in Windows-only deployments.

**Evidence**:
- "Permission denied" suggests authentication/authorization failure
- Not a network connectivity issue (heartbeats work)
- Specific to allocation retrieval RPC

**Test**: Check for gossip encryption keys or TLS certificates

### Hypothesis D: Windows-Specific RPC Bug
**Theory**: There's a bug in Nomad's Windows RPC implementation for `Node.GetClientAllocs`.

**Evidence**:
- Only affects Windows-only deployments
- Mixed OS works fine
- Specific RPC call fails

**Likelihood**: Low (would be a known Nomad bug)

---

## Critical Question

**Why did Build 15 work if both clients use the same template without `servers` config?**

Possible answers:
1. **Timing**: Linux client started first, established proper RPC context
2. **Server State**: Server initializes differently when first client is Linux vs Windows
3. **Consul Discovery**: Mixed OS creates different Consul service registration pattern
4. **Unknown Factor**: Something else we haven't identified

---

## Verification Plan

Before claiming the fix is correct, I should:

### Step 1: Verify Template Usage
✅ DONE - Confirmed both use same template

### Step 2: Check Build 15 Client Configurations
❓ NEEDED - SSH into Build 15 instances (if still running) and check actual deployed configs

### Step 3: Research Nomad Documentation
❓ NEEDED - Check if `servers` config is required or just recommended

### Step 4: Test the Fix
❓ NEEDED - Deploy Build 19 with fix and verify it works

### Step 5: Test Alternative Scenarios
❓ NEEDED - If fix works, try deploying Linux-only to see if it also needs the fix

---

## Current Assessment

**Confidence in Fix**: 60%

**Reasoning**:
- ✅ Adding `servers` config is a documented best practice
- ✅ It provides explicit server discovery vs relying on Consul
- ❌ Doesn't fully explain why Build 15 worked
- ❌ Doesn't explain why only `Node.GetClientAllocs` fails

**Recommendation**: 
1. Proceed with testing the fix in Build 19
2. If it works, document it as the solution
3. If it fails, investigate alternative hypotheses
4. Consider this might be a Nomad bug that needs reporting

---

## Next Steps

1. **Deploy Build 19** with the `servers` configuration fix
2. **Monitor carefully** for the same error
3. **If successful**: Document as solution and move forward
4. **If unsuccessful**: Investigate Hypotheses B, C, or D

---

## Conclusion

The `servers` configuration fix is **plausible but not certain**. The best way to verify is to test it in Build 19. If it works, we have our solution. If not, we need to dig deeper into server initialization, gossip encryption, or potential Nomad bugs.

**Status**: Ready to test fix, but maintaining healthy skepticism.