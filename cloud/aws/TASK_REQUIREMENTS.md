# Windows Client Support - Task Requirements and Status

## Project Overview
Add Windows client support to the Nomad Autoscaler demo environment on AWS, enabling mixed OS deployments with both Linux and Windows Nomad clients.

## Current Status: ✅ Build 26 DEPLOYED & DESTROYED - Project Complete

### Completed Work ✅

#### 1. Architecture Implementation
- ✅ Dual AMI build system (Linux + Windows)
- ✅ Separate autoscaling groups for Linux and Windows clients
- ✅ OS-specific node classes (`hashistack` for Linux, `hashistack-windows` for Windows)
- ✅ Windows-specific user-data template
- ✅ AMI cleanup logic for both OS types

#### 2. Infrastructure Code
- ✅ `terraform/control/variables.tf` - Added Windows client variables
- ✅ `terraform/control/terraform.tfvars.sample` - Added Windows configuration examples
- ✅ `terraform/modules/aws-nomad-image` - Supports dual AMI builds
- ✅ `terraform/modules/aws-hashistack/asg.tf` - Separate Windows client ASG
- ✅ `terraform/modules/aws-hashistack/variables.tf` - Windows client parameters
- ✅ `terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1` - Windows user-data
- ✅ `terraform/control/main.tf` - Orchestrates both AMI builds

#### 3. Testing Infrastructure
- ✅ `TESTING_PLAN.md` - Comprehensive Windows testing scenarios
- ✅ `quick-test.sh` - Multi-OS testing script with Windows mode

### Critical Bugs Fixed 🐛 (Total: 18)

#### Bug #1: Windows Config Files Missing
**File**: `packer/aws-packer.pkr.hcl`
**Issue**: Packer file provisioner not copying nested `config/` directory on Windows
**Solution**: Split into explicit directory provisioners with verification (lines 165-203)
**Status**: ✅ Fixed
**Documentation**: `PACKER_FILE_PROVISIONER_ANALYSIS.md`

#### Bug #2: Nomad Config File Path Mismatch
**File**: `../shared/packer/scripts/client.ps1`
**Issue**: Service expected config at `C:\HashiCorp\Nomad\config\nomad.hcl` but script wrote to `C:\HashiCorp\Nomad\nomad.hcl` (line 127)
**Solution**: Changed to write to correct path with config subdirectory
**Status**: ✅ Fixed
**Documentation**: `BUG_FIX_NOMAD_CONFIG_PATH.md`, `BUG_ANALYSIS_NOMAD_CONFIG_PATH_MISMATCH.md`

#### Bug #3: PowerShell Escape Sequences in Literal Strings
**File**: `../shared/packer/scripts/client.ps1`
**Issue**: Backslashes in double-quoted strings interpreted as escape sequences (lines 180-181)
**Solution**: Changed double quotes to single quotes for literal path strings
**Status**: ✅ Fixed
**Documentation**: `BUG_FIX_POWERSHELL_ESCAPE_SEQUENCES.md`

#### Bug #4: PowerShell Variable Expansion with Backslashes
**File**: `../shared/packer/scripts/client.ps1`
**Issue**: Variable `$LogFile` containing backslashes caused escape sequence issues when expanded in double-quoted string (line 179)
**Solution**: Used subexpression syntax `$($LogFile)` to safely expand variable
**Status**: ✅ Fixed
**Documentation**: `BUG_FIX_POWERSHELL_VARIABLE_EXPANSION.md`

#### Bug #5: EC2Launch v2 State Files
**File**: `packer/aws-packer.pkr.hcl`
**Issue**: EC2Launch v2 state files prevent user-data from running on new instances
**Solution**: Delete state files before sysprep
**Status**: ✅ Fixed
**Documentation**: `BUG_FIX_EC2LAUNCH_V2.md`

#### Bug #6: UTF-8 Checkmark Syntax Errors
**File**: `../shared/packer/scripts/client.ps1`
**Issue**: UTF-8 checkmark characters (✓) causing PowerShell syntax errors
**Solution**: Replaced with ASCII text
**Status**: ✅ Fixed

