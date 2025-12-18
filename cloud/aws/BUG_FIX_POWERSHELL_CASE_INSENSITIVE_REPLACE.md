# Bug Fix: PowerShell Case-Insensitive Replace Operator

## Bug #11: PowerShell `-replace` Operator Case-Insensitivity

### Discovery
**Date**: 2025-12-18 00:50 UTC  
**Build**: Build 9 (ami-092311cecadfef280)  
**Instance**: i-0edc2ea48989d62dd

### Symptom
Consul service fails to start with error:
```
==> failed to parse C:\HashiCorp\Consul\consul.hcl: At 11:45: literal not terminated
```

### Root Cause Analysis

The generated [`consul.hcl`](C:\HashiCorp\Consul\consul.hcl:14) file contains malformed HCL:
```hcl
provider=aws tag_key=ConsulAutoJoin tag_value=auto-join = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
```

**Expected**:
```hcl
retry_join = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
```

#### The Bug

In [`client.ps1:64`](../shared/packer/scripts/client.ps1:64):
```powershell
$ConsulConfig = $ConsulConfig -replace 'RETRY_JOIN', $RetryJoin
```

**PowerShell's `-replace` operator is case-INSENSITIVE by default!**

The template [`consul_client.hcl:14`](../shared/packer/config/consul_client.hcl:14) contains:
```hcl
retry_join = ["RETRY_JOIN"]
```

When the script replaces `'RETRY_JOIN'` with the value `"provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"`, it matches **BOTH**:
1. `RETRY_JOIN` (the placeholder inside quotes) ✓ Intended
2. `retry_join` (the HCL key name) ✗ **BUG!**

This results in:
```hcl
provider=aws tag_key=ConsulAutoJoin tag_value=auto-join = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
```

### The Fix

Use PowerShell's **case-sensitive** `-creplace` operator for all placeholder replacements:

**File**: [`../shared/packer/scripts/client.ps1`](../shared/packer/scripts/client.ps1)

#### Fix 1: Consul RETRY_JOIN (Line 64)
**Before**:
```powershell
$ConsulConfig = $ConsulConfig -replace 'RETRY_JOIN', $RetryJoin
```

**After**:
```powershell
$ConsulConfig = $ConsulConfig -creplace 'RETRY_JOIN', $RetryJoin
```

#### Fix 2: Nomad NODE_CLASS (Line 122)
**Before**:
```powershell
$NomadConfig = $NomadConfig -replace 'NODE_CLASS', "`"$NodeClass`""
```

**After**:
```powershell
$NomadConfig = $NomadConfig -creplace 'NODE_CLASS', "`"$NodeClass`""
```

**Why NODE_CLASS also needs fixing**: The template [`nomad_client.hcl:19`](../shared/packer/config/nomad_client.hcl:19) contains:
```hcl
node_class = NODE_CLASS
```

Without `-creplace`, it would match both `NODE_CLASS` and `node_class`, creating the same malformed HCL issue.

### PowerShell Replace Operators

| Operator | Case Sensitivity | Description |
|----------|-----------------|-------------|
| `-replace` | Case-insensitive | Default operator, matches regardless of case |
| `-creplace` | Case-sensitive | Only matches exact case |
| `-ireplace` | Case-insensitive | Explicit case-insensitive (same as `-replace`) |

### Impact

- **Severity**: Critical - Prevents Consul and potentially Nomad services from starting
- **Scope**: All Windows client deployments
- **Detection**: Services fail to parse configuration files with "literal not terminated" errors
- **Affected Configs**: Both Consul and Nomad configurations

### Testing

After applying the fix, verify:
1. **Consul config** has correct syntax:
   ```hcl
   retry_join = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
   ```
2. **Nomad config** has correct syntax:
   ```hcl
   node_class = "hashistack-windows"
   ```
3. Consul service starts successfully
4. Nomad service starts successfully
5. Windows client joins the cluster

### Related Bugs

- Bug #8: UTF-8 BOM in HCL files (fixed in Build 9)
- Bug #10: Verification script checking for removed executeScript (fixed in Build 9)

### Lessons Learned

1. **PowerShell string operators are case-insensitive by default** - always consider case sensitivity
2. **Use `-creplace` for literal string replacements** when case matters
3. **Template placeholders should not share names with configuration keys** (even with different cases)
4. **Test configuration file generation** before deploying to production

### Due Diligence Completed

Searched all PowerShell scripts for `-replace` operations:
- ✅ `setup-windows.ps1` - Backslash escaping (safe, no HCL key conflicts)
- ✅ `client.ps1` Line 63 - `IP_ADDRESS` (safe, no `ip_address` keys in templates)
- ✅ `client.ps1` Line 64 - `RETRY_JOIN` (FIXED with `-creplace`)
- ✅ `client.ps1` Lines 65-66 - Path replacements (safe, Linux paths)
- ✅ `client.ps1` Line 122 - `NODE_CLASS` (FIXED with `-creplace`)
- ✅ `client.ps1` Lines 123-124 - Path replacements (safe, Linux paths)

### Next Steps

1. Apply both fixes to [`client.ps1`](../shared/packer/scripts/client.ps1) (COMPLETED)
2. Rebuild Windows AMI (Build 10)
3. Deploy and verify Consul/Nomad services start correctly
4. Complete testing plan

---
**Status**: Fix identified, ready to implement  
**Build**: Will be fixed in Build 10