# Bob-Specific Instructions

## ⚠️ MANDATORY COMMAND EXECUTION RULES ⚠️

### Rule #1: ALWAYS Source .zshrc First
**EVERY command MUST start with:**
```bash
source ~/.zshrc 2>/dev/null && <command>
```

### Rule #2: ALWAYS Use logcmd Wrapper
**EVERY command (except shell built-ins) MUST use logcmd:**
```bash
source ~/.zshrc 2>/dev/null && logcmd <command>
```

**This includes:**
- AWS CLI commands
- Terraform commands
- Custom scripts (bash, python, etc.)
- Any executable command

**The ONLY exception is packer builds - see Rule #3**

### Rule #3: ALWAYS Use run-with-timestamps.sh for Packer Builds
**ONLY packer build commands use run-with-timestamps.sh instead of logcmd:**
```bash
source ~/.zshrc 2>/dev/null && cd packer && ./run-with-timestamps.sh packer build <options> .
```

**For all other commands (including packer validate, packer fmt, etc.), use logcmd:**
```bash
source ~/.zshrc 2>/dev/null && logcmd packer validate .
source ~/.zshrc 2>/dev/null && logcmd packer fmt .
```

## Command Execution Requirements

### Standard Command Format

**✅ CORRECT - ALWAYS USE THIS:**
```bash
source ~/.zshrc 2>/dev/null && logcmd packer validate .
source ~/.zshrc 2>/dev/null && logcmd terraform init
source ~/.zshrc 2>/dev/null && logcmd aws sts get-caller-identity
source ~/.zshrc 2>/dev/null && logcmd bash create-os-configs.sh
source ~/.zshrc 2>/dev/null && logcmd ./test-ami-build7.sh
source ~/.zshrc 2>/dev/null && logcmd python verify-setup.py
```

**❌ INCORRECT - NEVER USE THIS:**
```bash
packer validate .
terraform init
aws sts get-caller-identity
logcmd packer validate .  # Missing source ~/.zshrc
```

### Packer Build Command Format

**✅ CORRECT - Use run-with-timestamps.sh for packer build ONLY:**
```bash
source ~/.zshrc 2>/dev/null && cd packer && ./run-with-timestamps.sh packer build -only=windows.amazon-ebs.hashistack .
```

**✅ CORRECT - Use logcmd for all other packer commands:**
```bash
source ~/.zshrc 2>/dev/null && logcmd packer validate .
source ~/.zshrc 2>/dev/null && logcmd packer fmt .
source ~/.zshrc 2>/dev/null && logcmd packer init .
```

**❌ INCORRECT - NEVER USE THIS:**
```bash
packer build -only=windows.amazon-ebs.hashistack .
logcmd packer build -only=windows.amazon-ebs.hashistack .  # Use run-with-timestamps.sh instead
cd packer && packer build .  # Missing source and run-with-timestamps.sh
./test-ami-build7.sh  # Missing source and logcmd
```

### Why These Rules Matter

1. **Full Visibility**: User can see all command output in real-time in the terminal
2. **Audit Trail**: All commands and their output are logged with timestamps
3. **Debugging**: Historical logs help troubleshoot issues that occurred during execution
4. **Compliance**: Maintains complete record of all operations performed
5. **Timestamps**: Critical for tracking build progress and identifying issues

### Complete Examples

#### Packer Commands

**CRITICAL**: OS-specific builds MUST include the appropriate `-var-file` to set the OS variable correctly!

```bash
# Validation
source ~/.zshrc 2>/dev/null && logcmd packer validate .

# Windows Build (MUST include -var-file=windows-2022.pkrvars.hcl)
source ~/.zshrc 2>/dev/null && cd packer && logcmd packer build -only=windows.amazon-ebs.hashistack -var-file=windows-2022.pkrvars.hcl .

# Linux Build - Ubuntu 24.04
source ~/.zshrc 2>/dev/null && cd packer && logcmd packer build -only=linux.amazon-ebs.hashistack -var-file=ubuntu-24.04.pkrvars.hcl .

# Linux Build - RHEL 9.6
source ~/.zshrc 2>/dev/null && cd packer && logcmd packer build -only=linux.amazon-ebs.hashistack -var-file=rhel-9.6.pkrvars.hcl .
```

