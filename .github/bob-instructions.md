# Bob Instructions - AI Agent Best Practices

## Purpose
This document captures lessons learned and best practices for AI agents (Bob) working on this project, particularly for Windows AMI builds and HashiStack deployments.

## CRITICAL RULE: ALWAYS USE SOURCE + LOGCMD

**🚨 MANDATORY FOR EVERY COMMAND 🚨**

For **EVERY** command you execute (no exceptions):

```bash
source ~/.zshrc && logcmd <command> <args>
```

**Examples**:
```bash
# ✅ CORRECT - Every command uses source + logcmd
source ~/.zshrc && logcmd aws sts get-caller-identity
source ~/.zshrc && logcmd ./validate-build12.sh
source ~/.zshrc && logcmd packer build -only='windows.amazon-ebs.hashistack' -var-file=windows-2022.pkrvars.hcl .

# ❌ WRONG - Missing source and/or logcmd
aws sts get-caller-identity
./validate-build12.sh
packer build ...
```

**Why This Matters**:
1. `source ~/.zshrc` loads the `logcmd` function and AWS credentials
2. `logcmd` provides timestamped logging for all operations
3. Logs are essential for debugging and audit trails
4. This pattern must be used consistently, not selectively

**No Exceptions**: Even simple commands like `aws sts get-caller-identity` must use this pattern.

## Core Principles

### 1. Proactive Error Detection and Resolution
**CRITICAL**: When errors occur, fix them immediately rather than just documenting them.

**Example from Build #12**:
- ❌ **Wrong**: Detect error → Document analysis → Wait for user prompt → Fix
- ✅ **Right**: Detect error → Analyze → Fix immediately → Document fix → Continue

**Lesson**: User feedback: "Please keep an eye on errors so you can fix them sooner, not have to wait for me to prompt you."

### 2. Context Recovery After System Upgrades
When chat history is lost (e.g., version upgrades):
1. Read all relevant documentation files (*.md in project directories)
2. Check recent log files to understand current state
3. Review test scripts to understand workflow
4. Examine configuration files for current settings
5. Create assessment document summarizing findings

### 3. Windows AMI Build Workflow

#### Standard Build Process
```bash
# 1. Source environment
source ~/.zshrc

# 2. Run build with logging
cd cloud/aws/packer
logcmd "packer build -only='windows.amazon-ebs.hashistack' -var-file=windows-2022.pkrvars.hcl aws-packer.pkr.hcl" "$LOG_FILE"

# 3. Extract AMI ID
grep 'ami-' $LOG_FILE | tail -1

# 4. Launch test instance
aws ec2 run-instances --image-id <ami-id> --instance-type t3a.xlarge ...

# 5. Validate services
./validate-running-instance.sh <instance-ip> <key-name>
```

#### Key Requirements
- **Always use `logcmd`** for timestamped output
- **Always use `run-with-timestamps.sh`** when applicable
- **Always validate** AMI by launching instance and checking services
- **Default instance type**: `t3a.xlarge` for Windows workloads
- **Services must auto-start**: Consul, Nomad, Docker, SSH must be running on boot

### 4. Packer Build Best Practices

#### File Organization
Packer auto-loads all `.pkr.hcl` and `.pkrvars.hcl` files in the directory. This can cause conflicts.

**Solution**: Use explicit build targets
```bash
# ✅ Good - Explicit target
packer build -only='windows.amazon-ebs.hashistack' -var-file=windows-2022.pkrvars.hcl aws-packer.pkr.hcl

# ❌ Risky - May auto-load conflicting files
packer build -var-file=windows-2022.pkrvars.hcl aws-packer.pkr.hcl
```

#### Common Packer Errors
1. **JSON parsing error with `#` character**: Packer is trying to parse a shell script
   - Fix: Use `-only` flag to specify exact build target
   - Fix: Ensure no shell scripts have `.pkr.hcl` or `.pkrvars.hcl` extensions

2. **Service fails to start on boot**: Invalid configuration
   - Fix: Use standalone mode configs with `bootstrap_expect = 1`
   - Fix: Ensure server mode is enabled for standalone operation

