# Packer Provisioning Visibility Guide

## Overview
The packer configuration now provides **comprehensive real-time visibility** into all provisioning operations, including detailed progress for Docker installation and HashiStack component downloads.

## Enhanced Visibility Features

### Windows Provisioning ([`setup-windows.ps1`](../shared/packer/scripts/setup-windows.ps1))

**HashiStack Downloads:**
- Shows download URLs for each component
- Displays extraction progress
- Uses `-Verbose` flag for detailed HTTP request information
- Color-coded output (Yellow for in-progress, Green for success, Cyan for info)

**Docker Installation:**
- 4-step progress indicator
- Checks for existing installation
- Shows estimated time for each step
- Displays Docker version after installation
- Graceful error handling with detailed messages

**Example Output:**
```
[Consul] Downloading version 1.22.1...
  URL: https://releases.hashicorp.com/consul/1.22.1/consul_1.22.1_windows_amd64.zip
  Download complete, extracting to C:\HashiCorp\bin...
[Consul] Installed successfully

========================================
Docker Installation
========================================
[1/4] Checking for existing Docker installation...
  Docker not found, proceeding with installation
[2/4] Installing DockerMsftProvider module from PSGallery...
  This may take a few minutes...
```

## Methods to Get Visibility Into Provisioning Scripts

### 1. Real-time Log Monitoring (Recommended)
```bash
tail -f logs/<your-log-file>.out
```
**Pros:**
- Shows complete real-time progress
- Displays all Write-Host output from PowerShell
- Color-coded for easy reading
- Shows detailed download and installation steps

**Cons:** None - this is the primary visibility method

### 2. Enable Debug Logging (For Next Build)
Set environment variable before running packer:
```bash
export PACKER_LOG=1
export PACKER_LOG_PATH="packer-debug.log"
packer build -var-file=windows-2022.pkrvars.hcl .
```
Then monitor with:
```bash
tail -f packer-debug.log | grep -E "stdout|stderr|Provisioning"
```

### 3. Add Explicit Output in Scripts
Modify provisioners to include verbose output:

**For PowerShell provisioners:**
```hcl
provisioner "powershell" {
  inline = [
    "Write-Host '=== Starting Step 1 ==='",
    "# your command here",
    "Write-Host '=== Completed Step 1 ==='"
  ]
}
```

**For Shell provisioners:**
```hcl
provisioner "shell" {
  inline = [
    "echo '=== Starting Step 1 ==='",
    "# your command here",
    "echo '=== Completed Step 1 ==='"
  ]
}
```

### 4. Check packer.log File
The packer.log file contains detailed information:
```bash
tail -100 packer.log | grep -A 10 "stdout\|stderr\|Provisioning"
```

### 5. Add pause_before Parameter (For Debugging)
Add to provisioners to pause and allow manual inspection:
```hcl
provisioner "powershell" {
  pause_before = "30s"  # Pause 30 seconds before running
  script = "setup-windows.ps1"
}
```

### 6. Use Remote Desktop (For Windows)
For Windows builds, you can RDP into the instance while it's building:
1. Get the instance password from AWS Console
2. RDP to the public IP (35.80.7.39 in current build)
3. Watch scripts execute in real-time
4. Check C:\ops\ for uploaded files

**Note:** This requires modifying security group to allow RDP (port 3389)

### 7. Add Logging to Scripts
Modify scripts to write to log files:

**PowerShell:**
```powershell
Start-Transcript -Path "C:\ops\setup.log" -Append
# your commands here
Stop-Transcript
```

**Shell:**
```bash
exec > >(tee -a /ops/setup.log)
exec 2>&1
# your commands here
```

## Current Build Progress Indicators

The build goes through these stages:
1. ✅ Instance launched (i-069494852045ab35f)
2. ✅ WinRM connected (35.80.7.39)
3. 🔄 Running provisioners (currently here)
   - Shell provisioners (should skip for Windows)
   - PowerShell provisioners (creating directories, copying files, installing software)
4. ⏳ Sysprep and AMI creation
5. ⏳ Cleanup and completion

## Troubleshooting Stuck Builds

If a provisioner appears stuck:
1. Check if packer processes are still running: `ps aux | grep packer`
2. Check AWS Console to see if instance is still running
3. Look for timeout errors in logs
4. Consider the provisioner might just be taking a long time (Windows updates, software downloads)

## For This Current Build

The build is currently executing provisioners. Based on the process list, it's likely:
- Running the setup-windows.ps1 script
- Installing Consul, Nomad, and Vault
- Configuring Windows services

These operations can take 5-15 minutes depending on download speeds and Windows configuration.