# Build 26 Deployment Status

**Date:** 2025-12-20  
**Status:** ✅ DEPLOYMENT COMPLETE - READY FOR VALIDATION  
**Build Time:** 22 minutes (Linux: 9m 8s, Windows: 19m 22s)

## Critical Fixes Applied

### Fix #1: Restored Version Management ✅
**File:** `terraform/modules/aws-nomad-image/image.tf` (line 52)
```hcl
# BEFORE (Build 25 - BROKEN):
packer build -force \

# AFTER (Build 26 - FIXED):
source env-pkr-var.sh && \
  packer build -force \
```

**Impact:** Packer now fetches latest versions from HashiCorp APIs instead of using hardcoded defaults.

### Fix #2: Added Linux Client for Infrastructure Jobs ✅
**File:** `terraform/control/terraform.tfvars` (line 15)
```hcl
# BEFORE (Build 25 - BROKEN):
client_count = 0

# AFTER (Build 26 - FIXED):
client_count = 1
```

**Impact:** Infrastructure jobs (traefik, grafana, prometheus, webapp) now have a Linux client to run on.

## AMI Build Results

### Linux AMI ✅
- **AMI ID:** ami-011970e925a2b116c
- **Build Time:** 9 minutes 8 seconds
- **OS:** Ubuntu 24.04
- **Versions:**
  - Consul: 1.22.2
  - Nomad: 1.11.1 ✅ (was 1.10.5 in Build 25)
  - Vault: 1.21.1
  - CNI: v1.9.0

### Windows AMI ✅
- **AMI ID:** ami-011ced41a61b72075
- **Build Time:** 19 minutes 22 seconds
- **OS:** Windows Server 2022
- **Versions:**
  - Consul: 1.22.2
  - Nomad: 1.11.1 ✅ (was 1.10.5 in Build 25)
  - Vault: 1.21.1
  - Docker: 24.0.7 (Windows Containers)
  - OpenSSH Server: Enabled

## Infrastructure Deployment

### Server Nodes ✅
- **Count:** 1
- **Instance ID:** i-0937b4e8b4b8a1839
- **Public IP:** 100.20.87.254
- **Private IP:** 172.31.57.170

### Linux Client ASG ✅
- **Name:** mws-scale-ubuntu-client-linux
- **Desired Capacity:** 1
- **Min:** 0
- **Max:** 10
- **Launch Template:** lt-08182de00c79dee6d

### Windows Client ASG ✅
- **Name:** mws-scale-ubuntu-client-windows
- **Desired Capacity:** 1
- **Min:** 0
- **Max:** 10
- **Launch Template:** lt-00f3c3ea5c4364364

### Load Balancers ✅
- **Server ELB:** mws-scale-ubuntu-server-495511731.us-west-2.elb.amazonaws.com
- **Client ELB:** mws-scale-ubuntu-client-1327529348.us-west-2.elb.amazonaws.com

## Infrastructure Jobs Deployed ✅

All jobs submitted to Nomad (status pending validation):
1. ✅ traefik
2. ✅ prometheus
3. ✅ grafana
4. ✅ webapp

## Access URLs

### Management UIs
- **Nomad UI:** http://mws-scale-ubuntu-server-495511731.us-west-2.elb.amazonaws.com:4646/ui
- **Consul UI:** http://mws-scale-ubuntu-server-495511731.us-west-2.elb.amazonaws.com:8500/ui

### Application UIs
- **Grafana:** http://mws-scale-ubuntu-client-1327529348.us-west-2.elb.amazonaws.com:3000/d/AQphTqmMk/demo?orgId=1&refresh=5s
- **Traefik:** http://mws-scale-ubuntu-client-1327529348.us-west-2.elb.amazonaws.com:8081
- **Prometheus:** http://mws-scale-ubuntu-client-1327529348.us-west-2.elb.amazonaws.com:9090
- **Webapp:** http://mws-scale-ubuntu-client-1327529348.us-west-2.elb.amazonaws.com:80

