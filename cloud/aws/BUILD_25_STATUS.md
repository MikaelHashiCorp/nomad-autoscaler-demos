# Build 25 Status Report

## Build Summary
- **Build Number**: 25
- **Date**: 2025-12-20
- **Status**: Partial Success - AMIs created, version mismatch persists
- **Total Build Time**: ~20 minutes

## AMI Build Results

### ✅ Linux AMI - SUCCESS
- **AMI ID**: ami-0a91d5b822ca3c233
- **Build Time**: 9 minutes 8 seconds
- **OS**: Ubuntu 24.04
- **Versions**:
  - Consul: 1.22.2 ✅
  - Nomad: 1.11.1 ✅
  - Vault: 1.21.1 ✅
  - CNI: v1.9.0 ✅
- **Status**: All versions correct, environment variables working

### ✅ Windows AMI - BUILD SUCCESS, VERSION ISSUE
- **AMI ID**: ami-06ee351ed56954425
- **Build Time**: 19 minutes 51 seconds
- **OS**: Windows Server 2022
- **Versions**:
  - Consul: 1.21.4 ⚠️ (Different from Linux)
  - Nomad: 1.10.5 ❌ (Should be 1.11.1)
  - Vault: 1.20.3 ⚠️ (Different from Linux)
  - Docker: 24.0.7 ✅
- **Status**: AMI created successfully, but environment variables not working

## Infrastructure Deployment

### ✅ Resources Created
- Server instance: i-0a6ae08f7d64cfb60
- Server ELB: mws-scale-ubuntu-server
- Client ELB: mws-scale-ubuntu-client
- Linux client ASG: mws-scale-ubuntu-client-linux (desired: 0)
- Windows client ASG: mws-scale-ubuntu-client-windows (desired: 1)
- Security groups created
- IAM roles and policies created

### ❌ Nomad Jobs Failed
All 4 Nomad jobs (traefik, prometheus, grafana, webapp) failed with DNS error:
```
dial tcp: lookup mws-scale-ubuntu-server-479702878.us-west-2.elb.amazonaws.com: no such host
```

**Root Cause**: ELB DNS not yet propagated (expected, will resolve in ~60 seconds)

## Critical Issue: Windows Environment Variables Not Persisting

### Problem
The inline PowerShell provisioner sets environment variables:
```hcl
provisioner "powershell" {
  inline = [
    "$env:CONSULVERSION = '${var.consul_version}'",
    "$env:NOMADVERSION = '${var.nomad_version}'",
    "$env:VAULTVERSION = '${var.vault_version}'",
    "& C:\\ops\\scripts\\setup-windows.ps1"
  ]
}
```

However, when calling the external script with `&`, the environment variables are **not inherited** by the child process.

### Evidence
Build output shows:
```
Nomad 1.10.5  # Should be 1.11.1
Consul 1.21.4  # Latest from API, not pinned 1.22.2
Vault 1.20.3   # Latest from API, not pinned 1.21.1
```

This proves the script is fetching latest versions from HashiCorp API instead of using environment variables.

### Root Cause Analysis
PowerShell environment variables set with `$env:VAR = value` in an inline script block are:
1. **Process-scoped**: Only available in the current PowerShell process
2. **Not inherited**: Child processes (like `& script.ps1`) don't inherit them
3. **Lost on script invocation**: The `&` operator starts a new process

### Solution Options

#### Option 1: Use Script Parameters (RECOMMENDED)
Modify setup-windows.ps1 to accept parameters:
```powershell
param(
    [string]$ConsulVersion,
    [string]$NomadVersion,
    [string]$VaultVersion
)
```

Then call with:
```powershell
& C:\ops\scripts\setup-windows.ps1 -ConsulVersion '1.22.2' -NomadVersion '1.11.1' -VaultVersion '1.21.1'
```

#### Option 2: Use [Environment]::SetEnvironmentVariable
Set machine-level environment variables:
```powershell
[Environment]::SetEnvironmentVariable('NOMADVERSION', '1.11.1', 'Process')
```

#### Option 3: Dot-source the script
Use `. C:\ops\scripts\setup-windows.ps1` instead of `&` to run in same scope.

## Next Steps

### Immediate Actions
1. ✅ Document Build 25 results
2. ⏳ Fix Windows environment variable passing (Option 1 recommended)
3. ⏳ Rebuild Windows AMI (Build 26)
4. ⏳ Wait for ELB DNS propagation (~60 seconds)
5. ⏳ Retry terraform apply to deploy Nomad jobs

### After Build 26 Success
1. Verify Windows client joins cluster with Nomad 1.11.1
2. Check cluster status: `nomad node status`
3. Verify version compatibility
4. Proceed with KB validation testing

## Lessons Learned

### What Worked
- ✅ Merge conflict resolution
- ✅ Linux environment variables passing correctly
- ✅ Windows AMI build process (Docker, services, etc.)
- ✅ Infrastructure deployment automation

### What Didn't Work
- ❌ PowerShell environment variable inheritance with `&` operator
- ❌ Inline script calling external script doesn't preserve env vars

### Key Insight
PowerShell's `&` operator (call operator) starts a new process that doesn't inherit environment variables set in the parent process. This is different from bash where exported variables are inherited by child processes.

## Build Statistics
- **Total Builds**: 25
- **Successful Linux Builds**: 24, 25
- **Successful Windows Builds**: 21 (with version issues), 25 (with version issues)
- **Failed Builds**: 22 (merge conflict), 23 (merge conflict), 24 (SCP error)
- **Bugs Fixed**: 17 (version mismatch), 18 (Docker service)
- **Bugs Remaining**: 17 redux (Windows version mismatch)

## Cost Tracking
- **Current Session Cost**: $89.90
- **Build 25 Cost**: ~$0.33 (20 minutes of build time)