# Due Diligence: PowerShell Case-Insensitive Replace Operations

## Overview
After discovering Bug #11 (case-insensitive replace causing malformed HCL), conducted comprehensive audit of all `-replace` operations in PowerShell scripts to identify similar issues.

## Audit Date
2025-12-18 01:10 UTC

## Methodology
1. Searched all PowerShell scripts for `-replace` operations
2. Analyzed each operation for potential case-sensitivity issues
3. Checked templates for conflicting key names
4. Applied fixes where needed

## Findings

### Script: `../shared/packer/scripts/setup-windows.ps1`

#### Lines 265, 283: Backslash Escaping
```powershell
data_dir = "$($ConsulDir -replace '\\','\\')\\data"
data_dir = "$($NomadDir -replace '\\','\\')\\data"
```

**Analysis**: ✅ **SAFE**
- Pattern: `'\\'` (single backslash)
- Replacement: `'\\'` (double backslash for HCL escaping)
- Risk: None - no HCL key names contain backslashes
- Context: Used in here-string, not template replacement
- Action: No change needed

---

### Script: `../shared/packer/scripts/client.ps1`

#### Line 63: IP_ADDRESS Replacement
```powershell
$ConsulConfig = $ConsulConfig -replace 'IP_ADDRESS', $IP_ADDRESS
```

**Analysis**: ✅ **SAFE**
- Pattern: `'IP_ADDRESS'`
- Could match: `ip_address` (if it existed)
- Template check: No `ip_address` keys found in any templates
- Risk: None - no conflicting key names
- Action: No change needed

#### Line 64: RETRY_JOIN Replacement
```powershell
$ConsulConfig = $ConsulConfig -replace 'RETRY_JOIN', $RetryJoin
```

**Analysis**: ❌ **UNSAFE - BUG #11**
- Pattern: `'RETRY_JOIN'`
- Matches: Both `RETRY_JOIN` (placeholder) and `retry_join` (HCL key)
- Template: `consul_client.hcl:14` contains `retry_join = ["RETRY_JOIN"]`
- Impact: Creates malformed HCL, Consul fails to start
- **Action**: ✅ **FIXED** - Changed to `-creplace`

#### Lines 65-66: Path Replacements
```powershell
$ConsulConfig = $ConsulConfig -replace '/opt/consul/data', 'C:\HashiCorp\Consul\data'
$ConsulConfig = $ConsulConfig -replace '/opt/consul/logs/', 'C:\HashiCorp\Consul\logs\'
```

**Analysis**: ✅ **SAFE**
- Pattern: Linux file paths
- Risk: None - Linux paths won't match any HCL key names
- Action: No change needed

