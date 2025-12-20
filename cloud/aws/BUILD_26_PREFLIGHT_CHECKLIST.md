# Build 26 Pre-Flight Checklist

## Configuration Review

### ✅ Current terraform.tfvars Settings
```hcl
server_count = 1                      # ✅ 1 Linux server
client_count = 0                      # ❌ NEEDS TO BE 1 for infrastructure jobs
windows_client_count = 1              # ✅ 1 Windows client
windows_ami = ""                      # ✅ Will trigger rebuild
packer_windows_version = "2022"       # ✅ Correct version
```

### ❌ CRITICAL ISSUE: client_count = 0

**Problem**: Infrastructure jobs (traefik, grafana, prometheus, webapp) require Linux clients because they use Docker Linux containers. With `client_count = 0`, these jobs will remain in "pending" state indefinitely.

**Evidence from TESTING_PLAN.md**:
> A deployment is considered **SUCCESSFUL** only when ALL of the following conditions are met:
> 1. All ASGs have appropriate capacity:
>    - Linux client ASG: desired ≥ 1 (if Linux workloads expected)
>    - Windows client ASG: desired ≥ 1 (if Windows workloads expected)
> 3. All infrastructure jobs reach "running" status within 5 minutes

**Required Fix**: Change `client_count` from 0 to 1

### ✅ Deployment Architecture (After Fix)
- **1 Linux Server**: Runs Nomad/Consul/Vault servers
- **1 Linux Client**: Runs infrastructure jobs (traefik, grafana, prometheus, webapp)
- **1 Windows Client**: For Windows-specific workload testing and KB validation

## Root Cause Fix Status

### ✅ Issue Identified
**File**: `terraform/modules/aws-nomad-image/image.tf` line 52
**Problem**: Missing `source env-pkr-var.sh &&` command
**Impact**: Packer uses hardcoded defaults instead of fetching latest versions from HashiCorp APIs

### ⏳ Fix Required
Add back the missing command:
```hcl
provisioner "local-exec" {
  working_dir = "${path.root}/../../packer"
  command = <<EOF
source env-pkr-var.sh && \
  packer build -force \
    -only='${var.packer_os == "Windows" ? "windows" : "linux"}.amazon-ebs.hashistack' \
    -var 'created_name=${var.owner_name}' \
    -var 'created_email=${var.owner_email}' \
    -var 'region=${var.region}' \
    -var 'name_prefix=${var.stack_name}' \
    -var 'os=${var.packer_os}' \
    -var 'os_version=${var.packer_os_version}' \
    -var 'os_name=${var.packer_os_name}' \
    .
EOF
}
```

## Bob Instructions Compliance

### ✅ Command Execution Rules
All commands MUST follow these rules:

1. **Standard commands**: `source ~/.zshrc 2>/dev/null && logcmd <command>`
2. **Packer builds**: `source ~/.zshrc 2>/dev/null && cd packer && ./run-with-timestamps.sh packer build <options> .`
3. **Terraform commands**: `source ~/.zshrc 2>/dev/null && logcmd terraform -chdir=terraform/control <command>`

### ⚠️ Current Violation
Terraform's `local-exec` provisioner runs commands directly without `logcmd` wrapper. This is acceptable for Terraform-managed commands, but we should be aware that these won't appear in logcmd logs.

## Expected Versions After Fix

### From env-pkr-var.sh (Latest from APIs)
When `source env-pkr-var.sh` is executed, it will fetch:
- Consul: Latest from checkpoint-api.hashicorp.com
- Nomad: Latest from checkpoint-api.hashicorp.com  
- Vault: Latest from checkpoint-api.hashicorp.com
- CNI: Latest from GitHub releases

### Current API Versions (as of 2025-12-20)
- Consul: 1.21.4
- Nomad: 1.10.5
- Vault: 1.20.3
- CNI: v1.8.0

### Build 20 Versions (for comparison)
- Consul: 1.22.2
- Nomad: 1.11.1
- Vault: 1.21.1

**Note**: API versions have changed since Build 20. This is expected behavior when using `env-pkr-var.sh`.

## Pre-Flight Actions Required