#### Bug #7: EC2Launch v2 executeScript Misconfiguration
**File**: `packer/config/ec2launch-agent-config.yml`
**Issue**: Added `content: <userdata>` which was treated as literal PowerShell code, causing EC2Launch service crash
**Solution**: Removed executeScript task entirely - EC2Launch v2 handles user-data automatically
**Status**: ✅ Fixed (Build 9)
**Documentation**: `BUG_FIX_EC2LAUNCH_V2_ROOT_CAUSE.md`

#### Bug #8: UTF-8 BOM in HCL Configuration Files
**File**: `../shared/packer/scripts/client.ps1` (lines 70, 128)
**Issue**: PowerShell's `Out-File -Encoding UTF8` adds UTF-8 BOM (bytes: EF BB BF) causing Consul to fail with "illegal char" error
**Solution**: Use `[System.IO.File]::WriteAllText()` with UTF8Encoding($false) for BOM-free UTF-8
**Status**: ✅ Fixed (Build 9)
**Documentation**: `BUG_FIX_UTF8_BOM.md`

#### Bug #9: Malformed retry_join Syntax
**File**: Generated `consul.hcl`
**Issue**: Malformed retry_join line in generated config
**Root Cause**: Caused by Bug #8 (UTF-8 BOM corruption)
**Status**: ✅ Resolved by Bug #8 fix

#### Bug #10: Case-Insensitive String Replace
**File**: `../shared/packer/scripts/client.ps1`
**Issue**: PowerShell's `-replace` operator is case-insensitive, causing `RETRY_JOIN` placeholder to match `retry_join` in config
**Solution**: Use `-creplace` for case-sensitive replacement
**Status**: ✅ Fixed (Build 10)

#### Bug #11-15: Various Configuration Issues
**Status**: ✅ Fixed in Builds 10-14
**Documentation**: See individual build documentation

#### Bug #16: Log File Path Trailing Slash
**File**: `../shared/packer/scripts/client.ps1` (lines 66, 124)
**Issue**: Path replacement removed trailing slashes from log directories
- Source: `/opt/consul/logs/` → Target: `C:/HashiCorp/Consul/logs` (missing trailing slash)
- Source: `/opt/nomad/logs/` → Target: `C:/HashiCorp/Nomad/logs` (missing trailing slash)
- Services expect directory with trailing slash to create timestamped log files
- Without trailing slash, services attempt to open directory as file, causing failure
**Solution**: Preserve trailing slashes in both source and target paths
**Status**: ✅ Fixed (Build 15)
**Documentation**: `DUE_DILIGENCE_BUG_16_ANALYSIS.md`

#### Bug #17: RPC "Permission denied" on Windows-Only Deployment
**File**: `../shared/packer/config/nomad_client.hcl`
**Issue**: Windows clients in Windows-only deployments couldn't retrieve allocations from Nomad server
- RPC calls failed with "Permission denied" error
- Caused by missing `client.servers` configuration block
- Without explicit server addresses, Windows clients relied solely on Consul service discovery
- RPC authentication never properly initialized in Windows-only deployments
**Solution**: Added `servers` configuration block with AWS cloud auto-join
```hcl
client {
  enabled = true
  node_class = NODE_CLASS
  servers = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
  options {
    "driver.raw_exec.enable"    = "1"
    "docker.privileged.enabled" = "true"
  }
}
```
**Status**: ✅ Fixed (Build 19)
**Documentation**: `BUG_17_ROOT_CAUSE_AND_FIX.md`, `BUILD_18_BUG_17_CONFIRMED.md`

#### Bug #18: Docker Service Not Starting Automatically
**File**: `../shared/packer/scripts/setup.sh` (Linux) and `../shared/packer/scripts/setup.ps1` (Windows)
**Issue**: Docker service not configured to start automatically on boot
- Service installed but not enabled
- Required manual start after instance launch
- Affected both Linux and Windows clients
**Solution**: Added service enable commands to setup scripts
- Linux: `sudo systemctl enable docker`
- Windows: `Set-Service -Name docker -StartupType Automatic`
**Status**: ✅ Fixed (Build 20)
**Documentation**: `TESTING_PLAN.md` (Build 20 section)

### Current Infrastructure State 🏗️
- **Last Deployment**: Build 26 (deployed and destroyed 2025-12-20)
- **Status**: ✅ All infrastructure destroyed, project complete
- **Final AMIs Built**:
  - Linux AMI: ami-011970e925a2b116c (Ubuntu 24.04, Nomad 1.11.1, Consul 1.22.2)
  - Windows AMI: ami-011ced41a61b72075 (Windows Server 2022, Nomad 1.11.1, Consul 1.22.2)

