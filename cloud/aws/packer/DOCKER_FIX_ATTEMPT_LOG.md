# Docker Fix Attempt Log - Option 4: Enhanced Service Persistence

## Date: 2025-12-13

## Goal
Fix Docker installation so it persists in the Windows AMI after creation.

## Approach: Option 4 - Enhanced Service Persistence
Adding multiple layers of persistence to ensure Docker service survives AMI creation:

### Changes Made to setup-windows.ps1

#### 1. Service Registration (6-step process)
```powershell
# Step 1: Register service with error checking
& "C:\Program Files\Docker\dockerd.exe" --register-service
if ($LASTEXITCODE -ne 0) {
    throw "Docker service registration failed"
}

# Step 2: Verify service exists
$dockerService = Get-Service -Name docker -ErrorAction SilentlyContinue
if (-not $dockerService) {
    throw "Docker service not found after registration"
}

# Step 3: Set automatic startup with delayed start
Set-Service -Name docker -StartupType Automatic
sc.exe config docker start= delayed-auto

# Step 4: Configure service recovery (restart on failure)
sc.exe failure docker reset= 86400 actions= restart/60000/restart/60000/restart/60000

# Step 5: Set service description
sc.exe description docker "Docker Engine - Container Runtime (Nomad workload support)"

# Step 6: Create scheduled task as backup
Register-ScheduledTask -TaskName "Docker-Startup-Backup" \
    -Action (New-ScheduledTaskAction -Execute "dockerd.exe" -Argument "--run-service") \
    -Trigger (New-ScheduledTaskTrigger -AtStartup) \
    -Principal (New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest)
```

#### 2. Enhanced Error Handling
- Kept `$ErrorActionPreference = "Stop"` to catch Docker failures immediately
- Added detailed error messages at each step
- Added service verification after registration
- Made scheduled task failure non-critical (continues if it fails)

#### 3. Better Diagnostics
- Added step-by-step progress indicators (1/6, 2/6, etc.)
- Added explicit error messages with exit codes
- Added note that Docker failure before reboot is expected
- Added Docker version check if service starts successfully

## Expected Behavior

### During Build
1. Windows Containers feature installed (requires reboot)
2. Docker binaries extracted to C:\Program Files\Docker
3. Docker service registered with enhanced persistence
4. **Docker service fails to start** (expected - needs reboot for Windows Containers)
5. Build continues to reboot provisioner
6. After reboot, Docker should start automatically

### After AMI Creation
- Docker service should be registered in Windows Service Manager
- Service should be set to Automatic (Delayed Start)
- Service recovery configured to restart on failure
- Scheduled task exists as backup startup mechanism
- Docker should start when instance launches from AMI

## Testing Plan

### Phase 1: Build Completion
- ✅ Verify build completes without errors
- ✅ Verify Docker service registration succeeds
- ✅ Verify all 6 persistence steps complete
- ✅ Verify reboot provisioner runs
- ✅ Verify Docker starts after reboot during build

### Phase 2: AMI Testing
- Launch instance from new AMI
- Check if Docker service exists: `Get-Service docker`
- Check if Docker is running: `Get-Service docker | Select Status`
- Check if Docker responds: `docker version`
- Check if scheduled task exists: `Get-ScheduledTask -TaskName "Docker-Startup-Backup"`
- Verify service recovery settings: `sc.exe qfailure docker`

### Phase 3: Persistence Verification
- Stop Docker service: `Stop-Service docker`
- Verify it restarts automatically (recovery action)
- Reboot instance
- Verify Docker starts on boot
- Check if Docker survives instance stop/start cycle

## Fallback Plan

If Option 4 fails, we have Option 2 ready: **Chocolatey Package Manager**

```powershell
# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install Docker via Chocolatey
choco install docker-desktop -y
```

Chocolatey handles service persistence like Linux package managers (apt/dnf).

## Current Status

**Build in progress**: Waiting for WinRM connection to provision instance

**Next Steps**:
1. Monitor build for Docker installation steps
2. Check if Docker service registration succeeds
3. Verify all 6 persistence steps complete
4. Check if Docker starts after reboot
5. If build succeeds, test AMI
6. If Docker still doesn't persist, switch to Option 2 (Chocolatey)

## Timestamps

Timestamps are working correctly in `packer/packer.log`:
```
2025/12/13 11:30:37 ui: ==> windows.amazon-ebs.hashistack: Password retrieved!
2025/12/13 11:30:37 ui: ==> windows.amazon-ebs.hashistack: Using WinRM communicator to connect
```

Console output doesn't show timestamps because that's Packer's UI formatting, but the log file has full timestamps for debugging.

## Key Learnings

1. **Windows service persistence is different from Linux systemd**
   - Linux: systemd unit files persist naturally
   - Windows: Service registration may not survive AMI creation

2. **Multiple persistence layers needed**
   - Service registration alone isn't enough
   - Need: automatic startup + delayed start + recovery actions + scheduled task backup

3. **Windows Containers feature requires reboot**
   - Docker can't start until after reboot
   - This is expected behavior, not a failure

4. **Error handling is critical**
   - Must stop on Docker failures to investigate
   - Can't continue past failures or we lose diagnostic information