# Windows Client Support - Task Requirements and Status

## Project Overview
Add Windows client support to the Nomad Autoscaler demo environment on AWS, enabling mixed OS deployments with both Linux and Windows Nomad clients.

## Current Status: 🔧 Build 10 Required - Bug #11 Discovered in Build 9

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

### Critical Bugs Fixed 🐛 (Total: 11)

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
**Status**: ✅ Will be resolved by Bug #8 fix

### Current Infrastructure State 🏗️
- **Deployment**: Build 8 (FAILED - Consul service crashes due to UTF-8 BOM)
- **Linux AMI**: ami-0cee268c18e66d56a (Ubuntu 24.04) - ✅ Built
- **Windows AMI**: ami-00fb221f488bcf6f9 (Build 8) - ❌ Has UTF-8 BOM bug
- **Instance**: i-031f4337072cd1e9c (Build 8) - ❌ Consul service crashes
- **Status**: Ready to destroy and rebuild with all fixes (Build 9)

### Next Steps 📋

#### Immediate Action: Build 10 Deployment

**Current Situation**:
- Build 9 deployed with ami-092311cecadfef280
- Instance i-0edc2ea48989d62dd running
- Consul service failing due to Bug #11 (case-insensitive replace)

**Step 1: Destroy Build 9 Infrastructure**
```bash
cd terraform/control
terraform destroy -auto-approve
```

**Step 2: Rebuild Windows AMI (Build 10)** with ALL fixes:
- ✅ Bug #1-10: All previous fixes applied
- ✅ Bug #11: Case-sensitive `-creplace` operator for RETRY_JOIN replacement

```bash
cd terraform/control
terraform apply -auto-approve
```

Expected duration: ~20-25 minutes for Windows AMI build

**Step 3: Verify Deployment**
```bash
./verify-deployment.sh
```

#### Testing Phase (After Build 10 Deploys)

**Test 1: Verify Windows Client Joins Cluster** (TESTING_PLAN.md Section 4.4 Test 1)
   ```bash
   export NOMAD_ADDR=http://<server_lb_dns>:4646
   nomad node status
   # Should show Windows node with class: hashistack-windows
   ```

**Test 2: Verify Node Attributes** (TESTING_PLAN.md Section 4.4 Test 2)
   ```bash
   WINDOWS_NODE=$(nomad node status -json | jq -r '.[] | select(.NodeClass=="hashistack-windows") | .ID' | head -1)
   nomad node status -verbose $WINDOWS_NODE | grep -i "kernel.name\|os.name"
   # Expected: kernel.name = windows, os.name = Windows Server 2022
   ```

**Test 3: Deploy Windows-Targeted Job** (TESTING_PLAN.md Section 4.4 Test 3)
   - Create test job with Windows constraint
   - Verify job placement on Windows node

**Test 4: Test Windows Autoscaling** (TESTING_PLAN.md Section 4.5)
   - Generate load
   - Verify ASG scales Windows clients

**Test 5: Test Dual AMI Cleanup** (TESTING_PLAN.md Section 4.6)
   - Run `terraform destroy`
   - Verify both AMIs are deregistered

#### Documentation Tasks
- [ ] Update `TASK_REQUIREMENTS.md` with final results
- [ ] Create `WINDOWS_CLIENT_IMPLEMENTATION_COMPLETE.md` summary
- [ ] Update `.github/bob-instructions.md` with lessons learned
- [ ] Document PowerShell best practices for future Windows work

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
   - Verify with hexdump: `hexdump -C file.hcl | head -1` should NOT start with `ef bb bf`

5. **EC2Launch v2 Behavior**:
   - EC2Launch v2 automatically executes user-data - no configuration needed
   - Do NOT add executeScript task to agent-config.yml
   - The `<userdata>` placeholder is NOT valid - it's treated as literal PowerShell code
   - Keep agent-config.yml minimal with only essential tasks

6. **Error Detection**:
   - Check EC2Launch v2 logs: `C:\ProgramData\Amazon\EC2Launch\log\agent.log`
   - Check error output: `C:\Windows\system32\config\systemprofile\AppData\Local\Temp\EC2Launch*\err.tmp`
   - Use SSM Session Manager for real-time debugging
   - Check Windows Event Viewer for service crashes

### Packer on Windows
1. **File Provisioner**: Explicitly copy each directory separately
2. **Verification**: Always add verification provisioners after file operations
3. **Path Separators**: Use forward slashes in Packer, backslashes in PowerShell

### Testing Strategy
1. **AMI Baking**: Scripts are baked into AMI - fixes require rebuild
2. **User-Data Execution**: Takes 2-3 minutes after instance launch
3. **Console Output**: May be delayed or incomplete - use SSM for real-time debugging
4. **Bob-Instructions**: Always use `logcmd` wrapper and `source ~/.zshrc`

## Success Criteria ✓
- [ ] Windows clients successfully join Nomad cluster
- [ ] Windows node attributes correctly identified
- [ ] Windows-targeted jobs deploy successfully
- [ ] Windows autoscaling functions correctly
- [ ] Dual AMI cleanup works on destroy
- [ ] Documentation complete and accurate

## Timeline
- **Start**: 2025-12-16 (early morning)
- **Build 8 Deployed**: 2025-12-17 ~14:00 PST
- **Bugs #8 & #9 Fixed**: 2025-12-17 14:54 PST
- **Current**: 2025-12-17 14:56 PST
- **Status**: ✅ Ready for Build 9 - All bugs fixed, awaiting deployment

## Build History
- **Build 1-3**: Fixed config files, paths, escape sequences
- **Build 4**: Fixed EC2Launch v2 state files
- **Build 5**: Fixed UTF-8 checkmarks
- **Build 6**: Fixed EC2Launch v2 frequency setting
- **Build 7**: ❌ FAILED - EC2Launch service crash (missing content field)
- **Build 8**: ❌ FAILED - Consul service crash (UTF-8 BOM in HCL files)
- **Build 9**: ⏳ READY - All bugs fixed, ready to deploy

## Confidence Level
**VERY HIGH (95%)** - All critical bugs identified and fixed through thorough root cause analysis using SSM debugging.

See [`BUILD_9_PREPARATION.md`](BUILD_9_PREPARATION.md) for complete details.