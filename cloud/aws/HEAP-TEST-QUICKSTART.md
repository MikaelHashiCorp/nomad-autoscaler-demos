# Windows Desktop Heap Test - Quick Start

## Overview
Scripts and jobs created to replicate the Windows Desktop Heap exhaustion issue from KB article `1-KB-Nomad-Allocation-Failure.md`.

## What Was Created

### 1. Scripts
- **[`check-windows-desktop-heap.ps1`](scripts/check-windows-desktop-heap.ps1)** - PowerShell script to check desktop heap settings on Windows
- **[`check-windows-heap-remote.sh`](scripts/check-windows-heap-remote.sh)** - Bash wrapper to run the check remotely via SSH

### 2. Nomad Job
- **[`windows-heap-test.nomad`](jobs/windows-heap-test.nomad)** - Job that spawns 30 allocations to trigger heap exhaustion

### 3. Documentation
- **[`README-HEAP-TEST.md`](scripts/README-HEAP-TEST.md)** - Comprehensive test procedure and documentation

## Quick Test

### Step 1: Check Current Settings
```bash
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-win-bob/cloud/aws/scripts
./check-windows-heap-remote.sh
```

Expected: Shows Non-Interactive Heap = 768 KB (default, problematic)

### Step 2: Replicate the Issue
```bash
export NOMAD_ADDR=http://mws-scale-ubuntu-server-495511731.us-west-2.elb.amazonaws.com:4646
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-win-bob/cloud/aws/jobs
nomad job run windows-heap-test.nomad

# Watch for failures
watch -n 2 'nomad job status windows-heap-test'
```

Expected: ~20-24 allocations succeed, then failures with "Insufficient system resources"

### Step 3: Apply Fix
```bash
ssh -i ~/.ssh/mhc-aws-mws-west-2.pem Administrator@34.222.139.178
```

On Windows:
```powershell
$heapLimits = "%SystemRoot%\system32\csrss.exe ObjectDirectory=\Windows SharedSection=1024,20480,4096 Windows On SubSystemType=Windows ServerDll=basesrv,1 ServerDll=winsrv:UserServerDllInitialization,3 ServerDll=sxssrv,4 ProfileControl=Off MaxRequestThreads=16"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems" -Name "Windows" -Value $heapLimits
Restart-Computer -Force
```

### Step 4: Verify Fix
After reboot (~3-5 min):
```bash
./check-windows-heap-remote.sh
```

Expected: Shows Non-Interactive Heap = 4096 KB

### Step 5: Validate
```bash
nomad job stop -purge windows-heap-test
nomad job run windows-heap-test.nomad
watch -n 2 'nomad job status windows-heap-test'
```

Expected: All 30 allocations succeed

## Infrastructure Details

| Resource | Value |
|----------|-------|
| Windows Instance | i-050f0b51a6bf5b06e |
| Public IP | 34.222.139.178 |
| Private IP | 172.31.28.201 |
| Nomad Node | EC2AMAZ-975J5MS |
| Node Class | hashistack-windows |
| SSH Key | ~/.ssh/mhc-aws-mws-west-2.pem |
| SSH User | Administrator |
| Nomad UI | http://mws-scale-ubuntu-server-495511731.us-west-2.elb.amazonaws.com:4646/ui |

## Files Location

```
cloud/aws/
├── jobs/
│   └── windows-heap-test.nomad          # Nomad job to trigger issue
├── scripts/
│   ├── check-windows-desktop-heap.ps1   # PowerShell heap checker
│   ├── check-windows-heap-remote.sh     # SSH wrapper script
│   └── README-HEAP-TEST.md              # Full documentation
└── 1-KB-Nomad-Allocation-Failure.md     # Original KB article
```

## Key Points

1. **Root Cause:** Windows default Desktop Heap for services is only 768KB
2. **Symptom:** Fails after ~20-25 Nomad allocations with "Insufficient system resources"
3. **Fix:** Increase Non-Interactive Heap to 4096KB via registry
4. **Requires:** Full system reboot for changes to take effect

## Next Steps

1. Run the scripts to validate current configuration
2. Deploy the test job to replicate the issue
3. Document findings with screenshots/logs
4. Apply the fix and validate it works
5. Update KB article with real-world test results

## References

- KB Article: [`1-KB-Nomad-Allocation-Failure.md`](1-KB-Nomad-Allocation-Failure.md)
- Full Procedure: [`scripts/README-HEAP-TEST.md`](scripts/README-HEAP-TEST.md)
- GitHub Issue: https://github.com/hashicorp/nomad/issues/11939
