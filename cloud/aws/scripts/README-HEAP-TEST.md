# Windows Desktop Heap Exhaustion Test

This directory contains scripts and Nomad jobs to replicate and validate the Windows Desktop Heap exhaustion issue documented in [`1-KB-Nomad-Allocation-Failure.md`](../1-KB-Nomad-Allocation-Failure.md).

## Problem Overview

Windows limits the Desktop Heap size for non-interactive processes (services) to 768KB by default. When Nomad spawns many allocations, each allocation consumes desktop heap space for its plugin processes. After approximately 20-25 allocations, the desktop heap is exhausted, causing:

- Error: `"Reattachment process not found"`
- Error: `"failed to start plugin: failed to launch plugin: pipe: Insufficient system resources exist to complete the requested service"`
- Nomad client enters a frozen state
- Restarting the service doesn't help; VM must be destroyed and rebuilt

## Files in This Directory

### 1. `check-windows-desktop-heap.ps1`
PowerShell script that checks the current Desktop Heap configuration on a Windows node.

**What it checks:**
- Current SharedSection registry values
- Non-Interactive Heap size (the critical value)
- Nomad service status
- Current allocation count
- Provides recommendations based on findings

**Run locally on Windows:**
```powershell
powershell.exe -ExecutionPolicy Bypass -File check-windows-desktop-heap.ps1
```

### 2. `check-windows-heap-remote.sh`
Bash script to run the Desktop Heap check remotely via SSH.

**Usage:**
```bash
# Using default values (from script)
./check-windows-heap-remote.sh

# Specifying Windows IP and SSH key
./check-windows-heap-remote.sh 34.222.139.178 ~/.ssh/mhc-aws-mws-west-2.pem
```

**Prerequisites:**
- SSH access to Windows instance
- SSH key file
- SCP enabled on Windows

### 3. `windows-heap-test.nomad`
Nomad job that spawns 30 allocations on Windows clients to trigger desktop heap exhaustion.

**What it does:**
- Targets Windows nodes only (via constraints)
- Spawns 30 allocations (count = 30)
- Uses `raw_exec` driver which spawns plugin processes
- Each allocation runs a simple PowerShell loop
- Designed to exceed the ~24 allocation limit

**Deploy:**
```bash
export NOMAD_ADDR=http://<nomad-server>:4646
nomad job run windows-heap-test.nomad
```

## Test Procedure

### Phase 1: Check Current Configuration

1. **Check Windows Desktop Heap settings:**
   ```bash
   cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-win-bob/cloud/aws/scripts
   chmod +x check-windows-heap-remote.sh
   ./check-windows-heap-remote.sh
   ```

2. **Expected output:**
   - Current SharedSection values
   - Non-Interactive Heap size (likely 768 KB - the default)
   - Analysis and recommendations

### Phase 2: Replicate the Issue

1. **Ensure no other jobs are running on Windows client:**
   ```bash
   export NOMAD_ADDR=http://mws-scale-ubuntu-server-495511731.us-west-2.elb.amazonaws.com:4646
   nomad node status
   nomad job status
   ```

2. **Deploy the stress test job:**
   ```bash
   cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-win-bob/cloud/aws/jobs
   nomad job run windows-heap-test.nomad
   ```

3. **Monitor allocation placement:**
   ```bash
   # Watch allocations in real-time
   watch -n 2 'nomad job status windows-heap-test | grep -A 30 "Allocations"'
   
   # Or check via UI
   # http://mws-scale-ubuntu-server-495511731.us-west-2.elb.amazonaws.com:4646/ui/jobs/windows-heap-test
   ```

4. **Expected behavior:**
   - First ~20-24 allocations should place and run successfully
   - After that, allocations will fail to start
   - Look for "pending" allocations that never become "running"

5. **Check Nomad client logs on Windows:**
   ```bash
   ssh -i ~/.ssh/mhc-aws-mws-west-2.pem Administrator@34.222.139.178
   
   # On Windows:
   Get-Content C:\ProgramData\nomad\logs\nomad.log -Tail 100
   
   # Look for these error messages:
   # [WARN] client.driver_mgr: failed to reattach to plugin, starting new instance
   # error="failed to start plugin: failed to launch plugin: pipe: Insufficient system resources exist to complete the requested service"
   ```

### Phase 3: Apply the Fix

1. **Apply the Desktop Heap fix:**
   ```bash
   ssh -i ~/.ssh/mhc-aws-mws-west-2.pem Administrator@34.222.139.178
   
   # On Windows, run as Administrator:
   $heapLimits = "%SystemRoot%\system32\csrss.exe ObjectDirectory=\Windows SharedSection=1024,20480,4096 Windows On SubSystemType=Windows ServerDll=basesrv,1 ServerDll=winsrv:UserServerDllInitialization,3 ServerDll=sxssrv,4 ProfileControl=Off MaxRequestThreads=16"
   
   Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems" -Name "Windows" -Value $heapLimits
   
   # Restart the system
   Restart-Computer -Force
   ```

