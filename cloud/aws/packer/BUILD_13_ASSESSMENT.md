# Build #13 Assessment - Configuration Bug Fix

**Date**: 2025-12-15  
**Previous Build**: Build #12 (`ami-044ae3ded519b02e6`) - Failed validation  
**Goal**: Fix HCL path escaping bug and create working AMI

---

## Changes from Build #12

### Bug Fix: HCL Path Escaping

**File**: [`cloud/shared/packer/scripts/setup-windows.ps1`](cloud/shared/packer/scripts/setup-windows.ps1:265)

**Line 265** (Consul):
```powershell
# Before:
data_dir = "$($ConsulDir -replace '\\','\\')\data"

# After:
data_dir = "$($ConsulDir -replace '\\','\\')\\data"
```

**Line 283** (Nomad):
```powershell
# Before:
data_dir = "$($NomadDir -replace '\\','\\')\data"

# After:
data_dir = "$($NomadDir -replace '\\','\\')\\data"
```

### Expected Configuration Output

**Consul** (`C:\HashiCorp\Consul\config\consul.hcl`):
```hcl
datacenter = "dc1"
data_dir = "C:\\HashiCorp\\Consul\\data"  # ✅ Fixed
log_level = "INFO"
server = true
bootstrap_expect = 1
ui_config {
  enabled = true
}
client_addr = "0.0.0.0"
bind_addr = "0.0.0.0"
advertise_addr = "127.0.0.1"
```

**Nomad** (`C:\HashiCorp\Nomad\config\nomad.hcl`):
```hcl
datacenter = "dc1"
data_dir = "C:\\HashiCorp\\Nomad\\data"  # ✅ Fixed
log_level = "INFO"

server {
  enabled = true
  bootstrap_expect = 1
}

client {
  enabled = true
}
```

---

## Build Expectations

### What Should Work
- ✅ AMI build completes successfully
- ✅ All binaries installed (Consul, Nomad, Vault, Docker)
- ✅ Configuration files created with valid HCL syntax
- ✅ Services registered with Windows
- ✅ Services set to Automatic startup
- ✅ **Consul service starts on boot**
- ✅ **Nomad service starts on boot**
- ✅ **Docker service starts on boot**

### Success Criteria
1. Packer build completes without errors
2. AMI created successfully
3. Test instance launches from AMI
4. All services running after boot:
   - Consul: Running
   - Nomad: Running
   - Docker: Running
5. Service health checks pass:
   - Consul API responds
   - Nomad API responds
   - Docker daemon responds

---

## Build Process

### Command
```bash
cd cloud/aws/packer
source ~/.zshrc
logcmd ./run-with-timestamps.sh -only='windows.amazon-ebs.hashistack' -var-file=windows-2022.pkrvars.hcl .
```

### Expected Duration
- Build time: ~19-20 minutes
- Validation time: ~4-5 minutes
- **Total**: ~24-25 minutes

### Build Steps
1. Launch Windows Server 2022 base instance
2. Wait for WinRM connectivity
3. Run setup-windows.ps1 provisioner:
   - Download HashiStack binaries
   - Install Docker
   - Create directory structure
   - Generate configuration files (with fix)
   - Register Windows services
4. Create AMI snapshot
5. Terminate build instance

---

## Validation Plan

### Automated Validation
```bash
cd cloud/aws/packer
source ~/.zshrc
logcmd ./validate-build12.sh  # Script will use new AMI ID
```

### Manual Validation (if needed)
```bash
# Launch instance
aws ec2 run-instances \
  --image-id <new-ami-id> \
  --instance-type t3a.xlarge \
  --key-name aws-mikael-test \
  --security-group-ids sg-0dc160eb2b95bba7d \
  --region us-west-2

# SSH and check services
ssh -i ~/.ssh/aws-mikael-test.pem Administrator@<instance-ip>
Get-Service Consul,Nomad,Docker | Select-Object Name,Status,StartType
```

### Expected Validation Output
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

[4/5] Checking Vault Binary...
  [PASS] Vault binary found and executable

[5/5] Checking Consul Health...
  [PASS] Consul is healthy and responding

RESULT: ALL CHECKS PASSED
```

---

## Risk Assessment

### Low Risk
- Configuration syntax fix is straightforward
- No changes to service registration logic
- No changes to binary installation
- Same base image and instance type

### Potential Issues
1. **Other configuration errors**: Unlikely, but possible
2. **Service dependencies**: Docker may have separate issues
3. **Timing issues**: Services may need time to initialize

### Mitigation
- Comprehensive validation script ready
- Can SSH into instance for manual debugging
- Previous builds provide baseline for comparison

---

## Rollback Plan

If Build #13 fails:
1. Review error logs from Packer build
2. Check configuration file syntax on test instance
3. Verify service registration and startup
4. If needed, create Build #14 with additional fixes

---

## Documentation Plan

### During Build
- Monitor Packer output for errors
- Capture build logs with timestamps
- Note any warnings or unusual behavior

### After Build
- Extract AMI ID from logs
- Document build duration
- Record any issues encountered

### After Validation
- Document service status results
- Capture service logs if failures occur
- Create final summary document

---

## Success Metrics

### Build Success
- [  ] Packer build completes without errors
- [  ] AMI created with valid ID
- [  ] Build time within expected range (19-20 min)
- [  ] No warnings in build logs

### Validation Success
- [  ] Instance launches successfully
- [  ] SSH connectivity works
- [  ] Consul service running
- [  ] Nomad service running
- [  ] Docker service running
- [  ] Consul health check passes
- [  ] All validation checks pass

---

## Next Steps After Success

1. Document final results
2. Update bob-instructions with lessons learned
3. Create cleanup commands for test resources
4. Provide summary to user
5. Mark project as complete

---

## Build #13 Ready to Execute

All prerequisites met:
- ✅ Bug identified and fixed
- ✅ Build script ready
- ✅ Validation script ready
- ✅ Documentation prepared
- ✅ AWS credentials valid

**Status**: Ready to proceed with Build #13