### 5. Windows Service Configuration

#### Standalone Mode Requirements
Services must be configured to start without external dependencies:

**Consul Standalone Config**:
```hcl
datacenter = "dc1"
data_dir = "C:\\HashiCorp\\Consul\\data"
log_level = "INFO"
server = true                    # Server mode
bootstrap_expect = 1             # Standalone bootstrap
ui_config {
  enabled = true
}
client_addr = "0.0.0.0"         # Listen on all interfaces
bind_addr = "0.0.0.0"           # Bind to all interfaces
advertise_addr = "127.0.0.1"    # Advertise localhost
```

**Nomad Standalone Config**:
```hcl
datacenter = "dc1"
data_dir = "C:\\HashiCorp\\Nomad\\data"
log_level = "INFO"

server {
  enabled = true                 # Server mode
  bootstrap_expect = 1           # Standalone bootstrap
}

client {
  enabled = true                 # Also run as client
}
```

#### Why Standalone Mode?
- Golden images need services that start immediately
- No waiting for cluster formation
- Can be reconfigured for cluster mode later via user-data
- Enables immediate validation after instance launch

### 6. Validation Requirements

#### Service Validation Checklist
When validating a Windows AMI build:
1. ✅ Launch instance from AMI
2. ✅ Wait for instance to be running (2-3 minutes)
3. ✅ Connect via SSH with key authentication
4. ✅ Verify Consul service is running and healthy
5. ✅ Verify Nomad service is running and healthy
6. ✅ Verify Docker service is running and functional
7. ✅ Verify SSH service is running
8. ✅ Check service startup types are "Automatic"
9. ✅ Test service functionality (consul members, nomad node status, docker version)

#### Validation Script Usage
```bash
# Standard validation
./validate-running-instance.sh <instance-ip> <key-name>

# Expected output: ALL CHECKS PASSED
```

### 7. Documentation Standards

#### Build Documentation
Each build should have:
1. **Assessment document** (before build): Expected changes and goals
2. **Test script**: Automated build execution with logging
3. **Results document** (after build): Success/failure, AMI ID, issues found
4. **Validation results**: Service status verification

#### File Naming Convention
- `BUILD_<number>_<description>.md` - Build documentation
- `test-ami-build<number>.sh` - Build execution script
- `logs/<hostname>_packer_<timestamp>.out` - Build logs

### 8. Error Handling Protocol

#### When Build Fails
1. **Stop immediately** - Don't proceed to next steps
2. **Analyze logs** - Identify root cause
3. **Fix the bug** - Modify Packer config or scripts
4. **Document the fix** - Update relevant files
5. **Rebuild** - Run build again with fixes
6. **Validate** - Ensure fix resolved the issue

#### Common Failure Patterns
1. **Service registration but not starting**: Invalid config → Use standalone mode
2. **Packer parsing errors**: File conflicts → Use `-only` flag
3. **Docker not starting**: Needs reboot → Add reboot provisioner
4. **SSH not available**: Key injection issue → Verify userdata script

### 9. Tool Usage

#### Required Tools
- `logcmd`: Shell function for timestamped logging
- `run-with-timestamps.sh`: Packer wrapper with timestamps
- `gdate`: GNU date for precise timestamps (macOS: `brew install coreutils`)
- `ts`: Timestamp utility (macOS: `brew install moreutils`)

#### Environment Setup
```bash
# Always source before running builds
source ~/.zshrc

# Verify logcmd is available
type logcmd

# Check for required tools
command -v gdate
command -v ts
```

### 10. Communication Guidelines

#### Response Style
- ❌ Don't start with: "Great", "Certainly", "Okay", "Sure"
- ✅ Be direct and technical
- ✅ Use clear, actionable language
- ✅ Focus on outcomes, not process

#### Example Responses
```
❌ "Great! I've updated the CSS file for you."
✅ "CSS updated with responsive breakpoints."

❌ "Certainly! I'll help you with that task."
✅ "Analyzing build logs for error patterns."
```

