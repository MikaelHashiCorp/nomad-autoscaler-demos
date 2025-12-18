# Linux vs Windows Client Configuration Analysis

## Key Differences in Config Handling

### Linux Client Configuration (`client.sh`)

**Directory Structure:**
```bash
SHAREDDIR=/ops/
CONFIGDIR=$SHAREDDIR/config          # /ops/config
CONSULCONFIGDIR=/etc/consul.d
NOMADCONFIGDIR=/etc/nomad.d
```

**Config Template Processing (Lines 44-46):**
```bash
# Reads template from /ops/config/consul_client.hcl
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $CONFIGDIR/consul_client.hcl
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" $CONFIGDIR/consul_client.hcl

# Copies modified template to final location
sudo cp $CONFIGDIR/consul_client.hcl $CONSULCONFIGDIR/consul.hcl
```

**Key Points:**
- ✅ Modifies template IN-PLACE using `sed -i`
- ✅ Then copies modified file to `/etc/consul.d/consul.hcl`
- ✅ Template file at `/ops/config/consul_client.hcl` is PROVIDED by Packer file provisioner

---

### Windows Client Configuration (`client.ps1`)

**Directory Structure:**
```powershell
$SHAREDDIR = "C:\ops"
$CONFIGDIR = "$SHAREDDIR\config"     # C:\ops\config
$CONSULCONFIGDIR = "C:\HashiCorp\Consul"
$NOMADCONFIGDIR = "C:\HashiCorp\Nomad"
```

**Config Template Processing (Lines 56-70):**
```powershell
# Attempts to read template from C:\ops\config\consul_client.hcl
$ConsulConfigTemplate = "$CONFIGDIR\consul_client.hcl"
if (-not (Test-Path $ConsulConfigTemplate)) {
    Write-Error "Consul client config template not found: $ConsulConfigTemplate"
    exit 1  # ❌ SCRIPT EXITS HERE IF FILE NOT FOUND
}

# Reads entire file into memory
$ConsulConfig = Get-Content $ConsulConfigTemplate -Raw

# Performs string replacements in memory
$ConsulConfig = $ConsulConfig -replace 'IP_ADDRESS', $IP_ADDRESS
$ConsulConfig = $ConsulConfig -replace 'RETRY_JOIN', $RetryJoin

# Writes modified content to final location
$ConsulConfig | Out-File -FilePath "$CONSULCONFIGDIR\consul.hcl" -Encoding UTF8 -Force
```

**Key Points:**
- ❌ Reads template into memory (doesn't modify in-place)
- ❌ Performs replacements in memory
- ❌ Writes to final location `C:\HashiCorp\Consul\consul.hcl`
- ❌ **CRITICAL**: Script exits immediately if template not found at `C:\ops\config\consul_client.hcl`

---

## Root Cause Analysis

### The Problem

**Packer File Provisioner** (packer/aws-packer.pkr.hcl:165-168):
```hcl
provisioner "file" {
  source      = "../../shared/packer/"
  destination = "C:\\ops\\"
}
```

This provisioner copies the entire `../../shared/packer/` directory to `C:\ops\`.

**Expected Result:**
```
C:\ops\
├── config\
│   ├── consul_client.hcl  ← NEEDED
│   ├── nomad_client.hcl   ← NEEDED
│   └── ... (other config files)
└── scripts\
    ├── client.ps1
    └── ... (other scripts)
```

**Actual Result (from SSM investigation):**
```
C:\ops\
└── scripts\
    └── client.ps1 (6254 bytes) ✅ EXISTS
```

**Missing:**
- ❌ `C:\ops\config\` directory
- ❌ `C:\ops\config\consul_client.hcl`
- ❌ `C:\ops\config\nomad_client.hcl`

### Why Windows Fails

1. **User-data executes** `C:\ops\scripts\client.ps1` ✅
2. **Script starts** and logs parameters ✅
3. **Script checks** for `C:\ops\config\consul_client.hcl` at line 57 ❌
4. **File not found** - script exits with error at line 59 ❌
5. **No logging** occurs because `Start-Transcript` at line 23 hasn't created the log file yet
6. **Services run** but have no configuration ❌
7. **Node cannot join cluster** ❌

### Why Linux Works

1. **Packer file provisioner** copies `/ops/` directory including `/ops/config/` ✅
2. **User-data executes** `/ops/scripts/client.sh` ✅
3. **Script finds** `/ops/config/consul_client.hcl` ✅
4. **sed modifies** template in-place ✅
5. **Script copies** modified file to `/etc/consul.d/consul.hcl` ✅
6. **Services start** with proper configuration ✅
7. **Node joins cluster** ✅

---

## Solution Options

### Option 1: Fix Packer File Provisioner (RECOMMENDED)

Verify that the file provisioner is actually copying the config directory. The provisioner should work, but we need to verify:

1. Check if `../../shared/packer/config/` exists and contains the template files
2. Verify Packer is copying the entire directory structure
3. Test by checking the AMI after build

### Option 2: Embed Config Templates in Script

Instead of reading from external files, embed the config templates directly in `client.ps1`:

```powershell
$ConsulConfigTemplate = @"
datacenter = "dc1"
data_dir = "C:\HashiCorp\Consul\data"
advertise_addr = "IP_ADDRESS"
client_addr = "0.0.0.0"
retry_join = ["RETRY_JOIN"]
"@
```

**Pros:**
- No dependency on external files
- Self-contained script

**Cons:**
- Harder to maintain
- Duplicates config logic
- Not consistent with Linux approach

### Option 3: Create Config Directory in Packer

Add a provisioner to explicitly create and populate the config directory:

```hcl
provisioner "powershell" {
  inline = [
    "New-Item -ItemType Directory -Force -Path C:\\ops\\config",
    "Copy-Item -Path C:\\ops\\*.hcl -Destination C:\\ops\\config\\ -Force"
  ]
}
```

---

## Recommended Fix

**Use Option 1**: Verify and fix the Packer file provisioner to ensure `config/` directory is copied.

**Next Steps:**
1. Verify `../../shared/packer/config/` exists with required files
2. Check Packer build logs to see if files are being copied
3. Add explicit verification in Packer build
4. Rebuild Windows AMI
5. Verify config files exist in AMI before deployment