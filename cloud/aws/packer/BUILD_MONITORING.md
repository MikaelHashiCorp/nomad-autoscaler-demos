# Windows AMI Build Monitoring Guide

## Current Build Status

**Instance ID**: `i-0cafd98682bb58153`
**Build Started**: 2025-12-13 00:57 UTC
**Expected Duration**: 15-25 minutes (with Docker installation)

## Enhanced Logging Features

The setup-windows.ps1 script now includes:

1. **Progress Updates Every 15 Seconds**
   - DockerMsftProvider installation: Updates every 15s for up to 5 minutes
   - Docker package installation: Updates every 15s for up to 20 minutes
   - Shows elapsed time and remaining timeout

2. **Real-time Job Output**
   - Displays the last 2-3 lines of output from background jobs
   - Shows what the installation process is doing

3. **Status Checks Every 60 Seconds**
   - Provides reassurance that long-running operations are normal
   - Helps distinguish between normal delays and actual hangs

4. **Verbose Logging**
   - All PowerShell operations use `-Verbose` flag
   - Complete visibility into downloads, installations, and configurations

## Monitoring the Build

### Watch Build Progress
```bash
# Terminal is already tailing the log file
# You'll see real-time updates as they happen
```

### Check Instance Status (if no output for 60+ seconds)
```bash
./check-instance-status.sh i-0cafd98682bb58153
```

### Get Console Output (Windows-specific debugging)
```bash
aws ec2 get-console-output --instance-id i-0cafd98682bb58153 --output text
```

### Check What's Running on Instance
From a Windows machine with PowerShell:
```powershell
# Get credentials first
$cred = Get-Credential

# Check running processes
Invoke-Command -ComputerName <PUBLIC_IP> -Credential $cred -ScriptBlock {
    Get-Process | Where-Object { 
        $_.ProcessName -like '*docker*' -or 
        $_.ProcessName -like '*powershell*' -or
        $_.ProcessName -like '*install*'
    } | Select-Object ProcessName, CPU, WorkingSet
}

# Check top CPU consumers
Invoke-Command -ComputerName <PUBLIC_IP> -Credential $cred -ScriptBlock {
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 ProcessName, CPU, WorkingSet
}
```

## Expected Timeline

1. **0-2 minutes**: Instance launch and WinRM setup
2. **2-3 minutes**: Consul download and installation
3. **3-4 minutes**: Nomad download and installation  
4. **4-5 minutes**: Vault download and installation
5. **5-6 minutes**: Firewall configuration
6. **6-7 minutes**: Docker check (if already installed, skip to step 10)
7. **7-9 minutes**: DockerMsftProvider installation (if needed)
8. **9-25 minutes**: Docker package installation (longest step)
9. **25-26 minutes**: Docker verification
10. **26-27 minutes**: Sysprep and shutdown

## What to Look For

### Normal Progress Indicators
- `[HH:mm:ss]` timestamps on every line
- Progress updates every 15 seconds during Docker installation
- "in progress..." messages with elapsed time
- "Output:" lines showing job activity

### Warning Signs (Potential Issues)
- No output for more than 60 seconds
- Same "Output:" line repeated many times
- Timeout warnings
- Error messages in red

### Critical Issues (Requires Intervention)
- "timed out after X seconds" messages
- Build stops with no further output
- WinRM connection errors
- PowerShell errors in red

## Troubleshooting Steps

### If Build Hangs (No Output for 60+ Seconds)

1. **Check instance status**:
   ```bash
   ./check-instance-status.sh i-0cafd98682bb58153
   ```

2. **Get console output**:
   ```bash
   aws ec2 get-console-output --instance-id i-0cafd98682bb58153 --output text | tail -50
   ```

3. **Check if instance is responsive**:
   ```bash
   aws ec2 describe-instance-status --instance-ids i-0cafd98682bb58153
   ```

4. **If needed, connect via RDP** (from Windows machine):
   - Get password: `aws ec2 get-password-data --instance-id i-0cafd98682bb58153 --priv-launch-key <key-path>`
   - Connect to public IP on port 3389
   - Check Task Manager for running processes
   - Check PowerShell windows for any prompts or errors

### If Docker Installation Times Out

The script now has a 20-minute timeout for Docker installation. If it times out:

1. Check if Docker actually installed despite timeout
2. Consider increasing timeout in setup-windows.ps1
3. Or install Docker post-AMI creation on instances

## Build Artifacts

### Log Files
- Packer output: `logs/mikael-CCWRLY72J2_packer_TIMESTAMP.out`
- Build log: Check terminal output

### AMI Details
Once complete, the AMI will be tagged with:
- Name: `hashistack-Windows-2022-TIMESTAMP`
- OS: Windows
- Version: 2022
- Components: Consul, Nomad, Vault, Docker

## Post-Build Verification

After successful build:

1. **Find the AMI ID** in packer output
2. **Launch test instance**:
   ```bash
   aws ec2 run-instances --image-id ami-XXXXX --instance-type t3a.xlarge --key-name your-key
   ```
3. **Verify installations**:
   - RDP into instance
   - Check: `consul version`, `nomad version`, `vault version`, `docker version`
   - Verify all are in PATH
   - Check services are configured

## Notes

- Docker installation is the longest step (10-20 minutes)
- Progress updates every 15 seconds ensure visibility
- Timeouts are generous to handle slow downloads
- All operations have verbose logging enabled