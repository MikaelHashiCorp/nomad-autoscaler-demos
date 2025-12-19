# Build 18 - Bug #17 Confirmed and Reproduced

**Date**: 2025-12-18  
**Build**: 18  
**Configuration**: Windows-only (0 Linux clients, 1 Windows client, 1 server)  
**AMI**: ami-0468eee7e8ebb4ad3  
**Status**: ❌ **BUG #17 REPRODUCED**

---

## Executive Summary

Bug #17 has been successfully reproduced in Build 18 with a clean Windows-only deployment. All job allocations remain stuck in "pending" status due to RPC authentication failures between the Windows client and the Nomad server.

---

## Deployment Details

### Infrastructure
- **Server**: i-0d3efb26ea13a4b61 (172.31.52.39)
- **Windows Client**: i-04ace377f8e461e41 (EC2AMAZ-1AOOU29)
- **Node ID**: d243cf27
- **Node Status**: ready, eligible
- **Deployment Time**: 2025-12-18 15:57:14 PST
- **Investigation Time**: 2025-12-18 16:03:00 PST (5+ minutes after deployment)

### Configuration Verification
```hcl
client_count         = 0  # No Linux clients
windows_client_count = 1  # One Windows client
```

---

## Bug Symptoms

### 1. Allocation Status
All 4 job allocations stuck in "pending" state after 5+ minutes:

| Job | Allocation ID | Status | Duration | Node |
|-----|---------------|--------|----------|------|
| grafana | 33d567ff | pending | 5m11s | EC2AMAZ-1AOOU29 |
| prometheus | 22ea0c95 | pending | 5m11s | EC2AMAZ-1AOOU29 |
| traefik | 98a62910 | pending | 5m12s | EC2AMAZ-1AOOU29 |
| webapp | dbb05755 | pending | 5m12s | EC2AMAZ-1AOOU29 |

### 2. Server Perspective
- ✅ Server successfully assigned allocations to Windows node
- ✅ Allocations have IP addresses assigned (172.31.24.215)
- ✅ Server shows node as "ready" and "eligible"
- ✅ No errors in server logs

### 3. Client Perspective
- ❌ Client cannot retrieve allocation details from server
- ❌ RPC calls fail with "Permission denied"
- ❌ Error: `"Unknown allocation"` when querying allocation stats

---

## Root Cause Evidence

### Windows Client Logs (via SSM)
```
2025-12-19T00:21:57.670Z [ERROR] client.rpc: error performing RPC to server which is not safe to automatically retry: error="rpc error: Permission denied" rpc=Node.GetClientAllocs server=172.31.52.39:4647
2025-12-19T00:21:57.670Z [ERROR] client: error querying node allocations: error="rpc error: Permission denied"

2025-12-19T00:22:10.556Z [ERROR] client.rpc: error performing RPC to server: error="rpc error: Permission denied" rpc=Node.GetClientAllocs server=172.31.52.39:4647
2025-12-19T00:22:10.556Z [ERROR] client.rpc: error performing RPC to server which is not safe to automatically retry: error="rpc error: Permission denied" rpc=Node.GetClientAllocs server=172.31.52.39:4647
2025-12-19T00:22:10.556Z [ERROR] client: error querying node allocations: error="rpc error: Permission denied"

[Pattern repeats every ~12-16 seconds]
```

### Key Observations
1. **Continuous RPC Failures**: Client attempts `Node.GetClientAllocs` RPC every 12-16 seconds
2. **Permission Denied**: Consistent "Permission denied" error on every attempt
3. **Not Safe to Retry**: Nomad marks these errors as non-retryable
4. **Server Communication**: Client successfully heartbeats to server (node shows as "ready")
5. **Allocation Assignment**: Server successfully assigns allocations (visible in `nomad job status`)
6. **Allocation Retrieval**: Client cannot retrieve assigned allocations via RPC

---

## Technical Analysis

### What Works
- ✅ Node registration and heartbeat
- ✅ Consul service discovery
- ✅ Server-to-client communication (health checks)
- ✅ Allocation scheduling and assignment
- ✅ Network connectivity (172.31.52.39:4647)

### What Fails
- ❌ Client-to-server RPC: `Node.GetClientAllocs`
- ❌ Allocation retrieval from server
- ❌ Allocation stats queries (404 "Unknown allocation")

### RPC Authentication Flow
```
1. Server assigns allocation to Windows client ✅
2. Client attempts to retrieve allocation via Node.GetClientAllocs RPC ❌
3. Server rejects RPC with "Permission denied" ❌
4. Client cannot start allocation (remains "pending") ❌
```

---

## Comparison with Build 15

### Build 15 (Mixed OS - WORKED)
- Configuration: 1 Linux client + 1 Windows client
- Result: ✅ All allocations running successfully
- Windows client: Successfully retrieved and ran allocations

### Build 18 (Windows-only - FAILED)
- Configuration: 0 Linux clients + 1 Windows client
- Result: ❌ All allocations stuck in "pending"
- Windows client: Cannot retrieve allocations (Permission denied)

### Critical Difference
**The presence of a Linux client in Build 15 somehow enabled Windows client RPC authentication to work.**

---

## Hypothesis

The RPC authentication mechanism may have a dependency on:
1. **Initial cluster bootstrap**: Linux client present during server initialization
2. **Gossip encryption keys**: Shared secrets established during mixed-OS deployment
3. **TLS/mTLS certificates**: Certificate chain established with Linux client first
4. **Node secrets**: Authentication tokens generated during initial cluster formation

---

## Next Steps

### Immediate Investigation
1. Compare Nomad server configuration between Build 15 and Build 18
2. Check for gossip encryption key differences
3. Examine TLS certificate generation and distribution
4. Review node secret generation process
5. Check for any OS-specific RPC authentication code paths

### Potential Solutions
1. **Pre-seed gossip keys**: Ensure Windows client has correct gossip encryption keys
2. **TLS certificate distribution**: Verify Windows client has proper TLS certificates
3. **Node secret initialization**: Check if node secrets are properly generated for Windows
4. **Server configuration**: Review server RPC authentication settings
5. **Bootstrap order**: Investigate if server needs Linux client for initial bootstrap

---

## Files for Review

### Configuration Files
- `terraform/control/terraform.tfvars` - Deployment configuration
- `terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1` - Windows client initialization
- `../shared/packer/scripts/client.ps1` - Windows client Nomad configuration

### Log Files
- Windows client: `C:\HashiCorp\Nomad\logs\nomad.log`
- Server: `journalctl -u nomad` (no permission errors found)

---

## Conclusion

Bug #17 is **CONFIRMED** and **REPRODUCIBLE** in Windows-only deployments. The issue is a client-side RPC authentication failure that prevents Windows clients from retrieving allocations from the server when no Linux clients are present during initial deployment.

**Impact**: Windows-only deployments are currently **non-functional** due to this RPC authentication issue.

**Priority**: **CRITICAL** - Blocks Windows-only deployment capability.