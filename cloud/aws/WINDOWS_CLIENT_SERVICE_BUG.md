# Windows Client Service Configuration Bug

## Status: IDENTIFIED - User-Data Executes, But Service Not Reconfigured

## Summary
The simplified EC2Launch v2 fix **successfully allows user-data to execute**, but there's a separate bug in the `client.ps1` script that prevents the Nomad service from being properly reconfigured on Windows instances.

## Evidence

### ✅ User-Data Execution (WORKING)
```
2025-12-17 18:34:29 Info: PowerShell content detected
2025-12-17 18:34:29 Info: User-data conversion completed.
2025-12-17 18:34:33 Info: Type: powershell
2025-12-17 18:34:39 Info: Stage: postReadyUserData completed.
```

User-data log shows:
```
Starting Windows Nomad Client configuration...
Timestamp: 2025-12-17 18:34:38
Executing client configuration script...
  Script: C:\ops\scripts\client.ps1
  Cloud Provider: aws
  Retry Join: provider=aws tag_key=ConsulAutoJoin tag_value=auto-join
  Node Class: hashistack-windows

Client configuration completed successfully
```

### ❌ Service Configuration (BROKEN)

**Current Nomad Service:**
```
BINARY_PATH_NAME: C:\HashiCorp\bin\nomad.exe agent -config=C:\HashiCorp\Nomad\config\nomad.hcl
```

**Config Being Used** (`C:\HashiCorp\Nomad\config\nomad.hcl`):
```hcl
datacenter = "dc1"
data_dir = "C:\\HashiCorp\\Nomad\\data"
log_level = "INFO"

server {
  enabled = true
  bootstrap_expect = 1
}

client {
  enabled = true
}
```

**Problems:**
1. Using SERVER config from AMI (has `server { enabled = true }`)
2. No `server_join` or `retry_join` configuration
3. Trying to bootstrap as standalone server (`bootstrap_expect = 1`)

**Correct Config Created** (`C:\ops\config\nomad_client.hcl`):
```hcl
client {
  enabled    = true
  node_class = NODE_CLASS  # ← Also has placeholder bug

  options {
    "driver.raw_exec.enable"    = "1"
    "docker.privileged.enabled" = "true"
  }
}
```

## Root Cause

The `client.ps1` script:
1. ✅ Creates client config at `C:\ops\config\nomad_client.hcl`
2. ❌ **Does NOT update the Windows service to use the new config**
3. ❌ **Does NOT add retry_join configuration**
4. ❌ Leaves placeholders like `NODE_CLASS` unreplaced

## Impact

- Windows instances launch successfully
- User-data executes successfully  
- Nomad service runs but in wrong mode (server instead of client)
- Instance cannot join the cluster (no retry_join config)
- Shows as "No nodes registered" in cluster

## Next Steps

Need to fix `../shared/packer/scripts/client.ps1` to:
1. Properly update Windows service configuration path
2. Replace template placeholders (NODE_CLASS, paths, etc.)
3. Add retry_join configuration
4. Restart service with correct config

## Test Instance

- Instance ID: `i-09b5bd8aa4a0e7cb6`
- AMI: `ami-0b347d32e8ffa30c9`
- Launch Time: 2025-12-17 18:33:04
- User-Data Execution: ✅ SUCCESS (18:34:38)
- Service Configuration: ❌ FAILED (using wrong config)