**Why the var-file is required:**
- The `var.os` variable defaults to "Ubuntu" in [`variables.pkr.hcl`](variables.pkr.hcl:14)
- Without the var-file, Windows builds will try to use SSH instead of WinRM
- This causes errors like: `scp: c:/Windows/Temp: No such file or directory`
- Each OS has its own `.pkrvars.hcl` file that sets the correct OS variable

**Available var files:**
- `windows-2022.pkrvars.hcl` - Sets `os = "Windows"`
- `ubuntu-24.04.pkrvars.hcl` - Sets `os = "Ubuntu"`
- `ubuntu-22.04.pkrvars.hcl` - Sets `os = "Ubuntu"`
- `rhel-9.6.pkrvars.hcl` - Sets `os = "RedHat"`
- `rhel-9.5.pkrvars.hcl` - Sets `os = "RedHat"`
- `rhel-8.10.pkrvars.hcl` - Sets `os = "RedHat"`
```

#### Terraform Commands
```bash
source ~/.zshrc 2>/dev/null && logcmd terraform init
source ~/.zshrc 2>/dev/null && logcmd terraform plan
source ~/.zshrc 2>/dev/null && logcmd terraform apply
source ~/.zshrc 2>/dev/null && logcmd terraform destroy
```

#### AWS Commands
```bash
source ~/.zshrc 2>/dev/null && logcmd aws sts get-caller-identity
source ~/.zshrc 2>/dev/null && logcmd aws ec2 describe-instances
source ~/.zshrc 2>/dev/null && logcmd aws autoscaling describe-auto-scaling-groups
```

#### Script Execution
```bash
source ~/.zshrc 2>/dev/null && logcmd bash create-os-configs.sh
source ~/.zshrc 2>/dev/null && logcmd bash pre-flight-check.sh
source ~/.zshrc 2>/dev/null && logcmd bash verify-deployment.sh
source ~/.zshrc 2>/dev/null && logcmd ./test-ami-build7.sh
source ~/.zshrc 2>/dev/null && logcmd python verify-setup.py
```

### Exceptions (Rare Cases Only)

1. **Shell Built-ins**: Commands like `source` or `eval` that must run in current shell context:
```bash
source env-pkr-var.sh
eval $(doormat aws export --account aws_mikael.sikora_test)
```

2. **Interactive Commands**: Commands that require user input (but still source .zshrc first):
```bash
source ~/.zshrc 2>/dev/null && packer build -on-error=ask .
```

### Why `source ~/.zshrc 2>/dev/null` is Required

- **Loads logcmd function**: Makes the logging wrapper available
- **Loads environment**: Ensures all custom functions and aliases are available
- **Suppresses warnings**: `2>/dev/null` hides Oh My Zsh warnings in non-interactive shells
- **Consistent environment**: Every command runs in the same configured environment

### Checking for `logcmd` Availability

To verify `logcmd` is available:
```bash
source ~/.zshrc 2>/dev/null && type logcmd
```

If it returns "not found", inform the user immediately and request they check their .zshrc configuration.

## Ensuring Bob Always Follows These Instructions

### How to Make Bob Remember

1. **Reference in System Prompt**: These instructions should be referenced in the mode's system prompt
2. **File Location**: Keep this file at `.github/bob-instructions.md` (always checked)
3. **Copilot Instructions**: Reference this file in `.github/copilot-instructions.md`
4. **Task Context**: Include reference to these instructions in task descriptions

### Self-Check Before Every Command

Bob should mentally verify:
- [ ] Did I source ~/.zshrc?
- [ ] Did I use logcmd?
- [ ] For packer builds: Did I use run-with-timestamps.sh?
- [ ] Is the command in the correct working directory?

### Command Template

**Copy this template for every command:**
```bash
source ~/.zshrc 2>/dev/null && logcmd <your-command-here>
```

**For packer builds, use this template:**
```bash
source ~/.zshrc 2>/dev/null && cd packer && ./run-with-timestamps.sh packer build <options> .
```

## Additional Bob Guidelines

### Terminal Management
- Stay in the same terminal session after AWS authentication (per copilot-instructions.md)
- Do not open multiple terminals unnecessarily
- Respect the working directory context
- Always use `source ~/.zshrc 2>/dev/null &&` before commands

### Output Visibility
- All command output is captured and shown in Bob's responses
- User expects to see complete stdout/stderr for every command
- Never suppress or truncate command output
- Timestamps are MANDATORY for packer builds

### Error Handling
- If a command fails, show the complete error output
- Analyze the error and suggest fixes
- Re-run commands after fixes with FULL command format (source + logcmd)
- Never skip the source ~/.zshrc step

### Verbose Mode
- User prefers VERBOSE output for all operations
- Include detailed logging and status information
- Show progress indicators for long-running operations
- Use run-with-timestamps.sh for packer builds to provide timestamped output

## Quick Reference Card

### Every Command Checklist
```
✓ source ~/.zshrc 2>/dev/null &&
✓ logcmd
✓ <command>
```

### Packer Build Checklist
```
✓ source ~/.zshrc 2>/dev/null &&
✓ cd packer &&
✓ ./run-with-timestamps.sh
✓ packer build <options> .
```

### If You Forget
If Bob executes a command without following these rules, the user will remind Bob, and Bob must:
1. Acknowledge the mistake
2. Re-execute the command correctly
3. Reference this file to prevent future mistakes

## Windows Client Support - Lessons Learned (2025-12-16)

### Project Context
Added Windows client support to Nomad Autoscaler demo environment with mixed OS deployment capability (Linux servers + flexible Linux/Windows clients).

### Key Implementation Lessons

#### 1. Module Refactoring Requires Complete Reference Updates
**Lesson**: When renaming Terraform resources, ALL references must be updated across multiple files.

**Example from this project**:
- Renamed `hashistack_image` → `hashistack_image_linux`
- Renamed `nomad_client` → `nomad_client_linux`
- Had to update references in:
  - `terraform/control/outputs.tf`
  - `terraform/modules/aws-hashistack/outputs.tf`
  - `terraform/modules/aws-hashistack/templates.tf`

**Best Practice**: Use `grep -r "old_name" terraform/` to find all references before renaming.

#### 2. Conditional Resource Creation Pattern
**Pattern**: Use `count` for optional resources:
```hcl
resource "aws_autoscaling_group" "nomad_client_windows" {
  count = var.windows_client_count > 0 ? 1 : 0
  # configuration
}
```

**Access**: Always use index when referencing: `aws_autoscaling_group.nomad_client_windows[0]`

#### 3. Dual AMI Strategy
**Implementation**: Separate module instances for each OS type:
```hcl
module "hashistack_image_linux" {
  source = "../modules/aws-nomad-image"
  # Linux configuration
}

