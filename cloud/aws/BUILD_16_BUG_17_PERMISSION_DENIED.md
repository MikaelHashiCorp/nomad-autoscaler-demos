# Bug #17: Nomad Client Permission Denied Error

## Discovery
**Build**: 16
**Date**: 2025-12-18 14:54 PST
**Status**: ❌ CRITICAL - Blocks all workload execution

## Symptoms

### 1. Windows Node Joins Cluster Successfully
```
ID        Node Pool  DC   Name             Class               Status
050a6322  default    dc1  EC2AMAZ-83M26RG  hashistack-windows  ready
```

### 2. All Allocations Stuck in Pending
```
ID        Node ID   Task Group  Version  Desired  Status   Created
450d843e  050a6322  test        0        run      pending  25s ago
036e8988  050a6322  grafana     0        run      pending  28m ago
```

### 3. Client Logs Show Permission Denied
```
[ERROR] client.rpc: error performing RPC to server: error="rpc error: Permission denied" rpc=Node.GetClientAllocs server=172.31.51.1:4647
[ERROR] client.rpc: error performing RPC to server which is not safe to automatically retry: error="rpc error: Permission denied" rpc=Node.GetClientAllocs
[ERROR] client: error querying node allocations: error="rpc error: Permission denied"
```

## Root Cause Analysis

### Hypothesis 1: ACL Configuration Issue
The error "Permission denied" suggests an ACL (Access Control List) problem. The client may be trying to authenticate but doesn't have the proper credentials or permissions.

### Hypothesis 2: TLS/mTLS Configuration
The client might be configured for TLS but the server isn't, or vice versa, causing authentication failures.

### Hypothesis 3: Gossip Encryption Mismatch
Consul gossip encryption keys might be mismatched between server and client.

### Hypothesis 4: New Issue in Build 16
This is a NEW issue that didn't occur in Build 15. Something changed between builds.

## Key Differences: Build 15 vs Build 16

### Build 15 (WORKED)
- **Configuration**: Mixed OS (client_count=1, windows_client_count=1)
- **Linux Client**: Present (i-0fe3b25ecb13b95a8)
- **Windows Client**: Present (i-0f2e74fcb95361c77)
- **Result**: Windows node joined, jobs ran successfully

### Build 16 (FAILED)
- **Configuration**: Windows-only (client_count=0, windows_client_count=1)
- **Linux Client**: None
- **Windows Client**: Present (i-0fbc89f47366babb0)
- **Result**: Windows node joined, but can't get allocations

## Critical Observation

**The ONLY difference is the absence of Linux clients!**

This suggests the issue might be:
1. Server configuration depends on having at least one Linux client
2. Some initialization or bootstrap process requires a Linux client
3. ACL tokens are generated/distributed via Linux clients
4. There's a race condition in server startup without Linux clients

## Investigation Steps Needed

### 1. Check Server Configuration
```bash
# SSH to server
ssh ubuntu@35.86.214.111

# Check Nomad server config
cat /etc/nomad.d/nomad.hcl

# Check for ACL configuration
grep -i acl /etc/nomad.d/nomad.hcl

# Check server logs
sudo journalctl -u nomad -n 100
```

### 2. Check Client Configuration
```powershell
# Via SSM to Windows instance
Get-Content C:\HashiCorp\Nomad\config\nomad.hcl

# Check for ACL token configuration
Select-String -Path C:\HashiCorp\Nomad\config\nomad.hcl -Pattern "acl"
```

### 3. Compare Configurations
- Compare server config between Build 15 and Build 16
- Compare client config between Build 15 and Build 16
- Check if any ACL-related settings changed

### 4. Test Theory
Deploy with client_count=1 to see if adding a Linux client resolves the issue.

## Workaround

**Temporary Solution**: Deploy with at least one Linux client
```hcl
client_count         = 1  # Add Linux client
windows_client_count = 1  # Keep Windows client
```

This matches Build 15 configuration which worked successfully.

## Impact

**Severity**: CRITICAL
- Windows nodes cannot receive work assignments
- All jobs stuck in pending state
- Blocks Windows-only deployment model
- Affects production readiness

## Next Steps

1. ⏳ Investigate server configuration
2. ⏳ Check for ACL-related settings
3. ⏳ Compare Build 15 vs Build 16 configs
4. ⏳ Test workaround (add Linux client)
5. ⏳ Identify root cause
6. ⏳ Implement fix
7. ⏳ Test Windows-only deployment again

## Related Files

- **Server Config**: `/etc/nomad.d/nomad.hcl` (on server)
- **Client Config**: `C:\HashiCorp\Nomad\config\nomad.hcl` (on Windows client)
- **Client Script**: `../shared/packer/scripts/client.ps1`
- **Server Template**: `terraform/modules/aws-hashistack/templates/user-data-server.sh`

## References

- **Build 15 Success**: BUILD_15_SUCCESS_SUMMARY.md
- **Build 16 Status**: BUILD_16_STATUS.md
- **Nomad Logs**: Retrieved via SSM (see above)