### Project Completion Status ✅

**All Testing Complete**:
- ✅ Test 1: Windows client joins cluster
- ✅ Test 2: Node attributes verified
- ✅ Test 3: Infrastructure jobs running (grafana, prometheus, webapp)
- ✅ Test 4: Windows batch job deployed successfully
- ✅ Test 5: Mixed OS deployment validated (Linux + Windows clients)
- ✅ Test 6: Dual AMI cleanup verified (both AMIs destroyed)
- ✅ Bug #17 fix validated (Windows-only RPC communication)
- ✅ Bug #18 fix validated (Docker auto-start)

**Final Architecture Decision**:
- **Mixed OS Deployment Model** chosen as primary use case
- Supports both Linux and Windows clients simultaneously
- Infrastructure jobs run on Linux clients (Docker Linux containers)
- Windows clients available for Windows-specific workloads
- Windows-only deployment possible with Bug #17 fix (requires infrastructure job modifications)

**Documentation Complete**:
- ✅ `TASK_REQUIREMENTS.md` - Updated with all 18 bugs and complete history
- ✅ `TESTING_PLAN.md` - Complete testing procedures and build history
- ✅ `IMPLEMENTATION_SUMMARY.md` - Architecture and implementation details
- ✅ `BUG_17_ROOT_CAUSE_AND_FIX.md` - Critical RPC bug analysis
- ✅ `BUILD_26_STATUS.md` - Final deployment documentation
- ✅ All bug fix documentation (16 individual bug analysis files)

## Key Files Reference

### Configuration
- `terraform/control/terraform.tfvars` - Current: Windows-only (0 Linux, 1 Windows)
- `packer/windows-2022.pkrvars.hcl` - Windows AMI build configuration

### Scripts
- `quick-test.sh` - Multi-OS testing (use `./quick-test.sh windows`)
- `verify-deployment.sh` - Post-deployment verification
- `../shared/packer/scripts/client.ps1` - Windows client configuration script

### Documentation
- `TESTING_PLAN.md` - Comprehensive testing procedures
- `BUG_FIX_POWERSHELL_STRING_TERMINATOR.md` - Latest bug fix
- `PACKER_FILE_PROVISIONER_ANALYSIS.md` - Config files fix
- `BUG_FIX_EC2LAUNCH_V2.md` - EC2Launch v2 state management

## Lessons Learned 🎓

### PowerShell Gotchas
1. **Escape Sequences in Double-Quoted Strings**:
   - Backslashes before certain characters (`\c`, `\l`, `\N`, etc.) are interpreted as escape sequences
   - Use single quotes for literal strings with backslashes
   - Example: `'C:\HashiCorp\Consul\logs'` instead of `"C:\HashiCorp\Consul\logs"`

2. **Variable Expansion with Backslashes**:
   - Variables containing paths with backslashes can cause escape sequence issues in double-quoted strings
   - Use subexpression syntax: `"Text: $($variable)"` instead of `"Text: $variable"`
   - Example: `"Config: $($LogFile)"` where `$LogFile = "C:\ProgramData\client-config.log"`

3. **Service Configuration**:
   - Service definitions must match actual file paths exactly
   - Nomad service expected config at `C:\HashiCorp\Nomad\config\nomad.hcl`
   - Services can depend on other services: `depend= Consul`

4. **UTF-8 Encoding**:
   - NEVER use `Out-File -Encoding UTF8` for HCL configuration files
   - ALWAYS use `[System.IO.File]::WriteAllText()` with UTF8Encoding($false)
   - UTF-8 BOM (bytes: EF BB BF) causes HCL parser to fail with "illegal char" error

5. **Case-Sensitive String Operations**:
   - PowerShell's `-replace` operator is case-INSENSITIVE by default
   - Use `-creplace` for case-sensitive replacements
   - Use `-ireplace` for explicit case-insensitive replacements
   - Example: `$config -creplace 'RETRY_JOIN', $value` to avoid matching `retry_join`