2. **Wait for system to come back online** (~3-5 minutes)

3. **Verify the fix:**
   ```bash
   ./check-windows-heap-remote.sh
   # Should now show Non-Interactive Heap: 4096 KB
   ```

### Phase 4: Validate the Fix

1. **Stop the old job:**
   ```bash
   nomad job stop -purge windows-heap-test
   ```

2. **Redeploy the stress test:**
   ```bash
   nomad job run windows-heap-test.nomad
   ```

3. **Monitor allocations:**
   ```bash
   watch -n 2 'nomad job status windows-heap-test'
   ```

4. **Expected behavior after fix:**
   - All 30 allocations should place successfully
   - All should reach "running" state
   - No "Insufficient system resources" errors
   - Can potentially run even more allocations

## Infrastructure Details

**Current Deployment:**
- **Windows Instance:** i-050f0b51a6bf5b06e
- **Public IP:** 34.222.139.178
- **Private IP:** 172.31.28.201
- **Node Name:** EC2AMAZ-975J5MS
- **Node Class:** hashistack-windows
- **SSH User:** Administrator
- **SSH Key:** ~/.ssh/mhc-aws-mws-west-2.pem

**Nomad Cluster:**
- **Nomad Server:** mws-scale-ubuntu-server-495511731.us-west-2.elb.amazonaws.com
- **Nomad UI:** http://mws-scale-ubuntu-server-495511731.us-west-2.elb.amazonaws.com:4646/ui
- **Nomad API:** http://mws-scale-ubuntu-server-495511731.us-west-2.elb.amazonaws.com:4646

## Monitoring Commands

```bash
# Set environment
export NOMAD_ADDR=http://mws-scale-ubuntu-server-495511731.us-west-2.elb.amazonaws.com:4646

# Check node status
nomad node status

# Check specific Windows node
nomad node status EC2AMAZ-975J5MS

# Check job status
nomad job status windows-heap-test

# Check specific allocation
nomad alloc status <alloc-id>

# View allocation logs
nomad alloc logs <alloc-id>

# Get detailed node info
nomad node status -verbose EC2AMAZ-975J5MS | grep -A 10 "Allocations"
```

## SSH Access

```bash
# SSH to Windows instance
ssh -i ~/.ssh/mhc-aws-mws-west-2.pem Administrator@34.222.139.178

# Copy files to Windows
scp -i ~/.ssh/mhc-aws-mws-west-2.pem <local-file> Administrator@34.222.139.178:C:\\Users\\Administrator\\

# Run remote PowerShell command
ssh -i ~/.ssh/mhc-aws-mws-west-2.pem Administrator@34.222.139.178 "powershell.exe -Command '<command>'"
```

## Expected Results

### Before Fix (Default 768KB)
- ✅ First ~20-24 allocations start successfully
- ❌ Allocations 25+ fail with "Insufficient system resources"
- ❌ Nomad logs show "failed to reattach to plugin"
- ❌ Client may become unresponsive

### After Fix (4096KB)
- ✅ All 30 allocations start successfully
- ✅ No resource exhaustion errors
- ✅ Can scale to 50+ allocations if needed
- ✅ Stable client operation

## Cleanup

```bash
# Stop and purge the test job
nomad job stop -purge windows-heap-test

# Verify allocations are removed
nomad node status EC2AMAZ-975J5MS
```

## References

- [`1-KB-Nomad-Allocation-Failure.md`](../1-KB-Nomad-Allocation-Failure.md) - Knowledge Base article
- [GitHub Issue #11939](https://github.com/hashicorp/nomad/issues/11939) - Original issue report
- [GitHub Issue #6715](https://github.com/hashicorp/nomad/issues/6715) - Related issue
- [Microsoft Desktop Heap Overview](https://docs.microsoft.com/en-us/archive/blogs/ntdebugging/desktop-heap-overview)

## Troubleshooting

**Issue: SSH connection refused**
- Verify security groups allow SSH (port 22) from your IP
- Confirm Windows instance is running: `aws ec2 describe-instances --region us-west-2 --instance-ids i-050f0b51a6bf5b06e`

**Issue: SCP fails**
- Ensure OpenSSH is installed and running on Windows
- Check Windows firewall settings

**Issue: Job doesn't place on Windows**
- Verify node is ready: `nomad node status EC2AMAZ-975J5MS`
- Check job constraints match node attributes
- Review node drain/eligibility status

**Issue: Can't see errors in logs**
- Increase Nomad log level on Windows client
- Check Event Viewer for system-level errors
- Monitor Task Manager for process creation failures