### CLI Environment Variables
```bash
export NOMAD_CLIENT_DNS=http://mws-scale-ubuntu-client-1327529348.us-west-2.elb.amazonaws.com
export NOMAD_ADDR=http://mws-scale-ubuntu-server-495511731.us-west-2.elb.amazonaws.com:4646
```

## Next Steps (After Break)

### 1. Cluster Validation (5-10 minutes)
```bash
# Set environment variable
export NOMAD_ADDR=http://mws-scale-ubuntu-server-495511731.us-west-2.elb.amazonaws.com:4646

# Check cluster status
nomad node status
nomad server members
consul members

# Verify versions match
nomad node status -verbose | grep -i version
```

**Expected Results:**
- 1 server node (ready)
- 1 Linux client node (ready, class: hashistack-linux)
- 1 Windows client node (ready, class: hashistack-windows)
- All nodes running Nomad 1.11.1

### 2. Infrastructure Jobs Validation (5 minutes)
```bash
# Check job status
nomad job status

# Verify all jobs are running
nomad job status traefik
nomad job status prometheus
nomad job status grafana
nomad job status webapp
```

**Success Criteria:**
- All 4 jobs in "running" status within 5 minutes
- No failed allocations
- All allocations on Linux client (not Windows)

### 3. Windows Client Verification
```bash
# Check Windows node details
nomad node status -verbose <windows-node-id>

# Verify Windows-specific attributes
nomad node status <windows-node-id> | grep -i windows
nomad node status <windows-node-id> | grep -i docker
```

**Expected Attributes:**
- OS: Windows
- Docker: Available
- Node Class: hashistack-windows

### 4. Version Verification
```bash
# SSH to server
ssh ubuntu@100.20.87.254

# Check versions
consul version  # Should be 1.22.2
nomad version   # Should be 1.11.1
vault version   # Should be 1.21.1
```

## Success Metrics

### Build 26 vs Build 25 Comparison

| Metric | Build 25 | Build 26 | Status |
|--------|----------|----------|--------|
| Linux AMI Created | ✅ | ✅ | Same |
| Windows AMI Created | ✅ | ✅ | Same |
| Nomad Version (Linux) | ❌ 1.10.5 | ✅ 1.11.1 | **FIXED** |
| Nomad Version (Windows) | ❌ 1.10.5 | ✅ 1.11.1 | **FIXED** |
| Linux Clients | ❌ 0 | ✅ 1 | **FIXED** |
| Windows Clients | ✅ 1 | ✅ 1 | Same |
| Infrastructure Jobs | ❌ Pending | ⏳ Pending | TBD |

## Root Cause Analysis Summary

### Issue 1: Wrong Versions (Build 25)
**Cause:** Missing `source env-pkr-var.sh &&` command in image.tf  
**Impact:** Packer used hardcoded defaults (1.10.5) instead of API versions (1.11.1)  
**Fix:** Restored the source command  
**Lesson:** Always verify the complete command chain when refactoring

### Issue 2: No Linux Clients (Build 25)
**Cause:** `client_count = 0` in terraform.tfvars  
**Impact:** Infrastructure jobs remained in "pending" state (need Linux clients for Docker)  
**Fix:** Changed to `client_count = 1`  
**Lesson:** Infrastructure jobs require Linux clients; Windows clients cannot run Linux containers

## Build History Context

