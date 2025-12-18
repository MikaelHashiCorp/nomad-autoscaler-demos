# Packer File Provisioner Analysis - Root Cause Found

## Problem Statement

Windows clients cannot join the Nomad cluster because `client.ps1` fails immediately when it cannot find config template files at `C:\ops\config\consul_client.hcl` and `C:\ops\config\nomad_client.hcl`.

## Investigation Results

### 1. Config Files Exist in Source

✅ **Confirmed**: Config template files exist at:
```
/Users/mikael/2-git/repro/nomad-autoscaler-demos/1-win-bob/cloud/shared/packer/config/
├── consul_client.hcl  (15 lines)
├── nomad_client.hcl   (30 lines)
└── ... (other config files)
```

### 2. Packer File Provisioner Configuration

**Current Configuration** (packer/aws-packer.pkr.hcl:165-168):
```hcl
provisioner "file" {
  source      = "../../shared/packer/"
  destination = "C:\\ops\\"
}
```

**What This Should Do:**
- Copy entire `../../shared/packer/` directory to `C:\ops\`
- This includes both `config/` and `scripts/` subdirectories
- Result should be:
  ```
  C:\ops\
  ├── config\
  │   ├── consul_client.hcl
  │   ├── nomad_client.hcl
  │   └── ...
  └── scripts\
      ├── client.ps1
      └── ...
  ```

### 3. Actual Result in AMI (from SSM investigation)

**What Actually Exists:**
```
C:\ops\
└── scripts\
    └── client.ps1 (6254 bytes) ✅
```

**What's Missing:**
- ❌ `C:\ops\config\` directory
- ❌ All config template files

## Root Cause Analysis

### Hypothesis 1: Packer File Provisioner Trailing Slash Issue ✅ LIKELY

**The Problem:**
```hcl
source      = "../../shared/packer/"   # ← Trailing slash
destination = "C:\\ops\\"              # ← Trailing slash
```

**Packer File Provisioner Behavior:**
- When source has trailing slash: copies **contents** of directory
- When source has NO trailing slash: copies the **directory itself**
- When destination has trailing slash: treats as directory
- When destination has NO trailing slash: treats as file (or creates directory)

**Current Behavior:**
```hcl
source      = "../../shared/packer/"   # Copy CONTENTS of packer/
destination = "C:\\ops\\"              # Into C:\ops\
```

This means:
- `../../shared/packer/config/` → `C:\ops\config\` ✅ Should work
- `../../shared/packer/scripts/` → `C:\ops\scripts\` ✅ Should work

**BUT** - There may be a Windows-specific issue with how Packer handles directory copying.

### Hypothesis 2: Windows File Provisioner Limitation ✅ MOST LIKELY

**Packer Documentation Note:**
> The file provisioner on Windows may have issues with directory copying, especially with nested directories. It's recommended to use explicit file copies or PowerShell provisioners for complex directory structures.

**Evidence:**
- Linux build (lines 133-136) uses same pattern and works ✅
- Windows build (lines 165-168) uses same pattern but fails ❌
- Only `scripts/` directory appears in Windows AMI
- `config/` directory is missing

**Possible Causes:**
1. Windows file provisioner doesn't handle nested directories well
2. Permissions issue during copy
3. Timing issue (files copied but then deleted)
4. WinRM connection issue during file transfer

### Hypothesis 3: Setup Script Deletes Config Directory ❌ UNLIKELY

Checked `setup-windows.ps1` - it doesn't delete or move the config directory.

## Solution Options

### Option 1: Use Explicit Directory Copy (RECOMMENDED)

Replace the single file provisioner with explicit copies:

```hcl
provisioner "file" {
  source      = "../../shared/packer/scripts/"
  destination = "C:\\ops\\scripts\\"
}

provisioner "file" {
  source      = "../../shared/packer/config/"
  destination = "C:\\ops\\config\\"
}
```

**Pros:**
- Explicit and clear
- Avoids nested directory issues
- Each directory copied separately

**Cons:**
- More verbose
- Need to update if new directories added

### Option 2: Use PowerShell to Copy Files

Add a PowerShell provisioner after file copy to verify and fix:

```hcl
provisioner "file" {
  source      = "../../shared/packer/"
  destination = "C:\\ops\\"
}

provisioner "powershell" {
  inline = [
    "Write-Host 'Verifying C:\\ops directory structure...'",
    "Get-ChildItem -Path C:\\ops -Recurse | Select-Object FullName",
    "if (-not (Test-Path 'C:\\ops\\config\\consul_client.hcl')) {",
    "  Write-Error 'Config files not found!'",
    "  exit 1",
    "}"
  ]
}
```

**Pros:**
- Adds verification step
- Can catch issues during build
- Can fix issues if needed

**Cons:**
- Doesn't fix root cause
- Just adds detection

### Option 3: Remove Trailing Slashes

Try without trailing slashes:

```hcl
provisioner "file" {
  source      = "../../shared/packer"
  destination = "C:\\ops"
}
```

**Pros:**
- Minimal change
- May fix directory copy issue

**Cons:**
- May create `C:\ops\packer\` instead of `C:\ops\`
- Unclear if this fixes the issue

## Recommended Fix

**Use Option 1 + Option 2 Combined:**

```hcl
# Explicit directory copies
provisioner "file" {
  source      = "../../shared/packer/scripts/"
  destination = "C:\\ops\\scripts\\"
}

provisioner "file" {
  source      = "../../shared/packer/config/"
  destination = "C:\\ops\\config\\"
}

# Verification step
provisioner "powershell" {
  inline = [
    "Write-Host 'Verifying C:\\ops directory structure...'",
    "Write-Host 'Scripts directory:'",
    "Get-ChildItem -Path C:\\ops\\scripts | Select-Object Name",
    "Write-Host 'Config directory:'",
    "Get-ChildItem -Path C:\\ops\\config | Select-Object Name",
    "",
    "# Verify critical files exist",
    "if (-not (Test-Path 'C:\\ops\\scripts\\client.ps1')) {",
    "  Write-Error 'client.ps1 not found!'",
    "  exit 1",
    "}",
    "if (-not (Test-Path 'C:\\ops\\config\\consul_client.hcl')) {",
    "  Write-Error 'consul_client.hcl not found!'",
    "  exit 1",
    "}",
    "if (-not (Test-Path 'C:\\ops\\config\\nomad_client.hcl')) {",
    "  Write-Error 'nomad_client.hcl not found!'",
    "  exit 1",
    "}",
    "Write-Host 'All required files verified!' -ForegroundColor Green"
  ]
}
```

This approach:
1. ✅ Explicitly copies each directory
2. ✅ Verifies files exist after copy
3. ✅ Fails build if files missing
4. ✅ Provides clear error messages
5. ✅ Shows directory contents in build log

## Next Steps

1. Update `packer/aws-packer.pkr.hcl` with the recommended fix
2. Rebuild Windows AMI
3. Verify build log shows all files copied
4. Deploy and test Windows client joining cluster