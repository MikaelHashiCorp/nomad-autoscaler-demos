# Bob-Specific Instructions

## Command Execution Requirements

### CRITICAL: Always Use `logcmd` Wrapper (When Available)

**PREFERRED**: Every command that Bob executes SHOULD be prefaced with `logcmd` when the function is available. This is a custom function defined in `.zshrc` that:
- Sends stdout and stderr to the terminal (for real-time visibility)
- Logs all output to a timestamped file (for audit trail and debugging)
- Provides complete command history with timestamps

### Command Format

**Correct:**
```bash
logcmd packer validate -var-file=windows-2022.pkrvars.hcl .
logcmd terraform init
logcmd aws sts get-caller-identity
logcmd bash create-os-configs.sh
```

**Incorrect (DO NOT USE):**
```bash
packer validate -var-file=windows-2022.pkrvars.hcl .
terraform init
aws sts get-caller-identity
```

### Why This Matters

1. **Full Visibility**: User can see all command output in real-time in the terminal
2. **Audit Trail**: All commands and their output are logged with timestamps
3. **Debugging**: Historical logs help troubleshoot issues that occurred during execution
4. **Compliance**: Maintains complete record of all operations performed

### Examples

#### Packer Commands
```bash
logcmd packer init .
logcmd packer validate -var-file=windows-2022.pkrvars.hcl .
logcmd packer build -var-file=windows-2022.pkrvars.hcl .
```

#### Terraform Commands
```bash
logcmd terraform init
logcmd terraform plan
logcmd terraform apply
logcmd terraform destroy
```

#### AWS Commands
```bash
logcmd aws sts get-caller-identity
logcmd aws ec2 describe-instances
logcmd aws autoscaling describe-auto-scaling-groups
```

#### Script Execution
```bash
logcmd bash create-os-configs.sh
logcmd bash pre-flight-check.sh
logcmd bash verify-deployment.sh
```

### Exceptions

1. **Shell Built-ins**: Commands like `source` or `eval` (which must run in the current shell context):
```bash
source env-pkr-var.sh
eval $(doormat aws export --account aws_mikael.sikora_test)
```

2. **Function Not Available**: If `logcmd` is not available in the current shell session (returns "command not found"), Bob should:
   - Note this in the response
   - Execute commands without `logcmd` prefix
   - Still capture and display all stdout/stderr output
   - Recommend user to source their `.zshrc` or switch to a zsh terminal

### Using `logcmd` with Bob

Bob must source `.zshrc` before using `logcmd` in each command:

```bash
source ~/.zshrc 2>/dev/null; logcmd <command>
```

**Examples:**
```bash
source ~/.zshrc 2>/dev/null; logcmd packer validate -var-file=windows-2022.pkrvars.hcl .
source ~/.zshrc 2>/dev/null; logcmd terraform init
source ~/.zshrc 2>/dev/null; logcmd aws sts get-caller-identity
```

The `2>/dev/null` suppresses Oh My Zsh warnings that occur when sourcing in non-interactive shells.

### Checking for `logcmd` Availability

To verify `logcmd` is available:
```bash
source ~/.zshrc 2>/dev/null && type logcmd
```

If it returns "not found", proceed without the prefix but inform the user.

## Additional Bob Guidelines

### Terminal Management
- Stay in the same terminal session after AWS authentication (per copilot-instructions.md)
- Do not open multiple terminals unnecessarily
- Respect the working directory context

### Output Visibility
- All command output is captured and shown in Bob's responses
- User expects to see complete stdout/stderr for every command
- Never suppress or truncate command output

### Error Handling
- If a command fails, show the complete error output
- Analyze the error and suggest fixes
- Re-run commands after fixes with `logcmd` prefix

### Verbose Mode
- User prefers VERBOSE output for all operations
- Include detailed logging and status information
- Show progress indicators for long-running operations