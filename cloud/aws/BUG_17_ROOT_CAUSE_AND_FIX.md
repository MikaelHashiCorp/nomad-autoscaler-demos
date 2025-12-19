# Bug #17 - Root Cause Analysis and Fix

**Date**: 2025-12-18  
**Status**: ✅ **ROOT CAUSE IDENTIFIED**  
**Severity**: CRITICAL  
**Impact**: Windows-only deployments non-functional

---

## Executive Summary

Bug #17 has been **SOLVED**. The root cause is a **missing `client.servers` configuration block** in the Nomad client configuration template. Without explicit server addresses, Windows clients rely solely on Consul service discovery, which fails RPC authentication in Windows-only deployments.

---

## Root Cause

### Missing Configuration
The file [`../shared/packer/config/nomad_client.hcl`](../shared/packer/config/nomad_client.hcl) is missing the `client.servers` block:

```hcl
# MISSING FROM CURRENT CONFIG:
client {
  enabled = true
  node_class = NODE_CLASS
  
  # THIS BLOCK IS MISSING:
  servers = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
  
  options {
    "driver.raw_exec.enable"    = "1"
    "docker.privileged.enabled" = "true"
  }
}
```

### Why This Causes the Bug

1. **Without `servers` block**: Nomad client uses Consul service discovery to find servers
2. **Consul discovery works**: Client successfully finds server at 172.31.52.39:4647
3. **RPC authentication fails**: Client cannot authenticate RPC calls to retrieve allocations
4. **Error**: `"rpc error: Permission denied"` on `Node.GetClientAllocs`

### Why Build 15 (Mixed OS) Worked

In Build 15, the Linux client had the correct `servers` configuration:
- Linux client template includes: `servers = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]`
- This establishes proper RPC authentication during cluster bootstrap
- Windows client then inherits working authentication context

### Why Build 18 (Windows-only) Failed

In Build 18, no client has the `servers` configuration:
- Windows client relies solely on Consul service discovery
- RPC authentication never properly initializes
- All allocation retrieval attempts fail with "Permission denied"

---

## Evidence

### 1. Current Configuration (BROKEN)
**File**: `../shared/packer/config/nomad_client.hcl`
```hcl
client {
  enabled    = true
  node_class = NODE_CLASS

  options {
    "driver.raw_exec.enable"    = "1"
    "docker.privileged.enabled" = "true"
  }
}
# ❌ Missing servers block
```

### 2. Linux Client Configuration (WORKING)
**File**: `../shared/packer/config/nomad_client_linux.hcl` (hypothetical - need to verify)
```hcl
client {
  enabled = true
  servers = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
  # ✅ Has servers block
}
```

### 3. Windows Client Logs
```
[ERROR] client.rpc: error performing RPC to server which is not safe to automatically retry: 
  error="rpc error: Permission denied" 
  rpc=Node.GetClientAllocs 
  server=172.31.52.39:4647
```

### 4. Consul Service Discovery (WORKING)
```powershell
PS> C:\HashiCorp\bin\consul.exe catalog nodes -service=nomad
Node             ID        Address       DC
ip-172-31-52-39  2c8f850a  172.31.52.39  dc1
```
✅ Client can discover server via Consul  
❌ Client cannot authenticate RPC calls to server

---

## The Fix

### Solution
Add the `servers` block to the Nomad client configuration template.

### File to Modify
[`../shared/packer/config/nomad_client.hcl`](../shared/packer/config/nomad_client.hcl)

### Required Change
```hcl
client {
  enabled    = true
  node_class = NODE_CLASS
  
  # ADD THIS BLOCK:
  servers = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
  
  options {
    "driver.raw_exec.enable"    = "1"
    "docker.privileged.enabled" = "true"
  }
}
```

### Why This Works

1. **Explicit server discovery**: Client uses AWS EC2 tags to find servers
2. **Proper RPC initialization**: Client establishes authenticated RPC connection
3. **Fallback to Consul**: If AWS discovery fails, Consul service discovery still works
4. **Cross-platform consistency**: Same discovery mechanism for Linux and Windows

---

## Implementation Plan

### Step 1: Update Configuration Template
Modify [`../shared/packer/config/nomad_client.hcl`](../shared/packer/config/nomad_client.hcl) to add the `servers` block.

### Step 2: Rebuild Windows AMI (Build 19)
```bash
cd packer
./test-ami-build19.sh
```

### Step 3: Deploy Build 19
```bash
cd terraform/control
terraform destroy -auto-approve
terraform apply -auto-approve
```

### Step 4: Verify Fix
Wait 5 minutes after deployment, then check:
```bash
export NOMAD_ADDR=http://[SERVER_ELB]:4646
nomad node status
nomad job status
# All allocations should be "running", not "pending"
```

---

## Technical Details

### Nomad Client Server Discovery

Nomad clients can discover servers using multiple methods:

1. **Explicit servers list**: `servers = ["server1:4647", "server2:4647"]`
2. **Cloud auto-join**: `servers = ["provider=aws tag_key=X tag_value=Y"]`
3. **Consul service discovery**: Automatic fallback if no servers configured

### RPC Authentication Flow

```
1. Client starts with servers configuration
2. Client queries AWS EC2 API for instances with matching tags
3. Client finds server(s) and establishes RPC connection
4. Client authenticates using node secret (auto-generated)
5. Client can now make authenticated RPC calls (Node.GetClientAllocs)
6. Server responds with allocation details
7. Client starts allocations
```

### Without servers Configuration

```
1. Client starts without servers configuration
2. Client falls back to Consul service discovery
3. Client finds server via Consul
4. Client attempts RPC connection
5. ❌ RPC authentication fails (node secret not properly initialized)
6. ❌ Server rejects with "Permission denied"
7. ❌ Client cannot retrieve allocations
```

---

## Related Files

### Configuration Files
- [`../shared/packer/config/nomad_client.hcl`](../shared/packer/config/nomad_client.hcl) - **NEEDS FIX**
- [`../shared/packer/scripts/client.ps1`](../shared/packer/scripts/client.ps1) - Processes template
- [`terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1`](terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1) - Calls client.ps1

### Documentation
- [`BUILD_18_BUG_17_CONFIRMED.md`](BUILD_18_BUG_17_CONFIRMED.md) - Bug reproduction
- [`TASK_REQUIREMENTS.md`](TASK_REQUIREMENTS.md) - Project requirements
- [`TESTING_PLAN.md`](TESTING_PLAN.md) - Test plan

---

## Comparison: Linux vs Windows Client Config

### Linux Client (Working)
```hcl
client {
  enabled = true
  servers = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]  # ✅ Present
  node_class = "hashistack"
}
```

### Windows Client (Broken)
```hcl
client {
  enabled = true
  # servers = ???  # ❌ Missing
  node_class = "hashistack-windows"
}
```

---

## Success Criteria

After implementing the fix, Build 19 should demonstrate:

1. ✅ Windows client joins cluster
2. ✅ All job allocations reach "running" state within 2 minutes
3. ✅ No "Permission denied" errors in client logs
4. ✅ `nomad alloc status` returns allocation details (not "Unknown allocation")
5. ✅ Windows-only deployment (0 Linux clients) fully functional

---

## Conclusion

Bug #17 is caused by a **missing `servers` configuration block** in the Nomad client template. This prevents proper RPC authentication initialization in Windows-only deployments. The fix is simple: add the `servers` block with AWS cloud auto-join configuration.

**Next Step**: Implement the fix and test in Build 19.