6. **Path Replacement Trailing Characters**:
   - When replacing directory paths, preserve trailing slashes
   - `log_file` with trailing slash = directory for log files
   - `log_file` without trailing slash = attempt to open as file (will fail if it's a directory)
   - Example: `-replace '/opt/consul/logs/', 'C:/HashiCorp/Consul/logs/'` (both have trailing slash)
   - ALWAYS verify source and target have matching trailing characters

7. **Nomad Client Configuration**:
   - ALWAYS include `client.servers` configuration block
   - Use AWS cloud auto-join: `servers = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]`
   - Without explicit servers, Windows clients rely on Consul discovery which fails RPC authentication
   - This is critical for Windows-only deployments (Bug #17)

8. **Service Auto-Start**:
   - ALWAYS enable services to start automatically on boot
   - Linux: `sudo systemctl enable <service>`
   - Windows: `Set-Service -Name <service> -StartupType Automatic`
   - Without this, services require manual start after instance launch (Bug #18)

9. **EC2Launch v2 Behavior**:
   - EC2Launch v2 automatically executes user-data - no configuration needed
   - Do NOT add executeScript task to agent-config.yml
   - The `<userdata>` placeholder is NOT valid - it's treated as literal PowerShell code
   - Keep agent-config.yml minimal with only essential tasks

10. **Error Detection**:
   - Check EC2Launch v2 logs: `C:\ProgramData\Amazon\EC2Launch\log\agent.log`
   - Check error output: `C:\Windows\system32\config\systemprofile\AppData\Local\Temp\EC2Launch*\err.tmp`
   - Use SSM Session Manager for real-time debugging
   - Check Windows Event Viewer for service crashes

### Packer on Windows
1. **File Provisioner**: Explicitly copy each directory separately
2. **Verification**: Always add verification provisioners after file operations
3. **Path Separators**: Use forward slashes in Packer, backslashes in PowerShell

### Mandatory Pre-Build Due Diligence Process

**CRITICAL**: Before EVERY build deployment, you MUST complete the 5-phase verification process:

1. **Run the pre-build checklist script**:
   ```bash
   ./pre-build-checklist.sh <BUILD_NUMBER>
   ```

2. **Complete ALL phases** in the generated checklist:
   - Phase 1: Template Analysis (read all config templates)
   - Phase 2: Transformation Analysis (verify all string replacements)
   - Phase 3: Semantic Verification (understand parameter requirements)
   - Phase 4: Cross-Reference Check (compare with working examples)
   - Phase 5: Simulation (mentally execute transformations)

3. **Sign off** on the checklist with >95% confidence

4. **Only then** proceed with `terraform apply`

**Files**:
- `pre-build-checklist.sh` - Generates mandatory checklist
- `DUE_DILIGENCE_BUG_16_ANALYSIS.md` - Detailed process explanation
- `BUILD_15_PRE_DEPLOYMENT_DUE_DILIGENCE.md` - Example completed checklist

**Why This Matters**: Bug #16 was missed because due diligence was incomplete. This process ensures:
- ALL path replacements are verified
- Trailing slashes are preserved where needed
- Semantic correctness is confirmed
- No syntax errors slip through

### Testing Strategy
1. **AMI Baking**: Scripts are baked into AMI - fixes require rebuild
2. **User-Data Execution**: Takes 2-3 minutes after instance launch
3. **Console Output**: May be delayed or incomplete - use SSM for real-time debugging
4. **Bob-Instructions**: Always use `logcmd` wrapper and `source ~/.zshrc`

## Success Criteria ✓
- ✅ Windows clients successfully join Nomad cluster
- ✅ Windows node attributes correctly identified
- ✅ Windows-targeted jobs deploy successfully
- ✅ Mixed OS deployment validated (Linux + Windows clients)
- ✅ Dual AMI cleanup works on destroy
- ✅ Bug #17 fixed (Windows-only RPC communication)
- ✅ Bug #18 fixed (Docker auto-start)
- ✅ Documentation complete and accurate
- ✅ All 18 bugs documented and fixed

## Timeline
- **Start**: 2025-12-16 (early morning PST)
- **Build 1-7**: 2025-12-16 - Initial Windows implementation and config fixes
- **Build 8**: 2025-12-17 ~14:00 PST - UTF-8 BOM bug discovered
- **Build 9-14**: 2025-12-17 - Various configuration bug fixes
- **Build 15**: 2025-12-17 22:56 PST - First successful Windows deployment (mixed OS)
- **Build 16**: 2025-12-18 - Bug #17 discovered (Windows-only RPC failure)
- **Build 17**: 2025-12-18 - Reverted to mixed OS to continue testing
- **Build 18**: 2025-12-18 - Bug #17 reproduced and confirmed
- **Build 19**: 2025-12-18 - Bug #17 fix deployed
- **Build 20**: 2025-12-19 - Bug #18 fix deployed (Docker auto-start)
- **Build 21-25**: 2025-12-19 - Version management and environment variable fixes
- **Build 26**: 2025-12-20 02:00 PST - Final deployment with all fixes
- **Build 26 Destroyed**: 2025-12-20 06:48 PST - Infrastructure cleanup complete
- **Project Complete**: 2025-12-20 06:55 PST

## Build History Summary

### Phase 1: Initial Implementation (Builds 1-7)
- Fixed config files, paths, escape sequences, EC2Launch v2
- Established Windows AMI build process
- Created dual AMI architecture

### Phase 2: Configuration Bugs (Builds 8-15)
- **Build 8**: ❌ UTF-8 BOM in HCL files (Bug #8)
- **Build 9**: ❌ Case-insensitive string replace (Bug #10)
- **Build 10-14**: ❌ Various configuration issues (Bugs #11-15)
- **Build 15**: ✅ First successful mixed OS deployment (Bugs #1-16 fixed)

### Phase 3: Windows-Only Testing (Builds 16-19)
- **Build 16**: ❌ Bug #17 discovered (Windows-only RPC failure)
- **Build 17**: ✅ Reverted to mixed OS for continued testing
- **Build 18**: ✅ Bug #17 reproduced and root cause identified
- **Build 19**: ✅ Bug #17 fix deployed and validated

### Phase 4: Service Auto-Start (Build 20)
- **Build 20**: ✅ Bug #18 fixed (Docker auto-start)
- All services now start automatically on boot

### Phase 5: Version Management (Builds 21-25)
- **Build 21**: ❌ Version mismatch (1.11.1 vs 1.10.5)
- **Build 22**: ❌ Missing Windows user-data template
- **Build 23**: ❌ Missing CNIVERSION environment variable
- **Build 24**: ❌ Windows SCP path error with environment_vars
- **Build 25**: ⚠️ Partial success (wrong versions, missing Linux client)

### Phase 6: Final Validation (Build 26)
- **Build 26**: ✅ Complete success with all fixes
  - Correct versions (Nomad 1.11.1, Consul 1.22.2)
  - Mixed OS deployment (1 Linux + 1 Windows client)
  - All infrastructure jobs running
  - Deployed and destroyed successfully

## Project Status
**✅ COMPLETE (100%)** - All objectives achieved, all bugs fixed, infrastructure validated and destroyed.

**Achievements**:
- ✅ 18 critical bugs identified and fixed
- ✅ Dual AMI build system operational (Linux + Windows)
- ✅ Mixed OS deployment model validated
- ✅ Windows-only deployment possible (with Bug #17 fix)
- ✅ Comprehensive documentation created
- ✅ All testing scenarios completed
- ✅ Infrastructure cleanup verified

**Key Documentation**:
- [`TASK_REQUIREMENTS.md`](TASK_REQUIREMENTS.md:1) - This file (master status document)
- [`TESTING_PLAN.md`](TESTING_PLAN.md:1) - Complete testing procedures and build history
- [`IMPLEMENTATION_SUMMARY.md`](IMPLEMENTATION_SUMMARY.md:1) - Architecture and implementation
- [`BUG_17_ROOT_CAUSE_AND_FIX.md`](BUG_17_ROOT_CAUSE_AND_FIX.md:1) - Critical RPC bug analysis
- [`BUILD_26_STATUS.md`](BUILD_26_STATUS.md:1) - Final deployment documentation
- [`DUE_DILIGENCE_BUG_16_ANALYSIS.md`](DUE_DILIGENCE_BUG_16_ANALYSIS.md:1) - Pre-build verification process

## Next Session Startup
To continue work on this project in a new session, review:
1. This file (`TASK_REQUIREMENTS.md`) for complete project context
2. `TESTING_PLAN.md` for testing procedures and build history
3. `IMPLEMENTATION_SUMMARY.md` for architecture details
4. Individual bug documentation files for specific issue details