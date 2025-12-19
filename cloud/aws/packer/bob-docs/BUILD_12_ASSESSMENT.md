# Build #12 Assessment - Auto-Starting Services Fix

## Date
2025-12-15

## Context Recovery
After upgrading from version 0.11 to 0.12, all chat history was lost. This assessment documents the current state and next steps for Windows AMI creation.

## Previous Work Summary

### Build #11 Status
- **AMI ID**: ami-0d4f68180eaf66dac
- **Result**: Partial success
- **What Works**:
  - ✅ All binaries installed (Consul, Nomad, Vault, Docker)
  - ✅ Docker service starts automatically and runs on boot
  - ✅ SSH service works correctly
  - ✅ Services registered as Windows services with automatic startup
  
- **What Doesn't Work**:
  - ❌ Consul service stops immediately after boot (invalid configuration)
  - ❌ Nomad service stops immediately after boot (invalid configuration)

### Root Cause Analysis
The Consul and Nomad configuration files created in Build #11 were minimal and invalid for standalone operation:

**Build #11 Consul Config** (INVALID):
```hcl
datacenter = "dc1"
data_dir = "C:\\HashiCorp\\Consul\\data"
log_level = "INFO"
server = false  # ← Problem: client mode requires server addresses
```

**Build #11 Nomad Config** (INVALID):
```hcl
datacenter = "dc1"
data_dir = "C:\\HashiCorp\\Nomad\\data"
log_level = "INFO"

client {
  enabled = true  # ← Problem: client mode requires server addresses
}
```

## Build #12 Changes

### Modified File
- **File**: `cloud/shared/packer/scripts/setup-windows.ps1`
- **Lines**: 261-284

### New Consul Configuration (VALID - Standalone Mode)
```hcl
datacenter = "dc1"
data_dir = "C:\\HashiCorp\\Consul\\data"
log_level = "INFO"
server = true                    # ← Server mode
bootstrap_expect = 1             # ← Standalone bootstrap
ui_config {
  enabled = true
}
client_addr = "0.0.0.0"         # ← Listen on all interfaces
bind_addr = "0.0.0.0"           # ← Bind to all interfaces
advertise_addr = "127.0.0.1"    # ← Advertise localhost
```

### New Nomad Configuration (VALID - Standalone Mode)
```hcl
datacenter = "dc1"
data_dir = "C:\\HashiCorp\\Nomad\\data"
log_level = "INFO"

server {
  enabled = true                 # ← Server mode
  bootstrap_expect = 1           # ← Standalone bootstrap
}

client {
  enabled = true                 # ← Also run as client
}
```

## Expected Behavior After Build #12

When an instance boots from the Build #12 AMI:

1. **Consul Service**:
   - Should start automatically
   - Should remain running in standalone server mode
   - Should be accessible via UI on port 8500
   - Should respond to `consul members` command

2. **Nomad Service**:
   - Should start automatically after Consul (dependency configured)
   - Should remain running in server+client mode
   - Should be accessible via UI on port 4646
   - Should respond to `nomad node status` command

3. **Docker Service**:
   - Should start automatically (already working in Build #11)
   - Should remain running
   - Should respond to `docker version` command

4. **SSH Service**:
   - Should start automatically (already working in Build #11)
   - Should accept connections with SSH key

## Validation Plan

### Step 1: Build AMI
```bash
./cloud/aws/packer/test-ami-build12.sh
```

This will:
- Source ~/.zshrc for environment setup
- Use logcmd for timestamped output
- Build Windows Server 2022 AMI with fixed configurations
- Log all output to `cloud/aws/packer/logs/`

### Step 2: Extract AMI ID
```bash
grep 'ami-' cloud/aws/packer/logs/<latest-log-file> | tail -1
```

### Step 3: Launch Test Instance
```bash
# Manual launch or use existing test script
aws ec2 run-instances \
  --image-id <ami-id-from-build> \
  --instance-type t3a.xlarge \
  --key-name <your-key-name> \
  --security-group-ids <sg-id>
```

### Step 4: Validate Running Services
```bash
# Wait for instance to boot (2-3 minutes)
# Then run validation
./cloud/aws/packer/validate-running-instance.sh <instance-ip> <key-name>
```

Expected validation output:
```
[1/5] Checking Consul Service...
  Status: Running
  [PASS] Consul service is running

[2/5] Checking Nomad Service...
  Status: Running
  [PASS] Nomad service is running

[3/5] Checking Docker Service...
  Status: Running
  [PASS] Docker service is running

[5/5] Checking Consul Health...
  Consul Members: <member list>
  [PASS] Consul is healthy and responding

RESULT: ALL CHECKS PASSED
```

## Success Criteria

Build #12 will be considered successful when:

1. ✅ Packer build completes without errors
2. ✅ AMI is created successfully
3. ✅ Test instance launches from AMI
4. ✅ SSH connection works
5. ✅ Consul service is running and healthy
6. ✅ Nomad service is running and healthy
7. ✅ Docker service is running and functional
8. ✅ All services start automatically on boot (no manual intervention)

## Failure Handling

If any step fails:
1. Stop immediately
2. Analyze the failure in the log files
3. Fix the bug in the Packer configuration or scripts
4. Rebuild and revalidate

## Key Files Reference

### Configuration Files
- **Packer HCL**: `cloud/aws/packer/aws-packer.pkr.hcl`
- **Windows Variables**: `cloud/aws/packer/windows-2022.pkrvars.hcl`
- **Setup Script**: `cloud/shared/packer/scripts/setup-windows.ps1`

### Test Scripts
- **Build Script**: `cloud/aws/packer/test-ami-build12.sh`
- **Validation Script**: `cloud/aws/packer/validate-running-instance.sh`

### Documentation
- **Copilot Instructions**: `.github/copilot-instructions.md`
- **Previous Build Results**: `cloud/aws/packer/BUILD_11_*.md`

## Technical Notes

### Standalone vs Cluster Mode
- **Standalone Mode**: Single-node configuration with `bootstrap_expect = 1`
  - Suitable for golden images that will be configured for cluster mode later
  - Services start immediately without waiting for other nodes
  - Can be reconfigured for cluster mode via user-data or configuration management

- **Cluster Mode**: Multi-node configuration with `bootstrap_expect > 1`
  - Requires multiple nodes to bootstrap
  - Not suitable for golden images as services won't start until cluster forms

### Service Dependencies
- Nomad service is configured to start after Consul service
- This ensures Consul is available when Nomad starts
- Configured via Windows service dependencies in setup-windows.ps1

### Why This Approach Works
1. Services are registered with automatic startup
2. Configurations are valid for standalone operation
3. Services can start without external dependencies
4. Configuration can be overridden later via user-data or config management
5. Golden image pattern: pre-configured, ready-to-run base image

## Next Steps After Successful Build

1. Document Build #12 results
2. Update validation scripts if needed
3. Consider creating a comprehensive validation suite
4. Test cluster formation with multiple instances
5. Document configuration override patterns for production use

## References

- HashiCorp Consul Documentation: https://www.consul.io/docs
- HashiCorp Nomad Documentation: https://www.nomadproject.io/docs
- Windows Service Configuration: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-config