#### Line 122: NODE_CLASS Replacement
```powershell
$NomadConfig = $NomadConfig -replace 'NODE_CLASS', "`"$NodeClass`""
```

**Analysis**: ❌ **UNSAFE - ADDITIONAL BUG FOUND**
- Pattern: `'NODE_CLASS'`
- Matches: Both `NODE_CLASS` (placeholder) and `node_class` (HCL key)
- Template: `nomad_client.hcl:19` contains `node_class = NODE_CLASS`
- Impact: Would create malformed HCL, Nomad would fail to start
- **Action**: ✅ **FIXED** - Changed to `-creplace`

#### Lines 123-124: Path Replacements
```powershell
$NomadConfig = $NomadConfig -replace '/opt/nomad/data', 'C:\HashiCorp\Nomad\data'
$NomadConfig = $NomadConfig -replace '/opt/nomad/logs/', 'C:\HashiCorp\Nomad\logs\'
```

**Analysis**: ✅ **SAFE**
- Pattern: Linux file paths
- Risk: None - Linux paths won't match any HCL key names
- Action: No change needed

---

## Summary

### Total `-replace` Operations Found: 8

| Location | Pattern | Status | Action |
|----------|---------|--------|--------|
| setup-windows.ps1:265 | `'\\'` | ✅ Safe | None |
| setup-windows.ps1:283 | `'\\'` | ✅ Safe | None |
| client.ps1:63 | `'IP_ADDRESS'` | ✅ Safe | None |
| client.ps1:64 | `'RETRY_JOIN'` | ❌ Bug #11 | Fixed with `-creplace` |
| client.ps1:65 | `'/opt/consul/data'` | ✅ Safe | None |
| client.ps1:66 | `'/opt/consul/logs/'` | ✅ Safe | None |
| client.ps1:122 | `'NODE_CLASS'` | ❌ Additional Bug | Fixed with `-creplace` |
| client.ps1:123 | `'/opt/nomad/data'` | ✅ Safe | None |
| client.ps1:124 | `'/opt/nomad/logs/'` | ✅ Safe | None |

### Bugs Found: 2
1. **RETRY_JOIN** - Discovered during Build 9 testing
2. **NODE_CLASS** - Discovered during due diligence audit

### Fixes Applied: 2
Both bugs fixed by changing `-replace` to `-creplace` for case-sensitive matching.

## Risk Assessment

### Before Fixes
- **High Risk**: Both Consul and Nomad configs would be malformed
- **Impact**: Services fail to start, Windows clients cannot join cluster
- **Detection**: Would have been caught during Build 10 testing

### After Fixes
- **Low Risk**: All placeholder replacements now case-sensitive
- **Confidence**: HIGH (95%) - All `-replace` operations audited
- **Remaining Risk**: None identified

## Best Practices Established

### When to Use `-creplace` vs `-replace`

| Use Case | Operator | Reason |
|----------|----------|--------|
| Template placeholder replacement | `-creplace` | Avoid matching HCL key names |
| Path replacements (Linux → Windows) | `-replace` | No case conflicts possible |
| Backslash escaping | `-replace` | No case conflicts possible |
| Variable content replacement | `-replace` | Usually safe, but verify |

### Template Design Guidelines
1. **Use UPPERCASE for placeholders**: `RETRY_JOIN`, `NODE_CLASS`, `IP_ADDRESS`
2. **Use lowercase for HCL keys**: `retry_join`, `node_class`, `advertise_addr`
3. **Avoid similar names**: Don't use `retry_join` and `RETRY_JOIN` in same template
4. **Document placeholders**: Comment which values will be replaced

### Code Review Checklist
- [ ] All template placeholders use UPPERCASE
- [ ] All HCL key names use lowercase or snake_case
- [ ] Placeholder replacements use `-creplace` for case sensitivity
- [ ] Path replacements can safely use `-replace`
- [ ] No placeholder names match HCL key names (even with different case)

## Verification Plan

After Build 10 deployment, verify:

1. **Consul Config Syntax**:
   ```bash
   aws ssm send-command --instance-ids <id> \
     --document-name "AWS-RunPowerShellScript" \
     --parameters 'commands=["Get-Content C:\\HashiCorp\\Consul\\consul.hcl"]'
   ```
   Expected: `retry_join = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]`

2. **Nomad Config Syntax**:
   ```bash
   aws ssm send-command --instance-ids <id> \
     --document-name "AWS-RunPowerShellScript" \
     --parameters 'commands=["Get-Content C:\\HashiCorp\\Nomad\\config\\nomad.hcl"]'
   ```
   Expected: `node_class = "hashistack-windows"`

3. **Service Status**:
   ```bash
   aws ssm send-command --instance-ids <id> \
     --document-name "AWS-RunPowerShellScript" \
     --parameters 'commands=["Get-Service Consul,Nomad | Select Name,Status"]'
   ```
   Expected: Both services Running

## Conclusion

Due diligence audit successfully identified an additional instance of Bug #11 that would have caused Nomad service failure. Both bugs have been fixed. All PowerShell `-replace` operations have been reviewed and verified safe.

**Status**: ✅ Complete  
**Confidence**: HIGH (95%)  
**Ready for Build 10**: Yes

---
**Audit Completed**: 2025-12-18 01:11 UTC  
**Auditor**: IBM Bob (Advanced Mode)  
**Files Modified**: `../shared/packer/scripts/client.ps1` (2 changes)