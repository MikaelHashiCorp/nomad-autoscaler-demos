# Pre-Build Due Diligence Checklist

## Build Information
- **Build Number**: ubuntu-test-1
- **Date**: 2026-02-24 01:28 UTC
- **Reviewer**: mikael

## MANDATORY 5-PHASE VERIFICATION

### Phase 1: Template Analysis
- [ ] Read ALL template files completely
  - [ ] `../shared/packer/config/consul_client.hcl`
  - [ ] `../shared/packer/config/nomad_client.hcl`
- [ ] List ALL configuration parameters being modified
- [ ] Document expected formats for each parameter
- [ ] Identify parameters with special syntax requirements

**Notes**:


### Phase 2: Transformation Analysis
- [ ] Review ALL string replacements in `../shared/packer/scripts/client.ps1`
- [ ] For EACH replacement, verify:
  - [ ] Source pattern matches template exactly
  - [ ] Target pattern preserves critical characters (slashes, quotes, etc.)
  - [ ] Character-for-character consistency where needed
- [ ] Check for pattern inconsistencies (e.g., source has `/` but target doesn't)

**Replacements Verified**:
- [ ] Line 63: IP_ADDRESS
- [ ] Line 64: RETRY_JOIN (case-sensitive)
- [ ] Line 65: consul data_dir path
- [ ] Line 66: consul log_file path (VERIFY TRAILING SLASH)
- [ ] Line 122: NODE_CLASS (case-sensitive)
- [ ] Line 123: nomad data_dir path
- [ ] Line 124: nomad log_file path (VERIFY TRAILING SLASH)

**Issues Found**:


### Phase 3: Semantic Verification
- [ ] Understand what each parameter expects:
  - [ ] `data_dir`: Directory path (trailing slash optional)
  - [ ] `log_file`: Directory path WITH trailing slash OR base filename
  - [ ] `enable_syslog`: Boolean (true/false)
  - [ ] `retry_join`: Array of strings
  - [ ] `node_class`: Quoted string
- [ ] Verify generated config will be syntactically valid
- [ ] Mentally execute each transformation and verify result

**Expected Generated Configs**:

Consul:
```hcl
data_dir = "C:/HashiCorp/Consul/data"
log_file = "C:/HashiCorp/Consul/logs/"  # Must have trailing slash
enable_syslog = false
retry_join = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
```

Nomad:
```hcl
data_dir = "C:/HashiCorp/Nomad/data"
log_file = "C:/HashiCorp/Nomad/logs/"  # Must have trailing slash
node_class = "hashistack-windows"  # Must be quoted
```

**Semantic Issues Found**:


### Phase 4: Cross-Reference Check
- [ ] Compare Windows config with Linux config
- [ ] Verify semantic equivalence (not just syntactic)
- [ ] Check official Consul/Nomad documentation
- [ ] Review previous bug fixes for similar patterns

**Cross-Reference Results**:


### Phase 5: Simulation
- [ ] Mentally execute COMPLETE transformation for Consul config
- [ ] Mentally execute COMPLETE transformation for Nomad config
- [ ] Predict service behavior with generated config
- [ ] Identify potential failure modes

**Simulation Results**:


## CRITICAL CHECKS

### Trailing Slash Verification
- [ ] Consul log_file: Source `/opt/consul/logs/` → Target `C:/HashiCorp/Consul/logs/`
  - [ ] Both have trailing slash? YES/NO
- [ ] Nomad log_file: Source `/opt/nomad/logs/` → Target `C:/HashiCorp/Nomad/logs/`
  - [ ] Both have trailing slash? YES/NO

### Path Separator Verification
- [ ] All Windows paths use forward slashes (/)
- [ ] No backslashes (\) in path strings
- [ ] No escape sequence issues

### Case Sensitivity Verification
- [ ] RETRY_JOIN uses -creplace (case-sensitive)
- [ ] NODE_CLASS uses -creplace (case-sensitive)
- [ ] Other replacements use -replace (case-insensitive) appropriately

## RISK ASSESSMENT

### What Could Go Wrong?
1. 
2. 
3. 

### How to Detect Failure?
1. 
2. 
3. 

### Rollback Plan
1. 
2. 
3. 

## ALL BUGS VERIFICATION

- [ ] Bug #11: PowerShell case-insensitive replace - FIXED
- [ ] Bug #12: AMI Packer artifacts - FIXED
- [ ] Bug #13: Trailing backslash escape - SUPERSEDED
- [ ] Bug #14: HCL backslash escapes - FIXED
- [ ] Bug #15: Syslog on Windows - FIXED
- [ ] Bug #16: Log file path trailing slash - FIXED

## SIGN-OFF

### Verification Status
- [ ] All phases completed
- [ ] All critical checks passed
- [ ] No issues identified OR all issues documented and resolved
- [ ] Risk assessment completed
- [ ] Detection methods ready

### Approval
- [ ] **I HAVE COMPLETED ALL VERIFICATION PHASES**
- [ ] **I UNDERSTAND THE EXPECTED BEHAVIOR**
- [ ] **I AM CONFIDENT THIS BUILD WILL SUCCEED**

**Reviewer Signature**: _________________________

**Date**: _________________________

**Confidence Level**: ___% (must be >95% to proceed)

---

## MANDATORY RULE

**This checklist MUST be completed and signed off BEFORE running `terraform apply`**

If any phase reveals issues, they MUST be fixed and re-verified before proceeding.