module "hashistack_image_windows" {
  count = var.windows_client_count > 0 ? 1 : 0
  source = "../modules/aws-nomad-image"
  # Windows configuration
}
```

**Why**: Clean separation, independent lifecycle, easier maintenance.

#### 4. Resource Naming Convention
**Pattern**: Use OS-specific suffixes for clarity:
- Linux: `nomad_client_linux`, `hashistack-linux`
- Windows: `nomad_client_windows`, `hashistack-windows`

**Tags**: Include OS tag for identification:
```hcl
tags = {
  Name = "${var.stack_name}-client-windows"
  OS   = "Windows"
}
```

#### 5. User Data Template Differences
**Key Differences**:
- Linux: Bash script calling `/ops/scripts/client.sh`
- Windows: PowerShell script calling `C:\ops\scripts\client.ps1`
- Different path separators and service management

#### 6. Terraform Validation Workflow
**Critical Steps**:
```bash
source ~/.zshrc 2>/dev/null && logcmd terraform init
source ~/.zshrc 2>/dev/null && logcmd terraform validate
source ~/.zshrc 2>/dev/null && logcmd terraform plan
```

**Lesson**: Always validate after each significant change to catch reference errors early.

#### 7. Block Device Name Differences
**OS-Specific Device Names**:
- Linux: `/dev/xvdd`
- Windows: `/dev/sda1`

**Lesson**: Don't assume device names are the same across OS types.

#### 8. Backward Compatibility is Critical
**Requirements**:
- Default behavior unchanged (Linux-only)
- Existing terraform.tfvars work without modification
- Windows support is opt-in via `windows_client_count = 0` default

**Validation**: Test with existing configurations to ensure no breaking changes.

#### 9. Documentation Strategy
**Effective Structure**:
1. Architecture document (design decisions)
2. Implementation document (detailed changes)
3. Quick start guide (common use cases)
4. Testing plan (comprehensive scenarios)
5. Validation results (proof of correctness)

**Lesson**: Comprehensive documentation prevents confusion and aids future maintenance.

#### 10. Incremental Testing Approach
**Best Practice**: Test each layer independently:
1. Terraform syntax validation
2. Terraform plan generation
3. Module dependency verification
4. Resource naming validation

**Lesson**: Don't wait until full deployment to discover configuration errors.

### Windows-Specific Packer Commands

**Windows AMI Build**:
```bash
source ~/.zshrc 2>/dev/null && cd packer && logcmd packer build -var-file=windows-2022.pkrvars.hcl .
```

**Critical**: Always include `-var-file=windows-2022.pkrvars.hcl` to set `os = "Windows"` correctly.

### Configuration Examples

**Linux-only (default)**:
```hcl
client_count = 1
windows_client_count = 0
```

**Windows-only clients**:
```hcl
client_count = 0
windows_client_count = 1
```

**Mixed OS**:
```hcl
client_count = 1
windows_client_count = 1
```

### Common Pitfalls

1. **Forgetting to update all module references** after renaming
2. **Accessing conditional resources without checking count**
3. **Using Linux device names for Windows resources**
4. **Not testing backward compatibility**
5. **Incomplete documentation of architectural decisions**

### Files Modified in This Project

1. `terraform/control/variables.tf` - Windows variables
2. `terraform/control/terraform.tfvars` - Active configuration
3. `terraform/control/main.tf` - Dual AMI orchestration
4. `terraform/control/outputs.tf` - Updated module references
5. `terraform/modules/aws-hashistack/asg.tf` - Dual ASG support
6. `terraform/modules/aws-hashistack/outputs.tf` - Windows outputs
7. `terraform/modules/aws-hashistack/templates.tf` - Updated references
8. `terraform/modules/aws-hashistack/variables.tf` - Module variables
9. `terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1` - New template

### Reference Documentation

- [`WINDOWS_CLIENT_ARCHITECTURE.md`](../WINDOWS_CLIENT_ARCHITECTURE.md) - Design decisions
- [`WINDOWS_CLIENT_IMPLEMENTATION.md`](../WINDOWS_CLIENT_IMPLEMENTATION.md) - Implementation details
- [`WINDOWS_CLIENT_QUICK_START.md`](../WINDOWS_CLIENT_QUICK_START.md) - Quick reference
- [`TESTING_PLAN.md`](../TESTING_PLAN.md) - Phase 4 Windows testing
- [`VALIDATION_RESULTS.md`](../VALIDATION_RESULTS.md) - Validation proof

### Updates
- 2025-12-16: Added Windows client support lessons learned