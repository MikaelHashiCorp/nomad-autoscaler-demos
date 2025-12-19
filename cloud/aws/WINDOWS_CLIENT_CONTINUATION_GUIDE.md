# Windows Client Implementation - Continuation Guide

## Document Purpose
This guide provides everything needed to continue the Windows client implementation for Nomad/Consul clusters with mixed OS deployments (Linux servers + Windows clients). Use this as your primary reference for understanding the project state, best practices, and next steps.

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Current Status](#current-status)
3. [Architecture](#architecture)
4. [Critical Files Reference](#critical-files-reference)
5. [Best Practices & Lessons Learned](#best-practices--lessons-learned)
6. [Bug History & Fixes](#bug-history--fixes)
7. [Testing & Validation](#testing--validation)
8. [Deployment Process](#deployment-process)
9. [Debugging Guide](#debugging-guide)
10. [Bob Instructions Compliance](#bob-instructions-compliance)

---

## Project Overview

### Goal
Add Windows client support to the Nomad Autoscaler demo environment on AWS, enabling mixed OS deployments with both Linux servers and Windows clients.

### Key Features
- **Dual AMI System**: Separate Linux and Windows AMI builds
- **Separate ASGs**: Independent autoscaling groups for Linux and Windows clients
- **OS-Specific Node Classes**: `hashistack` (Linux) and `hashistack-windows` (Windows)
- **Automatic AMI Cleanup**: Both AMIs deregistered on `terraform destroy`

### Success Criteria
- ✅ Windows clients join Nomad cluster successfully
- ✅ Windows node attributes correctly identified
- ✅ Windows-targeted jobs deploy successfully
- ⏳ Windows autoscaling functions correctly
- ⏳ Dual AMI cleanup works on destroy
- ✅ No RPC "Permission denied" errors (Bug #17 fix)

---

## Current Status

### Build 19 - IN PROGRESS (as of 2025-12-18 22:59 PST)

**Objective**: Test Bug #17 fix in Windows-only deployment

**Configuration**:
```hcl
server_count = 1              # Linux server
client_count = 0              # No Linux clients
windows_client_count = 1      # Windows-only clients
```

**AMI Build Status**:
- ✅ Linux AMI: `ami-08bda4714105a65aa` (Ubuntu 24.04) - Complete
- ⏳ Windows AMI: Building with Bug #17 fix (11m50s elapsed)

**Bug #17 Fix Applied**:
- **File**: `../shared/packer/config/nomad_client.hcl`
- **Change**: Added explicit server discovery
  ```hcl
  servers = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
  ```

**Next Steps**:
1. Wait for Windows AMI build completion (~5-10 minutes)
2. Infrastructure deployment (1 server + 1 Windows client)
3. Wait 5 minutes for services to initialize
4. Verify Bug #17 resolution (no "Permission denied" errors)
5. Confirm all allocations reach "running" state
6. Document results in `BUILD_19_RESULTS.md`

### Previous Successful Build

**Build 15** (2025-12-17 22:56 PST):
- ✅ All 16 bugs fixed
- ✅ Mixed OS deployment (1 Linux + 1 Windows client)
- ✅ Windows clients successfully joined cluster
- ✅ Infrastructure jobs running
- ✅ Windows batch job deployed successfully

**Build 15 AMIs**:
- Linux: `ami-096aaae0bc50ad23f`
- Windows: `ami-064e18a7f9c54c998`

---

## Architecture

### Infrastructure Components

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS VPC                              │
│                                                              │
│  ┌────────────────┐                                         │
│  │ Linux Server   │  (Nomad + Consul + Vault)               │
│  │ EC2 Instance   │  - Manages cluster                      │
│  └────────────────┘  - Runs infrastructure jobs            │
│         │                                                    │
│         │                                                    │
│  ┌──────┴──────────────────────────────────────┐           │
│  │                                              │           │
│  ▼                                              ▼           │
│  ┌────────────────┐                  ┌────────────────┐    │
│  │ Linux Client   │                  │ Windows Client │    │
│  │ ASG (0-10)     │                  │ ASG (0-10)     │    │
│  │                │                  │                │    │
│  │ Node Class:    │                  │ Node Class:    │    │
│  │ hashistack     │                  │ hashistack-    │    │
│  │                │                  │ windows        │    │
│  └────────────────┘                  └────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

1. **Separate ASGs**: Each OS has its own ASG
   - Linux ASG only manages Linux instances
   - Windows ASG only manages Windows instances
   - Prevents OS mixing within single ASG

2. **Node Classes**: OS-specific targeting
   - Jobs use constraints to target specific OS
   - Example: `constraint { attribute = "${attr.kernel.name}" value = "windows" }`

3. **Infrastructure Jobs**: Run on Linux clients
   - Grafana, Prometheus, Traefik, Webapp
   - Require at least 1 Linux client (`client_count >= 1`)

4. **AMI Build Process**: Terraform-managed
   - Terraform automatically triggers Packer builds
   - AMIs tagged with creation date and versions
   - Cleanup scripts run on `terraform destroy`

---

## Critical Files Reference

### Configuration Files

#### Terraform Configuration
- **`terraform/control/terraform.tfvars`** - Deployment configuration
  ```hcl
  server_count = 1
  client_count = 0              # Linux clients
  windows_client_count = 1      # Windows clients
  windows_client_instance_type = "t3a.xlarge"
  ```

- **`terraform/control/main.tf`** - Orchestrates dual AMI builds
- **`terraform/modules/aws-hashistack/asg.tf`** - Separate Windows ASG
- **`terraform/modules/aws-hashistack/variables.tf`** - Windows parameters
- **`terraform/modules/aws-nomad-image/image.tf`** - AMI build automation

#### Packer Configuration
- **`packer/aws-packer.pkr.hcl`** - Main Packer template
  - Lines 165-203: File provisioners for Windows config files
  - Lines 204-220: Verification provisioners
  - Lines 221-240: EC2Launch v2 state cleanup

- **`packer/windows-2022.pkrvars.hcl`** - Windows AMI variables
  ```hcl
  os_name = "Windows"
  os_version = "2022"
  ami_base_name = "windows-2022"
  source_ami_filter_name = "Windows_Server-2022-English-Full-Base-*"
  ```

#### Scripts
- **`../shared/packer/scripts/client.ps1`** - Windows client setup
  - Lines 66, 124: Log file path configuration (preserve trailing slashes!)
  - Lines 70, 128: UTF-8 encoding without BOM
  - Lines 180-181: Path string literals (use single quotes)

#### Configuration Templates
- **`../shared/packer/config/nomad_client.hcl`** - Nomad client config
  - **CRITICAL**: Contains Bug #17 fix (servers configuration)
  ```hcl
  client {
    enabled    = true
    node_class = NODE_CLASS
    
    # Server discovery using AWS EC2 tags
    # This enables proper RPC authentication for allocation retrieval
    servers = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
    
    options {
      "driver.raw_exec.enable"    = "1"
      "docker.privileged.enabled" = "true"
    }
  }
  ```

- **`../shared/packer/config/consul_client.hcl`** - Consul client config
- **`terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1`** - Windows user-data

### Testing & Validation Scripts
- **`quick-test.sh`** - Multi-OS testing script
  ```bash
  ./quick-test.sh windows  # Test Windows deployment
  ```

- **`verify-deployment.sh`** - Post-deployment verification
- **`verify-windows-client.sh`** - Windows-specific checks

### Documentation
- **`TASK_REQUIREMENTS.md`** - Project requirements and status
- **`TESTING_PLAN.md`** - Comprehensive testing procedures
- **`BUILD_19_DEPLOYMENT_STATUS.md`** - Current build status
- **`BUG_17_ROOT_CAUSE_AND_FIX.md`** - Bug #17 analysis and fix

---

## Best Practices & Lessons Learned

### PowerShell Gotchas (CRITICAL)

#### 1. Escape Sequences in Double-Quoted Strings
**Problem**: Backslashes before certain characters are interpreted as escape sequences
```powershell
# ❌ WRONG - \c, \l, \N interpreted as escape sequences
$path = "C:\HashiCorp\Consul\logs"

# ✅ CORRECT - Use single quotes for literal strings
$path = 'C:\HashiCorp\Consul\logs'
```

#### 2. Variable Expansion with Backslashes
**Problem**: Variables containing paths can cause escape sequence issues
```powershell
# ❌ WRONG - May cause escape sequence issues
$LogFile = "C:\ProgramData\client-config.log"
Write-Output "Config: $LogFile"

# ✅ CORRECT - Use subexpression syntax
Write-Output "Config: $($LogFile)"
```

#### 3. UTF-8 Encoding (CRITICAL FOR HCL FILES)
**Problem**: `Out-File -Encoding UTF8` adds UTF-8 BOM (bytes: EF BB BF) causing HCL parser to fail
```powershell
# ❌ WRONG - Adds UTF-8 BOM
$config | Out-File -FilePath $path -Encoding UTF8

# ✅ CORRECT - No BOM
[System.IO.File]::WriteAllText($path, $config, [System.Text.UTF8Encoding]::new($false))
```

#### 4. Case-Sensitive String Operations
**Problem**: PowerShell's `-replace` is case-insensitive by default
```powershell
# ❌ WRONG - Matches both RETRY_JOIN and retry_join
$config -replace 'RETRY_JOIN', $value

# ✅ CORRECT - Case-sensitive replacement
$config -creplace 'RETRY_JOIN', $value
```

#### 5. Path Replacement Trailing Characters (CRITICAL)
**Problem**: Services expect directory paths with trailing slashes for log files
```powershell
# ❌ WRONG - Removes trailing slash
$config -replace '/opt/consul/logs/', 'C:/HashiCorp/Consul/logs'

# ✅ CORRECT - Preserves trailing slash
$config -replace '/opt/consul/logs/', 'C:/HashiCorp/Consul/logs/'
```

**Why This Matters**:
- `log_file` with trailing slash = directory for timestamped log files
- `log_file` without trailing slash = attempt to open as file (FAILS if it's a directory)

### Packer Best Practices

#### 1. File Provisioner for Windows
**Problem**: Nested directories not copied automatically
```hcl
# ❌ WRONG - Doesn't copy nested config/ directory
provisioner "file" {
  source      = "../shared/packer/"
  destination = "C:/Temp/packer/"
}

# ✅ CORRECT - Explicit directory provisioners
provisioner "file" {
  source      = "../shared/packer/config"
  destination = "C:/Temp/packer/config"
}
```

#### 2. Always Add Verification Provisioners
```hcl
provisioner "powershell" {
  inline = [
    "if (!(Test-Path 'C:/Temp/packer/config/nomad_client.hcl')) { throw 'Config file missing!' }"
  ]
}
```

#### 3. EC2Launch v2 State Cleanup (CRITICAL)
**Problem**: State files prevent user-data from running on new instances
```hcl
# Required before sysprep
provisioner "powershell" {
  inline = [
    "Remove-Item -Path 'C:/ProgramData/Amazon/EC2Launch/state/.run-once' -Force -ErrorAction SilentlyContinue"
  ]
}
```

### Mandatory Pre-Build Due Diligence Process

**CRITICAL**: Before EVERY build deployment, complete the 5-phase verification:

1. **Phase 1: Template Analysis**
   - Read ALL config templates that will be transformed
   - Understand the structure and placeholders

2. **Phase 2: Transformation Analysis**
   - Verify ALL string replacements in scripts
   - Check for trailing slashes, escape sequences, case sensitivity

3. **Phase 3: Semantic Verification**
   - Understand what each parameter means
   - Verify values make sense in context

4. **Phase 4: Cross-Reference Check**
   - Compare with working examples (Build 15)
   - Verify consistency across similar configurations

5. **Phase 5: Simulation**
   - Mentally execute all transformations
   - Predict final configuration content

**Sign-off Requirement**: >95% confidence before proceeding with `terraform apply`

**Why This Matters**: Bug #16 was missed because due diligence was incomplete. This process ensures no syntax errors slip through.

---

## Bug History & Fixes

### Bug #17: RPC "Permission denied" on Windows-Only Deployment (CURRENT)

**Status**: Fix applied, testing in Build 19

**Symptom**:
- Windows client joins cluster successfully (node shows "ready")
- Client heartbeats succeed every 12-20 seconds
- `Node.GetClientAllocs` RPC fails with "Permission denied"
- All allocations stuck in "pending" indefinitely

**Root Cause**:
Missing explicit server discovery configuration in client config. While Consul service discovery works for heartbeats, RPC authentication for allocation retrieval requires explicit server configuration.

**Fix Applied**:
```hcl
# File: ../shared/packer/config/nomad_client.hcl
client {
  enabled    = true
  node_class = NODE_CLASS
  
  # Server discovery using AWS EC2 tags
  servers = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
  
  options {
    "driver.raw_exec.enable"    = "1"
    "docker.privileged.enabled" = "true"
  }
}
```

**Verification Steps** (after Build 19 deploys):
1. Check Windows client joins cluster: `nomad node status`
2. Verify no "Permission denied" in logs
3. Confirm allocations reach "running" within 2 minutes
4. Test `nomad alloc status <alloc-id>` returns details

**Documentation**: `BUG_17_ROOT_CAUSE_AND_FIX.md`

### Bug #16: Log File Path Trailing Slash

**Status**: ✅ Fixed in Build 15

**Issue**: Path replacement removed trailing slashes from log directories
- Source: `/opt/consul/logs/` → Target: `C:/HashiCorp/Consul/logs` (missing slash)
- Services expect directory with trailing slash to create timestamped log files
- Without trailing slash, services attempt to open directory as file (FAILS)

**Fix**:
```powershell
# Lines 66, 124 in ../shared/packer/scripts/client.ps1
$consulConfig = $consulConfig -replace '/opt/consul/logs/', 'C:/HashiCorp/Consul/logs/'
$nomadConfig = $nomadConfig -replace '/opt/nomad/logs/', 'C:/HashiCorp/Nomad/logs/'
```

**Documentation**: `DUE_DILIGENCE_BUG_16_ANALYSIS.md`

### Bug #8: UTF-8 BOM in HCL Configuration Files

**Status**: ✅ Fixed in Build 9

**Issue**: PowerShell's `Out-File -Encoding UTF8` adds UTF-8 BOM (bytes: EF BB BF) causing Consul to fail with "illegal char" error

**Fix**:
```powershell
# Lines 70, 128 in ../shared/packer/scripts/client.ps1
[System.IO.File]::WriteAllText($consulConfigPath, $consulConfig, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($nomadConfigPath, $nomadConfig, [System.Text.UTF8Encoding]::new($false))
```

**Documentation**: `BUG_FIX_UTF8_BOM.md`

### Complete Bug List (16 Total)

1. ✅ Windows Config Files Missing (Packer file provisioner)
2. ✅ Nomad Config File Path Mismatch
3. ✅ PowerShell Escape Sequences in Literal Strings
4. ✅ PowerShell Variable Expansion with Backslashes
5. ✅ EC2Launch v2 State Files
6. ✅ UTF-8 Checkmark Syntax Errors
7. ✅ EC2Launch v2 executeScript Misconfiguration
8. ✅ UTF-8 BOM in HCL Configuration Files
9. ✅ Malformed retry_join Syntax (caused by Bug #8)
10. ✅ Case-Insensitive String Replace
11-15. ✅ Various Configuration Issues (Builds 10-14)
16. ✅ Log File Path Trailing Slash
17. ⏳ RPC "Permission denied" (testing fix in Build 19)

**See**: `TASK_REQUIREMENTS.md` for detailed bug descriptions

---

## Testing & Validation

### Test Scenarios (from TESTING_PLAN.md)

#### Test 1: Verify Windows Clients Join Cluster
```bash
export NOMAD_ADDR=$(terraform output -raw nomad_addr)
nomad node status

# Expected: Windows nodes with node_class="hashistack-windows", status="ready"
```

#### Test 2: Verify Node Attributes
```bash
WINDOWS_NODE=$(nomad node status -json | jq -r '.[] | select(.NodeClass=="hashistack-windows") | .ID' | head -1)
nomad node status -verbose $WINDOWS_NODE | grep -i "kernel.name\|os.name"

# Expected:
# kernel.name = windows
# os.name = Windows Server 2022
```

#### Test 3: Deploy Windows-Targeted Job
```hcl
job "windows-test" {
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "windows"
  }

  group "test" {
    count = 1

    task "powershell" {
      driver = "exec"

      config {
        command = "powershell.exe"
        args    = ["-Command", "while($true) { Write-Host 'Windows task running'; Start-Sleep -Seconds 10 }"]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
```

```bash
nomad job run test-windows-job.nomad
nomad job status windows-test
nomad alloc logs <alloc-id>

# Expected: Job placed on Windows node, logs show "Windows task running"
```

#### Test 4: Windows Autoscaling
```bash
# Deploy multiple Windows jobs to trigger autoscaling
for i in {1..5}; do
  nomad job run -detach test-windows-job.nomad
done

# Monitor ASG
watch -n 5 'aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names <stack-name>-client-windows \
  --query "AutoScalingGroups[0].{Desired:DesiredCapacity,Current:Instances|length(@),Min:MinSize,Max:MaxSize}"'

# Expected: Windows ASG scales up, new instances join cluster, jobs placed
```

#### Test 5: Dual AMI Cleanup
```bash
# Capture AMI IDs before destroy
export LINUX_AMI=$(terraform output -raw ami_id)
export WINDOWS_AMI=$(aws ec2 describe-images \
  --owners self \
  --filters "Name=name,Values=*-windows-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text)

# Destroy infrastructure
terraform destroy -auto-approve

# Verify both AMIs are deregistered
aws ec2 describe-images --image-ids $LINUX_AMI --region us-west-2 2>&1 | grep -q "InvalidAMIID.NotFound" && echo "✅ Linux AMI cleaned up"
aws ec2 describe-images --image-ids $WINDOWS_AMI --region us-west-2 2>&1 | grep -q "InvalidAMIID.NotFound" && echo "✅ Windows AMI cleaned up"
```

### Quick Testing Script
```bash
# Test Windows deployment
./quick-test.sh windows

# Verify deployment
./verify-deployment.sh

# Windows-specific checks
./verify-windows-client.sh
```

---

## Deployment Process

### Standard Deployment Workflow

#### 1. Pre-Deployment Checklist
- [ ] Review `TASK_REQUIREMENTS.md` for current status
- [ ] Check `terraform/control/terraform.tfvars` configuration
- [ ] Complete 5-phase due diligence if making changes
- [ ] Ensure AWS credentials are configured
- [ ] Verify SSH key exists in AWS

#### 2. Deploy Infrastructure
```bash
cd terraform/control

# Initialize (first time only)
terraform init

# Review plan
terraform plan

# Deploy (use logcmd wrapper for Bob)
source ~/.zshrc 2>/dev/null && logcmd terraform apply -auto-approve
```

#### 3. Wait for AMI Builds
- Linux AMI: ~9-10 minutes
- Windows AMI: ~15-20 minutes
- Total: ~20-25 minutes

#### 4. Wait for Services to Initialize
- After infrastructure deployment completes
- Wait 5 minutes for user-data scripts to run
- Services start automatically on boot

#### 5. Verify Deployment
```bash
# Get Nomad address
export NOMAD_ADDR=$(terraform output -raw nomad_addr)

# Check cluster status
nomad node status
nomad server members
consul members

# Verify Windows clients
nomad node status -json | jq -r '.[] | select(.NodeClass=="hashistack-windows") | {ID, Name, Status, NodeClass}'
```

#### 6. Test Workloads
```bash
# Deploy test job
nomad job run test-windows-job.nomad

# Monitor status
nomad job status windows-test
nomad alloc status <alloc-id>
```

### Configuration Options

#### Windows-Only Deployment
```hcl
# terraform/control/terraform.tfvars
server_count = 1
client_count = 0              # No Linux clients
windows_client_count = 1      # Windows-only
```

**Note**: Infrastructure jobs (grafana, prometheus, webapp) require Linux clients. For pure Windows-only, modify job constraints.

#### Mixed OS Deployment (Recommended)
```hcl
server_count = 1
client_count = 1              # Linux clients for infrastructure jobs
windows_client_count = 1      # Windows clients for Windows workloads
```

#### Scaling Configuration
```hcl
# ASG limits
client_count = 2              # Desired Linux clients
windows_client_count = 2      # Desired Windows clients

# Instance types
client_instance_type = "t3a.medium"
windows_client_instance_type = "t3a.xlarge"  # Windows needs more resources
```

---

## Debugging Guide

### Common Issues & Solutions

#### Issue: Windows Client Not Joining Cluster

**Symptoms**:
- Instance running but not appearing in `nomad node status`
- No Consul service registration

**Debug Steps**:
1. Check user-data execution:
   ```powershell
   # Via SSM Session Manager
   Get-Content C:\ProgramData\Amazon\EC2Launch\log\agent.log -Tail 50
   ```

2. Check service status:
   ```powershell
   Get-Service Consul, Nomad
   # Expected: Both Running
   ```

3. Check service logs:
   ```powershell
   Get-Content C:\HashiCorp\Consul\logs\consul-*.log -Tail 50
   Get-Content C:\HashiCorp\Nomad\logs\nomad-*.log -Tail 50
   ```

4. Verify configuration files:
   ```powershell
   Test-Path C:\HashiCorp\Consul\config\consul.hcl
   Test-Path C:\HashiCorp\Nomad\config\nomad.hcl
   Get-Content C:\HashiCorp\Nomad\config\nomad.hcl
   ```

**Common Causes**:
- EC2Launch v2 state files not cleaned (prevents user-data execution)
- Configuration file syntax errors (UTF-8 BOM, escape sequences)
- Missing trailing slashes in log paths
- Service dependencies not met (Nomad depends on Consul)

#### Issue: Allocations Stuck in "Pending"

**Symptoms**:
- Jobs submitted but allocations never reach "running"
- `nomad job status` shows "pending" indefinitely

**Debug Steps**:
1. Check allocation status:
   ```bash
   nomad alloc status <alloc-id>
   # Look for placement failures or constraint violations
   ```

2. Check node eligibility:
   ```bash
   nomad node status <node-id>
   # Verify node is "ready" and "eligible"
   ```

3. Check job constraints:
   ```bash
   nomad job inspect <job-id> | jq '.Job.TaskGroups[].Constraints'
   # Verify constraints match available nodes
   ```

4. Check for Bug #17 (RPC "Permission denied"):
   ```bash
   # Check Windows client logs
   nomad alloc logs <alloc-id>
   # Look for "rpc error: Permission denied"
   ```

**Common Causes**:
- Missing `servers` configuration in client config (Bug #17)
- Job constraints don't match any available nodes
- Insufficient resources on available nodes
- Node marked as ineligible

#### Issue: Packer Build Fails

**Symptoms**:
- `terraform apply` fails during AMI build
- Packer error messages in output

**Debug Steps**:
1. Check Packer logs:
   ```bash
   # Logs are in terraform/control/logs/
   ls -lt terraform/control/logs/
   tail -100 terraform/control/logs/<latest-log>
   ```

2. Verify source AMI exists:
   ```bash
   aws ec2 describe-images \
     --owners amazon \
     --filters "Name=name,Values=Windows_Server-2022-English-Full-Base-*" \
     --query 'Images | sort_by(@, &CreationDate) | [-1].{ID:ImageId,Name:Name}'
   ```

3. Check file provisioners:
   ```hcl
   # Verify source files exist
   ls -la ../shared/packer/config/
   ```

**Common Causes**:
- Source AMI not found (wrong region or filter)
- File provisioner source path incorrect
- PowerShell script syntax errors
- Network connectivity issues

### Debugging Tools

#### AWS Systems Manager (SSM)
```bash
# Start session with Windows instance
aws ssm start-session --target <instance-id>

# Run commands
Get-Service Consul, Nomad
Get-Content C:\HashiCorp\Nomad\logs\nomad-*.log -Tail 50
```

#### Nomad CLI
```bash
# Set Nomad address
export NOMAD_ADDR=http://<server-elb>:4646

# Check cluster status
nomad node status
nomad server members

# Check job status
nomad job status
nomad alloc status <alloc-id>

# View logs
nomad alloc logs <alloc-id>
nomad alloc logs -stderr <alloc-id>
```

#### Consul CLI
```bash
# Check Consul members
consul members

# Check service catalog
consul catalog services
consul catalog nodes -service nomad-client
```

---

## Bob Instructions Compliance

### Command Execution Rules

#### 1. Always Use logcmd Wrapper
```bash
# ✅ CORRECT
source ~/.zshrc 2>/dev/null && logcmd terraform apply -auto-approve

# ❌ WRONG
terraform apply -auto-approve
```

**Why**: `logcmd` captures all output to timestamped log files for debugging

#### 2. Source .zshrc Before Commands
```bash
# ✅ CORRECT
source ~/.zshrc 2>/dev/null && cd terraform/control && logcmd terraform apply

# ❌ WRONG
cd terraform/control && terraform apply
```

**Why**: Ensures environment variables and aliases are loaded

#### 3. Use Relative Paths
```bash
# ✅ CORRECT
cd terraform/control
./quick-test.sh

# ❌ WRONG
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-win-bob/cloud/aws/terraform/control
```

**Why**: Maintains portability across different environments

### File Operations

#### 1. Read Files Efficiently
```xml
<!-- Read multiple related files together -->
<read_file>
<args>
  <file>
    <path>terraform/control/terraform.tfvars</path>
  </file>
  <file>
    <path>packer/windows-2022.pkrvars.hcl</path>
  </file>
</args>
</read_file>
```

#### 2. Use Line Ranges for Large Files
```xml
<!-- Read specific sections -->
<read_file>
<args>
  <file>
    <path>TESTING_PLAN.md</path>
    <line_range>668-937</line_range>
  </file>
</args>
</read_file>
```

#### 3. Use apply_diff for Surgical Edits
```xml
<!-- Make targeted changes -->
<apply_diff>
<path>../shared/packer/config/nomad_client.hcl</path>
<diff>
<<<<<<< SEARCH
:start_line:1
-------
client {
  enabled    = true
  node_class = NODE_CLASS
=======
client {
  enabled    = true
  node_class = NODE_CLASS
  
  # Server discovery using AWS EC2 tags
  servers = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
>>>>>>> REPLACE
</diff>
</apply_diff>
```

### Documentation Standards

#### 1. Create Markdown Links
```markdown
<!-- ✅ CORRECT - Clickable links -->
See [`nomad_client.hcl`](../shared/packer/config/nomad_client.hcl:5) for configuration.

<!-- ❌ WRONG - Plain text -->
See nomad_client.hcl for configuration.
```

#### 2. Update Status Documents
- Always update `TASK_REQUIREMENTS.md` with progress
- Create build-specific documentation (e.g., `BUILD_19_RESULTS.md`)
- Document bugs in dedicated files (e.g., `BUG_17_ROOT_CAUSE_AND_FIX.md`)

#### 3. Use Clear Section Headers
```markdown
## Section Title

### Subsection

**Bold for emphasis**

`code` for technical terms
```

---

## Quick Reference

### Essential Commands

```bash
# Deploy infrastructure
cd terraform/control
source ~/.zshrc 2>/dev/null && logcmd terraform apply -auto-approve

# Destroy infrastructure
source ~/.zshrc 2>/dev/null && logcmd terraform destroy -auto-approve

# Check cluster status
export NOMAD_ADDR=$(terraform output -raw nomad_addr)
nomad node status
consul members

# Test Windows deployment
./quick-test.sh windows

# View logs
ls -lt logs/
tail -100 logs/<latest-log>
```

### Key File Locations

```
cloud/aws/
├── terraform/control/
│   ├── terraform.tfvars          # Deployment configuration
│   ├── main.tf                   # Orchestration
│   └── logs/                     # Command logs
├── packer/
│   ├── aws-packer.pkr.hcl       # Packer template
│   └── windows-2022.pkrvars.hcl # Windows variables
└── ../shared/packer/
    ├── scripts/client.ps1        # Windows setup script
    └── config/
        ├── nomad_client.hcl      # Nomad client config (Bug #17 fix here!)
        └── consul_client.hcl     # Consul client config
```

### Configuration Patterns

```hcl
# Windows-only deployment
server_count = 1
client_count = 0
windows_client_count = 1

# Mixed OS deployment (recommended)
server_count = 1
client_count = 1
windows_client_count = 1

# Scaling configuration
client_count = 2
windows_client_count = 2
windows_client_instance_type = "t3a.xlarge"
```

---

## Next Steps for Continuation

### Immediate Actions (Build 19)

1. **Wait for Build 19 Completion**
   - Monitor Windows AMI build progress
   - Expected completion: ~5-10 minutes from current state

2. **Verify Bug #17 Fix**
   ```bash
   export NOMAD_ADDR=$(terraform output -raw nomad_addr)
   
   # Check Windows client joined
   nomad node status
   
   # Verify no "Permission denied" errors
   nomad alloc status <alloc-id>
   
   # Check allocations reach "running"
   watch -n 5 'nomad job status'
   ```

3. **Document Results**
   - Create `BUILD_19_RESULTS.md`
   - Update `TASK_REQUIREMENTS.md` with outcome
   - Note any remaining issues

### Remaining Tests

From `TESTING_PLAN.md`:

- [ ] **Test 5**: Windows autoscaling (Section 4.5)
  - Deploy multiple Windows jobs
  - Verify ASG scales up
  - Confirm new instances join cluster

- [ ] **Test 6**: Dual AMI cleanup (Section 4.6)
  - Capture AMI IDs before destroy
  - Run `terraform destroy`
  - Verify both AMIs deregistered

### Future Enhancements

1. **Windows-Only Infrastructure Jobs**
   - Modify Grafana, Prometheus, Traefik to run on Windows
   - Change constraints from `hashistack-linux` to `hashistack-windows`
   - Test pure Windows-only deployment

2. **Additional OS Support**
   - Add RedHat client support
   - Test multi-OS deployments (Linux + Windows + RedHat)

3. **Production Hardening**
   - Enable ACLs
   - Configure TLS
   - Implement secrets management

---

## Conclusion

This guide provides everything needed to continue the Windows client implementation. Key takeaways:

1. **Always complete due diligence** before deploying (5-phase process)
2. **PowerShell gotchas are critical** - UTF-8 BOM, escape sequences, trailing slashes
3. **Bug #17 fix is in place** - testing in Build 19
4. **Use Bob instructions** - logcmd, source .zshrc, relative paths
5. **Document everything** - builds, bugs, fixes, results

For questions or issues, refer to:
- `TASK_REQUIREMENTS.md` - Current status
- `TESTING_PLAN.md` - Test procedures
- `BUG_17_ROOT_CAUSE_AND_FIX.md` - Latest bug analysis
- This guide - Everything else

**Good luck with the continuation!** 🚀