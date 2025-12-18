# BOB COMMAND EXECUTION RULES - MANDATORY

## ⚠️ CRITICAL: EVERY COMMAND MUST FOLLOW THESE RULES ⚠️

### Rule #1: ALWAYS Source .zshrc First
```bash
source ~/.zshrc 2>/dev/null && <command>
```

### Rule #2: ALWAYS Use logcmd Wrapper
```bash
source ~/.zshrc 2>/dev/null && logcmd <command>
```

### Rule #3: Packer Builds Use run-with-timestamps.sh
```bash
source ~/.zshrc 2>/dev/null && cd packer && ./run-with-timestamps.sh packer build <options> .
```

## CORRECT COMMAND EXAMPLES

### Terraform Commands
```bash
source ~/.zshrc 2>/dev/null && logcmd terraform init
source ~/.zshrc 2>/dev/null && logcmd terraform plan
source ~/.zshrc 2>/dev/null && logcmd terraform apply -auto-approve
source ~/.zshrc 2>/dev/null && logcmd terraform destroy -auto-approve
```

### AWS Commands
```bash
source ~/.zshrc 2>/dev/null && logcmd aws sts get-caller-identity
source ~/.zshrc 2>/dev/null && logcmd aws ssm send-command --instance-ids <id> ...
```

### Script Execution
```bash
source ~/.zshrc 2>/dev/null && logcmd bash script.sh
source ~/.zshrc 2>/dev/null && logcmd ./test-script.sh
```

### Packer Commands
```bash
# Validation
source ~/.zshrc 2>/dev/null && logcmd packer validate .

# Windows Build
source ~/.zshrc 2>/dev/null && cd packer && ./run-with-timestamps.sh packer build -only=windows.amazon-ebs.hashistack -var-file=windows-2022.pkrvars.hcl .

# Linux Build
source ~/.zshrc 2>/dev/null && cd packer && ./run-with-timestamps.sh packer build -only=linux.amazon-ebs.hashistack -var-file=ubuntu-24.04.pkrvars.hcl .
```

## WHY THESE RULES MATTER

1. **Full Visibility**: User sees all command output in real-time
2. **Audit Trail**: All commands logged with timestamps
3. **Debugging**: Historical logs help troubleshoot issues
4. **Compliance**: Complete record of all operations

## SELF-CHECK BEFORE EVERY COMMAND

- [ ] Did I source ~/.zshrc?
- [ ] Did I use logcmd?
- [ ] For packer builds: Did I use run-with-timestamps.sh?
- [ ] Is the command in the correct working directory?

## COMMAND TEMPLATE

**Copy this for EVERY command:**
```bash
source ~/.zshrc 2>/dev/null && logcmd <your-command-here>
```

**For packer builds:**
```bash
source ~/.zshrc 2>/dev/null && cd packer && ./run-with-timestamps.sh packer build <options> .
```

## PRE-BUILD VALIDATION CHECKLIST (MANDATORY)

### Rule #4: ALWAYS Validate Before New Builds

Before deploying ANY new build, you MUST complete these validation steps:

#### 1. PowerShell Syntax Validation
```bash
source ~/.zshrc 2>/dev/null && logcmd pwsh -Command "Get-Content <script-path> -Raw | Out-Null; if (\$?) { Write-Host 'PowerShell syntax is valid' } else { Write-Host 'Syntax error found' }"
```

**Example:**
```bash
source ~/.zshrc 2>/dev/null && logcmd pwsh -Command "Get-Content ../shared/packer/scripts/client.ps1 -Raw | Out-Null; if (\$?) { Write-Host 'PowerShell syntax is valid' } else { Write-Host 'Syntax error found' }"
```

#### 2. PowerShell-HCL Compatibility Check

**Critical Patterns to Verify:**

a) **String Replacements with Paths**
- ❌ WRONG: `'C:\path\to\dir\'` (trailing backslash escapes quote in HCL)
- ✅ CORRECT: `'C:\path\to\dir'` (no trailing backslash)

b) **Case-Sensitive Placeholders**
- ❌ WRONG: `-replace 'PLACEHOLDER'` (matches both PLACEHOLDER and placeholder)
- ✅ CORRECT: `-creplace 'PLACEHOLDER'` (case-sensitive, matches only PLACEHOLDER)

c) **Escape Sequences in HCL**
- `\"` = Escaped quote (makes string unterminated)
- `\\` = Escaped backslash (literal backslash)
- `/` = Forward slash (safe, no escaping needed)

#### 3. Template-to-Output Validation

**Verify the transformation:**
```bash
# Check template file
cat ../shared/packer/config/consul_client.hcl | grep log_file

# Verify replacement logic in PowerShell
grep -n "log_file" ../shared/packer/scripts/client.ps1

# Expected: Template has "/opt/consul/logs/"
# Expected: Replacement produces "C:\HashiCorp\Consul\logs" (no trailing \)
```

#### 4. Consult Documentation

Before making changes to:
- **PowerShell scripts**: Review PowerShell string operators documentation
- **HCL files**: Review HCL syntax and escape sequences
- **Path replacements**: Verify Windows path conventions

**Key Documentation:**
- PowerShell `-replace` vs `-creplace`: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_comparison_operators
- HCL String Literals: https://developer.hashicorp.com/terraform/language/expressions/strings
- Windows Path Conventions: Avoid trailing backslashes in string literals

### PRE-BUILD VALIDATION TEMPLATE

**Copy this checklist before EVERY build:**

```markdown
## Pre-Build Validation for Build X

- [ ] PowerShell syntax validated (no errors)
- [ ] All path replacements checked (no trailing backslashes)
- [ ] Case-sensitive operators used for placeholders (-creplace)
- [ ] Template files reviewed for compatibility
- [ ] HCL escape sequences verified
- [ ] Documentation consulted for any changes
- [ ] Due diligence audit completed
- [ ] All fixes from previous builds included
```

### LESSONS LEARNED

**From Builds 9-11:**

1. **Bug #11**: PowerShell `-replace` is case-insensitive
   - Always use `-creplace` for placeholder replacements
   - Prevents matching both `RETRY_JOIN` and `retry_join`

2. **Bug #12**: AMI contained Packer build artifacts
   - Always add cleanup provisioner in Packer
   - Remove state, config, and log files before AMI creation

3. **Bug #13**: Trailing backslash escapes HCL quotes
   - Never end Windows paths with `\` in string replacements
   - `'C:\path\dir\'` creates `"C:\path\dir\"` (unterminated!)
   - `'C:\path\dir'` creates `"C:\path\dir"` (correct!)

---
**REMEMBER**: NO EXCEPTIONS! Every command AND every build must follow these rules.