### 11. Project-Specific Context

#### Windows AMI Goals
- Create golden images with HashiStack pre-installed
- Services must auto-start on boot
- Support standalone and cluster modes
- Enable SSH key authentication
- Include Docker for container workloads

#### Key Files
- **Setup Script**: `cloud/shared/packer/scripts/setup-windows.ps1`
- **Packer Template**: `cloud/aws/packer/aws-packer.pkr.hcl`
- **Variables**: `cloud/aws/packer/windows-2022.pkrvars.hcl`
- **Validation**: `cloud/aws/packer/validate-running-instance.sh`

#### Default Settings
- **Instance Type**: t3a.xlarge (Windows workloads)
- **Region**: us-west-2 (or AWS_REGION env var)
- **OS**: Windows Server 2022
- **HashiStack Versions**: Latest from checkpoint API

### 12. AWS Credentials Management

#### Pre-Build Verification
Always verify AWS credentials before starting long-running builds:
```bash
# Check credentials are valid
aws sts get-caller-identity

# Verify region access
aws ec2 describe-regions --region us-west-2
```

#### Common AWS Authentication Errors
1. **RequestExpired**: Credentials have expired
   - Symptom: Build fails during AWS API validation (typically within 60 seconds)
   - Solution: Refresh credentials before retrying
   - Prevention: Check credential expiration before starting builds

2. **InvalidClientTokenId**: Invalid access key
   - Solution: Reconfigure AWS credentials
   
3. **SignatureDoesNotMatch**: Incorrect secret key
   - Solution: Verify and update AWS credentials

#### Credential Refresh Methods
```bash
# AWS SSO
aws sso login --profile <profile-name>

# AWS CLI
aws configure

# Environment Variables
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."  # for temporary credentials

# AWS Vault
aws-vault exec <profile-name> -- <command>
```

#### Build Retry After Auth Failure
When a build fails due to authentication:
1. ✅ Configuration is still valid - no changes needed
2. ✅ Refresh credentials
3. ✅ Verify with `aws sts get-caller-identity`
4. ✅ Re-run the exact same command
5. ❌ Don't modify Packer files - auth errors are not config errors

### 13. Command Execution Best Practices

#### Using run-with-timestamps.sh
When running Packer builds, always use the wrapper script:
```bash
cd cloud/aws/packer
./run-with-timestamps.sh -only='windows.amazon-ebs.hashistack' -var-file=windows-2022.pkrvars.hcl .
```

**Key Points**:
- Use `.` (current directory) as the final argument to let Packer auto-load all `.pkr.hcl` files
- Don't specify individual `.pkr.hcl` files - let Packer auto-load them
- Only specify `.pkrvars.hcl` files explicitly with `-var-file`
- The `-only` flag prevents conflicts from multiple OS configurations

#### Incorrect vs Correct Commands
```bash
# ❌ Wrong - specifies individual .pkr.hcl files
packer build -var-file=windows-2022.pkrvars.hcl aws-packer.pkr.hcl

# ❌ Wrong - missing variables.pkr.hcl
packer build -only='...' -var-file=windows-2022.pkrvars.hcl aws-packer.pkr.hcl

# ✅ Correct - auto-loads all .pkr.hcl files
./run-with-timestamps.sh -only='windows.amazon-ebs.hashistack' -var-file=windows-2022.pkrvars.hcl .
```

## Version History

### 2025-12-15 (Update 2)
- Added AWS credentials management section
- Added command execution best practices
- Documented run-with-timestamps.sh usage
- Added credential verification steps

### 2025-12-15 (Initial)
- Initial creation after Build #12 experience
- Added proactive error handling guidelines
- Documented Packer build best practices
- Added Windows service configuration patterns
- Established validation requirements

## References

- [Copilot Instructions](.github/copilot-instructions.md)
- [Packer Documentation](https://www.packer.io/docs)
- [HashiCorp Consul](https://www.consul.io/docs)
- [HashiCorp Nomad](https://www.nomadproject.io/docs)