- **Build 20:** ✅ Successful (baseline with Bug #17 and #18 fixes)
- **Build 21:** ❌ Version mismatch (1.11.1 vs 1.10.5)
- **Build 22:** ❌ Missing user-data template
- **Build 23:** ❌ Linux build error (CNIVERSION)
- **Build 24:** ❌ Windows SCP error
- **Build 25:** ⚠️ Partial success (wrong versions, no Linux clients)
- **Build 26:** ✅ **DEPLOYMENT COMPLETE** (all fixes applied)

## Technical Notes

### Version Management Flow
1. `env-pkr-var.sh` fetches latest versions from HashiCorp APIs
2. Exports as environment variables (NOMADVERSION, CONSULVERSION, etc.)
3. Packer reads via `env("NOMADVERSION")` in variables.pkr.hcl
4. Falls back to hardcoded defaults if env var not set

### Infrastructure Job Requirements
- **Linux Containers:** Require Linux clients (Docker Linux mode)
- **Windows Containers:** Require Windows clients (Docker Windows mode)
- **Current Setup:** 
  - traefik, prometheus, grafana, webapp → Linux client
  - Future Windows workloads → Windows client

### Windows Client Capabilities
- Nomad client with Windows task drivers
- Docker with Windows Containers support
- OpenSSH for remote access
- EC2Launch v2 for user-data execution

## Files Modified in Build 26

1. `terraform/modules/aws-nomad-image/image.tf` - Restored version management
2. `terraform/control/terraform.tfvars` - Added Linux client

## Validation Checklist (Pending)

- [ ] All 3 nodes joined cluster (1 server + 1 Linux client + 1 Windows client)
- [ ] All nodes running Nomad 1.11.1
- [ ] All infrastructure jobs in "running" status
- [ ] No failed allocations
- [ ] Windows client has Docker available
- [ ] Linux client running all 4 infrastructure jobs

## Important Note: Windows Version Mismatch ⚠️

**Current Deployment:** Windows Server 2022 (ami-00b5c2912ac32b41b)
**KB Article Target:** Windows Server 2016

The KB article [`1-KB-Nomad-Allocation-Failure.md`](1-KB-Nomad-Allocation-Failure.md:1) documents a desktop heap exhaustion issue that was primarily reported on **Windows Server 2016**. The issue occurs when Nomad clients reach ~20-25 allocations due to the default 768KB desktop heap limit for non-interactive processes.

**Key Differences:**
- **Windows Server 2016:** Known to have desktop heap exhaustion issues with Nomad
- **Windows Server 2022:** May have different default heap limits or improved resource management
- **Packer Config:** Currently set to `Windows_Server-2022-English-Full-Base-*` (line 37 in packer/aws-packer.pkr.hcl)

**Options for KB Validation:**

### Option 1: Test on Windows Server 2022 (Current)
- **Pros:** Already deployed, ready to test
- **Cons:** May not reproduce the issue if 2022 has higher defaults
- **Action:** Deploy 30 allocations and monitor for failures
- **Outcome:** If no failure, document that issue is specific to 2016

### Option 2: Switch to Windows Server 2016
- **Pros:** Matches KB article target OS, more likely to reproduce issue
- **Cons:** Requires AMI rebuild and redeployment (~25 minutes)
- **Action:** Change Packer filter to `Windows_Server-2016-English-Full-Base-*`
- **Outcome:** Should reproduce desktop heap exhaustion at ~20-25 allocations

### Option 3: Test Both Versions
- **Pros:** Complete validation, documents behavior on both OS versions
- **Cons:** Requires two full deployment cycles (~50 minutes total)
- **Action:** Test 2022 first, then rebuild with 2016 if needed
- **Outcome:** Comprehensive KB validation with version-specific notes

## Next Milestone

**Immediate Goal:** Validate cluster health on Windows Server 2022
**Then Decide:** Whether to test KB on 2022 or rebuild with 2016
**KB Article:** [`1-KB-Nomad-Allocation-Failure.md`](1-KB-Nomad-Allocation-Failure.md:1)
**Test Procedure:** Deploy 30 allocations and monitor for desktop heap exhaustion
**Expected (2016):** Failure at ~20-25 allocations
**Expected (2022):** Unknown - may have higher limits or better resource management

---

**Status:** Ready for validation after break  
**Estimated Validation Time:** 15-20 minutes  
**Next Action:** Run validation scripts when ready to resume