### 1. Fix terraform.tfvars ⏳
```bash
# Change client_count from 0 to 1
sed -i '' 's/^client_count            = 0/client_count            = 1/' terraform/control/terraform.tfvars
```

### 2. Fix image.tf ⏳
```bash
# Add back source env-pkr-var.sh command
# Manual edit required in terraform/modules/aws-nomad-image/image.tf line 52
```

### 3. Verify Current State ✅
```bash
source ~/.zshrc 2>/dev/null && logcmd terraform -chdir=terraform/control state list
```

Current state shows:
- ✅ 1 server instance
- ✅ Linux client ASG (desired=0, needs to be 1)
- ✅ Windows client ASG (desired=1)

### 4. Clean Up Current Deployment ⏳
Since we have wrong AMI versions and wrong client_count, we should:
```bash
source ~/.zshrc 2>/dev/null && logcmd terraform -chdir=terraform/control destroy -auto-approve
```

### 5. Apply Fixes ⏳
1. Update terraform.tfvars (client_count = 1)
2. Update image.tf (add source env-pkr-var.sh)
3. Commit changes

### 6. Deploy Build 26 ⏳
```bash
source ~/.zshrc 2>/dev/null && logcmd terraform -chdir=terraform/control apply -auto-approve
```

## Success Criteria

### Build Success ✅
- Linux AMI created with correct versions
- Windows AMI created with correct versions
- Both AMIs tagged with version information

### Deployment Success ✅
- 1 server instance running
- Linux client ASG: desired=1, running=1
- Windows client ASG: desired=1, running=1
- All nodes join cluster within 5 minutes
- All infrastructure jobs reach "running" status within 5 minutes

### Version Verification ✅
```bash
# Check server version
nomad node status -json <SERVER_ID> | jq -r '.Attributes["nomad.version"]'

# Check Linux client version
nomad node status -json <LINUX_CLIENT_ID> | jq -r '.Attributes["nomad.version"]'

# Check Windows client version
nomad node status -json <WINDOWS_CLIENT_ID> | jq -r '.Attributes["nomad.version"]'

# All should show same version (from env-pkr-var.sh)
```

### Job Status Verification ✅
```bash
nomad job status
# Expected output:
# ID          Type     Priority  Status   Submit Date
# grafana     service  50        running  <timestamp>
# prometheus  service  50        running  <timestamp>
# traefik     system   50        running  <timestamp>
# webapp      service  50        running  <timestamp>
```

## Risk Assessment

### High Risk ⚠️
1. **Version Drift**: API versions have changed since Build 20
   - Mitigation: Document versions, test compatibility
   
2. **Infrastructure Jobs Pending**: If client_count stays 0
   - Mitigation: Fix terraform.tfvars before deployment

### Medium Risk ⚠️
1. **Build Time**: ~20 minutes for Windows AMI
   - Mitigation: Monitor build progress, have rollback plan

2. **Cost**: ~$0.50 per build attempt
   - Mitigation: Ensure all fixes applied before building

### Low Risk ✅
1. **DNS Propagation**: ELB DNS takes ~60 seconds
   - Mitigation: Retry terraform apply after 60 seconds if jobs fail

## Rollback Plan

If Build 26 fails:
1. Check build logs for errors
2. Verify all fixes were applied
3. If needed, revert to Build 20 AMIs:
   ```bash
   # Set AMI IDs in terraform.tfvars
   ami = "ami-<build20-linux>"
   windows_ami = "ami-<build20-windows>"
   ```

## Timeline Estimate

- Fix terraform.tfvars: 1 minute
- Fix image.tf: 2 minutes
- Destroy current deployment: 5 minutes
- Build 26 deployment: 25 minutes (20 min Windows + 5 min infrastructure)
- Verification: 5 minutes
- **Total**: ~40 minutes

## Next Steps

1. ⏳ Update terraform.tfvars (client_count = 1)
2. ⏳ Update image.tf (add source env-pkr-var.sh)
3. ⏳ Destroy current deployment
4. ⏳ Deploy Build 26
5. ⏳ Verify all nodes join cluster
6. ⏳ Verify all jobs reach running status
7. ⏳ Proceed with KB validation testing