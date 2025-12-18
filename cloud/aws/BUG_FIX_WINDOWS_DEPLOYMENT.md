# Bug Fix: Windows-Only Deployment Issue

## Date
2025-12-16

## Problem Summary
When running `./quick-test.sh windows`, the deployment was building **two Windows AMIs** instead of one Ubuntu AMI (for server) and one Windows AMI (for clients). This caused the Linux build to take 35+ minutes and was actually building a Windows AMI.

## Root Cause
In [`quick-test.sh`](quick-test.sh:87-98), the Windows-only test mode was setting:
```bash
TF_OS="Windows"
TF_OS_VERSION="2022"
TF_OS_NAME=""
```

These variables were passed to **both** Terraform modules:
- `module.hashistack_image_linux` (for server)
- `module.hashistack_image_windows` (for clients)

Since `packer_os="Windows"` was passed to the Linux module, it built a Windows AMI instead of Ubuntu.

## Solution
Modified [`quick-test.sh`](quick-test.sh:87-98) to set correct OS variables for Windows-only mode:

```bash
elif [[ "$OS_TYPE" == "windows" ]]; then
  log "Testing Windows build..."
  PACKER_VARS="-var 'os=Windows' -var 'os_version=2022' -var 'os_name=' -var 'name_prefix=scale-mws-win'"
  NAME_FILTER="scale-mws-win-*"
  SSH_USER="Administrator"
  EXPECTED_OS_ID="windows"
  EXPECTED_PKG_MGR="choco"
  # For Windows-only clients, we still need Ubuntu for the server
  TF_OS="Ubuntu"
  TF_OS_VERSION="24.04"
  TF_OS_NAME="noble"
  TF_LINUX_COUNT="0"
  TF_WINDOWS_COUNT="1"
```

**Key Change**: Set `TF_OS="Ubuntu"` instead of `TF_OS="Windows"` because the server always needs to run Ubuntu/Linux, even in Windows-only client deployments.

## Verification
After the fix, the deployment completed successfully:

### Build Times
- **Windows AMI**: 19m26s ✅
- **Ubuntu AMI**: ~15m ✅ (estimated, not explicitly shown but completed)

### Infrastructure Created
- 1 Ubuntu server instance
- 1 Windows client ASG with 1 instance
- Both AMIs built correctly with proper OS

### Test Results
```bash
./quick-test.sh windows
```

**Output:**
- ✅ Windows AMI: `ami-06ec2566401f3737a`
- ✅ Ubuntu AMI: `ami-02142e1eaa15ae789`
- ✅ Server: 44.243.137.36
- ✅ Windows Client: 52.10.240.168
- ✅ Consul UI accessible
- ✅ Nomad UI accessible
- ✅ Traefik job running

## Architecture Clarification
The deployment architecture requires:
1. **Server nodes**: Always Ubuntu/Linux (runs Consul, Nomad, Vault servers)
2. **Client nodes**: Can be Linux, Windows, or mixed
   - Linux clients: Use `hashistack-linux` node class
   - Windows clients: Use `hashistack-windows` node class

Even in "Windows-only" mode, we're only deploying Windows **clients**, not Windows servers.

## Files Modified
- [`quick-test.sh`](quick-test.sh) - Fixed OS variable assignment for Windows mode

## Related Documentation
- [`TESTING_PLAN.md`](TESTING_PLAN.md) - Testing scenarios
- [`terraform/control/main.tf`](terraform/control/main.tf) - Dual AMI module configuration
- [`terraform/modules/aws-nomad-image/image.tf`](terraform/modules/aws-nomad-image/image.tf) - Packer build logic