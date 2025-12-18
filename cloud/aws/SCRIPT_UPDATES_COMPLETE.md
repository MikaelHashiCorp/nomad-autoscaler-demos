# Script Updates for Windows Client Support - Complete

## Summary

Successfully updated all testing and verification scripts to support Windows client deployments alongside Linux clients.

## Scripts Updated

### 1. pre-flight-check.sh
**Changes:**
- Fixed hardcoded paths to use relative paths from script directory
- Added Windows and mixed deployment options to usage instructions
- Now supports: `ubuntu`, `redhat`, `windows`, `mixed`

**Key Updates:**
```bash
# Before: Hardcoded paths
TF_DIR="/Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/terraform/control"

# After: Relative paths
TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/terraform/control"
```

### 2. quick-test.sh
**Changes:**
- Added support for Windows-only deployments (`./quick-test.sh windows`)
- Added support for mixed OS deployments (`./quick-test.sh mixed`)
- Fixed hardcoded paths to use relative paths
- Added Windows-specific variables (TF_WINDOWS_COUNT, SSH_USER for Windows)
- Updated terraform plan to include client count variables
- Enhanced next steps with Windows-specific instructions

**New Deployment Options:**
```bash
./quick-test.sh ubuntu    # Linux (Ubuntu) only - default
./quick-test.sh redhat    # Linux (RedHat) only
./quick-test.sh windows   # Windows only
./quick-test.sh mixed     # Both Linux and Windows
```

**Key Variables Added:**
```bash
# Windows deployment
TF_OS="Windows"
TF_OS_VERSION="2022"
TF_LINUX_COUNT="0"
TF_WINDOWS_COUNT="1"

# Mixed deployment
TF_LINUX_COUNT="1"
TF_WINDOWS_COUNT="1"
```

### 3. verify-deployment.sh
**Changes:**
- Enhanced node status check to distinguish Linux vs Windows nodes
- Added separate IP lookup for Linux and Windows client instances
- Updated instance listing to show OS-specific information
- Added RDP connection instructions for Windows instances
- Filters instances by OS tag (Linux/Windows)

**Key Enhancements:**
```bash
# Node class detection
LINUX_NODES=$(echo "$NODE_OUTPUT" | grep "ready" | grep -c "hashistack-linux" || true)
WINDOWS_NODES=$(echo "$NODE_OUTPUT" | grep "ready" | grep -c "hashistack-windows" || true)

# OS-specific instance filtering
--filters "Name=tag:OS,Values=Linux" "Name=instance-state-name,Values=running"
--filters "Name=tag:OS,Values=Windows" "Name=instance-state-name,Values=running"
```

## Current Deployment Status

### Infrastructure Deployed
- ✅ Linux AMI built: `ami-0cfe2a09be82d814c` (Ubuntu 24.04)
- ✅ Nomad server: 1 instance
- ✅ Linux clients: 1 instance (ASG: `mws-scale-ubuntu-client-linux`)
- ⏳ Windows clients: 0 instances (not requested in current deployment)

### Service Endpoints
- **Nomad UI**: http://mws-scale-ubuntu-server-2031623354.us-west-2.elb.amazonaws.com:4646/ui
- **Consul UI**: http://mws-scale-ubuntu-server-2031623354.us-west-2.elb.amazonaws.com:8500/ui
- **Grafana**: http://mws-scale-ubuntu-client-1580180297.us-west-2.elb.amazonaws.com:3000
- **Prometheus**: http://mws-scale-ubuntu-client-1580180297.us-west-2.elb.amazonaws.com:9090
- **Webapp**: http://mws-scale-ubuntu-client-1580180297.us-west-2.elb.amazonaws.com:80

### Known Issue
**Nomad API Connection Timeout:**
```
Error querying servers: Get "http://...elb.amazonaws.com:4646/v1/agent/members": 
dial tcp 35.83.234.144:4646: i/o timeout
```

**Possible Causes:**
1. Security group rules may need adjustment for external access
2. Nomad server may still be initializing (though unlikely after 15+ minutes)
3. ELB health checks may not have passed yet
4. Network connectivity issue from local machine to AWS

**Recommended Actions:**
1. Check security group rules for Nomad server (port 4646)
2. Verify ELB health check status
3. SSH into server instance to check Nomad service status
4. Check Nomad server logs: `journalctl -u nomad -f`

## Testing Next Steps

### 1. Verify Current Linux Deployment
Once Nomad API is accessible:
```bash
source ~/.zshrc 2>/dev/null && logcmd ./verify-deployment.sh
```

### 2. Test Windows Client Deployment
Update `terraform/control/terraform.tfvars`:
```hcl
windows_client_count = 1
windows_client_instance_type = "t3a.medium"
packer_windows_version = "2022"
```

Then deploy:
```bash
cd terraform/control
source ~/.zshrc 2>/dev/null && logcmd terraform apply -auto-approve
```

### 3. Test Mixed OS Deployment
Update `terraform/control/terraform.tfvars`:
```hcl
client_count = 1              # Linux clients
windows_client_count = 1      # Windows clients
```

Then deploy:
```bash
cd terraform/control
source ~/.zshrc 2>/dev/null && logcmd terraform apply -auto-approve
```

### 4. Use Quick Test Script
```bash
# Test Windows only
source ~/.zshrc 2>/dev/null && logcmd ./quick-test.sh windows

# Test mixed deployment
source ~/.zshrc 2>/dev/null && logcmd ./quick-test.sh mixed
```

## Script Compliance

All scripts now follow bob-instructions.md requirements:
- ✅ Use relative paths (no hardcoded absolute paths)
- ✅ Support Windows client deployments
- ✅ Support mixed OS deployments
- ✅ Proper OS tagging and filtering
- ✅ Windows-specific connection instructions (RDP/SSM)
- ✅ Node class awareness (hashistack-linux, hashistack-windows)

## Files Modified

1. `pre-flight-check.sh` - Updated paths and usage instructions
2. `quick-test.sh` - Added Windows and mixed deployment support
3. `verify-deployment.sh` - Enhanced OS-specific verification

## Documentation References

- [`DEPLOYMENT_SUCCESS.md`](DEPLOYMENT_SUCCESS.md:1) - Full deployment details
- [`TESTING_PLAN.md`](TESTING_PLAN.md:1) - Comprehensive testing plan
- [`TASK_REQUIREMENTS.md`](TASK_REQUIREMENTS.md:1) - Original requirements
- [`.github/bob-instructions.md`](.github/bob-instructions.md:1) - Command execution rules

---

**Status**: Scripts updated and ready for Windows client testing  
**Date**: 2025-12-16  
**Next Action**: Resolve Nomad API connectivity issue, then proceed with Windows deployment testing