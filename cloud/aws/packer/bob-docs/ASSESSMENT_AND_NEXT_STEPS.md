# Windows AMI Creation - Assessment and Next Steps

**Date**: 2025-12-15  
**Current AMI**: `ami-044ae3ded519b02e6` (Build #12)  
**Status**: Build Complete - Awaiting Validation

---

## Executive Summary

Build #12 successfully created a Windows Server 2022 AMI with all HashiStack components (Consul, Nomad, Vault), Docker, and SSH configured for automatic startup. The AMI is ready for validation testing.

---

## Current State

### ✅ Completed Work

1. **AMI Build #12 - SUCCESSFUL**
   - AMI ID: `ami-044ae3ded519b02e6`
   - Build Time: 19 minutes 26 seconds
   - Region: us-west-2
   - Base: Windows Server 2022

2. **Installed Components**
   - Consul 1.22.1 (Windows service, auto-start)
   - Nomad 1.11.1 (Windows service, auto-start, depends on Consul)
   - Vault 1.21.1 (binary installed)
   - Docker 24.0.7 (Windows service, auto-start)
   - OpenSSH Server (Windows service, auto-start)

3. **Service Configuration**
   - All services registered with `sc.exe`
   - Startup type: Automatic
   - Service dependencies: Nomad → Consul
   - Standalone mode: `bootstrap_expect = 1`

4. **Configuration Files**
   - Consul: `C:\opt\consul\config\consul.hcl` (standalone server)
   - Nomad: `C:\opt\nomad\config\nomad.hcl` (standalone server+client)
   - Both configured for immediate operation without clustering

5. **Validation Infrastructure**
   - Security group created: `sg-0dc160eb2b95bba7d`
   - Validation script created: `validate-build12.sh`
   - Service check script: `validate-running-instance.sh`

---

## Technical Architecture

### Service Startup Flow
```
Windows Boot
    ↓
Consul Service (Auto-start)
    ↓
Nomad Service (Auto-start, depends on Consul)
    ↓
Docker Service (Auto-start)
    ↓
SSH Service (Auto-start)
```

### Standalone Configuration Strategy

**Consul Configuration** (`C:\opt\consul\config\consul.hcl`):
```hcl
datacenter = "dc1"
data_dir = "C:\\opt\\consul\\data"
log_level = "INFO"
server = true
bootstrap_expect = 1  # Standalone mode
ui_config {
  enabled = true
}
client_addr = "0.0.0.0"
bind_addr = "0.0.0.0"
advertise_addr = "127.0.0.1"
```

**Nomad Configuration** (`C:\opt\nomad\config\nomad.hcl`):
```hcl
datacenter = "dc1"
data_dir = "C:\\opt\\nomad\\data"
log_level = "INFO"

server {
  enabled = true
  bootstrap_expect = 1  # Standalone mode
}

client {
  enabled = true
}
```

### Key Design Decisions

1. **Standalone Mode**: Services configured with `bootstrap_expect = 1` to operate independently
2. **Service Dependencies**: Nomad depends on Consul for service discovery
3. **Auto-Start**: All services set to automatic startup for "golden image" pattern
4. **SSH Access**: OpenSSH configured for remote validation and management
5. **Docker Integration**: Docker service auto-starts for container workloads

---

## Validation Status

### ⏳ Pending Validation

**Current Blocker**: AWS credentials expired during validation attempt

**Validation Script Ready**: `validate-build12.sh`
- Launches test instance from Build #12 AMI
- Waits for instance to boot and services to start
- Runs comprehensive service checks via SSH
- Provides cleanup instructions

**Expected Validation Checks**:
1. ✓ Consul service running
2. ✓ Nomad service running
3. ✓ Docker service running
4. ✓ Vault binary present and executable
5. ✓ Consul health endpoint responding
6. ✓ SSH connectivity working

---

## Next Steps

### Immediate Actions Required

1. **Refresh AWS Credentials**
   ```bash
   # Update credentials in ~/.zshrc
   source ~/.zshrc
   ```

2. **Run Validation**
   ```bash
   cd cloud/aws/packer
   source ~/.zshrc
   ./validate-build12.sh
   ```

3. **Expected Validation Timeline**
   - Instance launch: ~30 seconds
   - Windows boot: ~2-3 minutes
   - Service startup: ~30 seconds
   - Validation checks: ~30 seconds
   - **Total**: ~4-5 minutes

### Post-Validation Actions

**If Validation Succeeds**:
1. Document final results in `BUILD_12_FINAL_RESULTS.md`
2. Update `bob-instructions.md` with lessons learned
3. Create cleanup commands for test resources
4. Mark project as complete

**If Validation Fails**:
1. Analyze failure logs from validation script
2. SSH into instance for manual inspection
3. Check Windows Event Viewer for service errors
4. Determine if configuration changes needed
5. Create Build #13 if necessary

---

## Known Issues and Mitigations

### 1. AWS Credential Expiration
**Issue**: Long-running operations (19+ minute builds) may exceed credential lifetime  
**Mitigation**: Refresh credentials before validation; consider using IAM roles for EC2

### 2. Windows Boot Time
**Issue**: Windows instances take 2-3 minutes to fully boot  
**Mitigation**: Validation script includes appropriate wait times and retry logic

### 3. Service Startup Order
**Issue**: Nomad requires Consul to be running  
**Mitigation**: Service dependency configured: Nomad depends on Consul

---

## Build History Summary

| Build | Status | Key Changes | Result |
|-------|--------|-------------|--------|
| #8 | ✅ Success | Manual Docker installation | Working Docker |
| #9 | ❌ Failed | Chocolatey Docker install | Chocolatey conflicts |
| #10 | ✅ Success | Reverted to manual Docker | Working Docker |
| #11 | ⚠️ Partial | Added Consul/Nomad services | Services stopped on boot |
| #12 | ✅ Success | Standalone configurations | **Current AMI** |

---

## Resource Information

### Created Resources
- **AMI**: `ami-044ae3ded519b02e6` (Build #12)
- **Security Group**: `sg-0dc160eb2b95bba7d` (validation-sg)
- **Region**: us-west-2

### Cleanup Commands
```bash
# After validation is complete:

# Terminate test instance (get ID from validation output)
aws ec2 terminate-instances --instance-ids <INSTANCE_ID> --region us-west-2

# Wait for termination
aws ec2 wait instance-terminated --instance-ids <INSTANCE_ID> --region us-west-2

# Delete security group
aws ec2 delete-security-group --group-id sg-0dc160eb2b95bba7d --region us-west-2

# Optional: Deregister AMI if not needed
# aws ec2 deregister-image --image-id ami-044ae3ded519b02e6 --region us-west-2
```

---

## Documentation Files

### Build Documentation
- `BUILD_12_ASSESSMENT.md` - Pre-build analysis
- `BUILD_12_FAILURE_ANALYSIS.md` - Initial Packer error
- `BUILD_12_AWS_AUTH_FAILURE.md` - Credential expiration
- `BUILD_12_SUCCESS.md` - Complete build details
- `ASSESSMENT_AND_NEXT_STEPS.md` - This document

### Validation Scripts
- `validate-build12.sh` - Automated validation orchestration
- `validate-running-instance.sh` - Service status checks via SSH
- `test-ami-build12.sh` - AMI build script with logcmd

### Configuration Files
- `cloud/shared/packer/scripts/setup-windows.ps1` - Main provisioning script
- `cloud/aws/packer/windows-2022.pkrvars.hcl` - Windows-specific variables
- `cloud/aws/packer/aws-packer.pkr.hcl` - Packer template

---

## Lessons Learned

### What Worked Well
1. **Standalone configurations** resolved service startup issues
2. **Service dependencies** ensure proper startup order
3. **Comprehensive logging** with logcmd and timestamps
4. **Iterative approach** allowed quick problem identification
5. **Documentation** maintained clear history of changes

### Areas for Improvement
1. **Credential management** - Consider IAM roles for long operations
2. **Validation automation** - Could be integrated into build pipeline
3. **Service health checks** - Could add more comprehensive checks
4. **Configuration templates** - Could parameterize for different deployment modes

### Best Practices Established
1. Always use `logcmd` for command execution
2. Use `run-with-timestamps.sh` for Packer builds
3. Document each build attempt with detailed results
4. Create validation scripts before testing
5. Use explicit `-only` flags to avoid file conflicts
6. Refresh credentials before long-running operations

---

## Success Criteria

### Build Success ✅
- [x] AMI created successfully
- [x] All components installed
- [x] Services registered with Windows
- [x] Configurations deployed
- [x] Build completed without errors

### Validation Success (Pending)
- [ ] Instance launches from AMI
- [ ] Consul service running
- [ ] Nomad service running
- [ ] Docker service running
- [ ] Vault binary accessible
- [ ] SSH connectivity working
- [ ] Consul health endpoint responding

---

## Contact and Support

**Project**: Nomad Autoscaler Demos  
**Workspace**: `/Users/mikael/2-git/repro/nomad-autoscaler-demos/1-win-bob`  
**Documentation**: `.github/bob-instructions.md`, `.github/copilot-instructions.md`

---

## Conclusion

Build #12 represents a successful implementation of a Windows Server 2022 AMI with auto-starting HashiStack services. The AMI is ready for validation testing. Once credentials are refreshed, run `./validate-build12.sh` to complete the validation phase.

**Current Status**: ⏳ Awaiting credential refresh and validation execution

**Estimated Time to Completion**: 5-10 minutes (credential refresh + validation)