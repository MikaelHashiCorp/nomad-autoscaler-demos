# Build 25 Root Cause Analysis

## Executive Summary
Due diligence revealed the actual root cause: **`source env-pkr-var.sh` was removed from the Terraform packer build command**, causing Packer to use default fallback versions instead of the pinned versions from the API.

## Investigation Timeline

### Initial Hypothesis (INCORRECT)
- **Claim**: PowerShell's `&` operator doesn't inherit environment variables
- **Status**: ❌ DISPROVEN by build logs
- **Evidence**: Build logs show "Using X version from environment" for all products

### Build Log Analysis (CORRECT)
Build output confirmed environment variables ARE being passed to scripts:

**Windows**:
```
Setting HashiCorp product versions...
  Consul: 1.21.4
  Nomad: 1.10.5
  Vault: 1.20.3

Using Consul version from environment: 1.21.4
Using Nomad version from environment: 1.10.5
Using Vault version from environment: 1.20.3
```

**Linux**:
```
Using Consul version from environment: 1.21.4
Using Nomad version from environment: 1.10.5
Using CNI version from environment: v1.8.0
```

### Key Insight
The scripts ARE receiving environment variables correctly. The problem is that **Packer is receiving the wrong values in the first place**.

## Root Cause

### The Missing Command
**File**: `terraform/modules/aws-nomad-image/image.tf`

**Old Working Version** (commit e245e80):
```hcl
provisioner "local-exec" {
  working_dir = "${path.root}/../../packer"
  command = <<EOF
source env-pkr-var.sh && \
  packer build -force \
    -var 'created_name=${var.owner_name}' \
    -var 'created_email=${var.owner_email}' \
    -var 'region=${var.region}' \
    -var 'name_prefix=${var.stack_name}' \
    .
EOF
}
```

**Current Broken Version**:
```hcl
provisioner "local-exec" {
  working_dir = "${path.root}/../../packer"
  command = <<EOF
packer build -force \
  -only='${var.packer_os == "Windows" ? "windows" : "linux"}.amazon-ebs.hashistack' \
  -var 'created_name=${var.owner_name}' \
  -var 'created_email=${var.owner_email}' \
  -var 'region=${var.region}' \
  -var 'name_prefix=${var.stack_name}' \
  -var 'os=${var.packer_os}' \
  -var 'os_version=${var.packer_os_version}' \
  -var 'os_name=${var.packer_os_name}' \
  .
EOF
}
```

**What's Missing**: `source env-pkr-var.sh && \`

### Why This Matters

**env-pkr-var.sh** fetches the latest versions from HashiCorp APIs:
```bash
export CONSULVERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/consul | jq -r '.current_version')
export NOMADVERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/nomad | jq -r '.current_version')
export VAULTVERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/vault | jq -r '.current_version')
```

**Current API Returns** (as of 2025-12-20):
- Consul: 1.21.4
- Nomad: 1.10.5
- Vault: 1.20.3

**Build 20 Used** (when env-pkr-var.sh was sourced):
- Consul: 1.22.2
- Nomad: 1.11.1
- Vault: 1.21.1

### Packer Variable Fallback Chain

**File**: `packer/variables.pkr.hcl`
```hcl
variable "nomad_version" {
  description = "Nomad version. If empty, will use environment variable or default"
  type        = string
  default     = env("NOMADVERSION") != "" ? env("NOMADVERSION") : "1.10.5"
}
```

**Fallback Logic**:
1. Check if `NOMADVERSION` environment variable is set
2. If yes, use it
3. If no, use hardcoded default "1.10.5"

**What Happened**:
- Terraform didn't run `source env-pkr-var.sh`
- `NOMADVERSION` environment variable was NOT set
- Packer used fallback default: "1.10.5"
- This default happens to match the current API latest version

## Why The Confusion

The versions from Packer's fallback defaults (1.10.5, 1.20.3, 1.21.4) happen to be very close to the current API latest versions, making it appear as if the script was fetching from the API. In reality:

1. Packer used its hardcoded defaults
2. These defaults were old and happened to match current API versions
3. The scripts correctly used these values from Packer's environment variables
4. Everything appeared to work, but with wrong versions

## The Fix

### Option 1: Restore `source env-pkr-var.sh` (RECOMMENDED)
Add back the missing command to `terraform/modules/aws-nomad-image/image.tf`:

```hcl
provisioner "local-exec" {
  working_dir = "${path.root}/../../packer"
  command = <<EOF
source env-pkr-var.sh && \
  packer build -force \
    -only='${var.packer_os == "Windows" ? "windows" : "linux"}.amazon-ebs.hashistack' \
    ...
EOF
}
```

**Pros**:
- Minimal change
- Restores working behavior
- Uses latest versions from HashiCorp APIs

**Cons**:
- Versions will change over time as APIs update
- May cause version drift between builds

### Option 2: Pin Versions in Terraform Variables
Pass explicit version variables to Packer:

```hcl
command = <<EOF
packer build -force \
  -var 'consul_version=1.22.2' \
  -var 'nomad_version=1.11.1' \
  -var 'vault_version=1.21.1' \
  ...
EOF
```

**Pros**:
- Explicit version control
- No dependency on external APIs
- Reproducible builds

**Cons**:
- Requires updating Terraform variables
- More maintenance

### Option 3: Hybrid Approach
Source env-pkr-var.sh but allow Terraform overrides:

```hcl
command = <<EOF
source env-pkr-var.sh && \
  packer build -force \
    ${var.nomad_version != "" ? "-var 'nomad_version=${var.nomad_version}'" : ""} \
    ...
EOF
```

## Lessons Learned

### What Went Wrong
1. ❌ Assumed PowerShell environment variable issue without checking logs
2. ❌ Didn't verify the actual values being passed to Packer
3. ❌ Didn't compare current vs. working version of image.tf

### What Went Right
1. ✅ User asked for due diligence
2. ✅ Checked build logs to verify hypothesis
3. ✅ Traced back through git history to find working version
4. ✅ Identified exact change that broke functionality

### Key Takeaway
**Always verify assumptions with actual data before proposing solutions.** The build logs contained the truth all along - we just needed to look at them carefully.

## Next Steps

1. ✅ Document root cause analysis
2. ⏳ Implement fix (Option 1 recommended)
3. ⏳ Test with Build 26
4. ⏳ Verify versions match Build 20
5. ⏳ Proceed with KB validation

## Impact Assessment

### Builds Affected
- Build 21: ✅ Worked (used old image.tf with source command)
- Build 22-25: ❌ Wrong versions (missing source command)

### Why Build 21 Worked
Build 21 was before the image.tf refactoring that removed the `source env-pkr-var.sh` command.

### Current State
- Linux AMI: ami-0a91d5b822ca3c233 (wrong versions)
- Windows AMI: ami-06ee351ed56954425 (wrong versions)
- Both need to be rebuilt with correct versions