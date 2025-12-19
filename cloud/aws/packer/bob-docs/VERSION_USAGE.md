# HashiStack Version Management

## Overview
The packer configuration supports flexible version management for HashiCorp products (Consul, Nomad, Vault) with **automatic latest version detection by default**.

## Version Resolution Priority

The system uses a **two-tier approach**:

1. **Environment Variables** (if set - highest priority)
2. **Automatic Latest Version Detection** (default - scripts fetch from HashiCorp APIs)

## Default Behavior: Automatic Latest Versions ✨

**By default, when you run `packer build`, the scripts automatically fetch and install the latest versions** of Consul, Nomad, and Vault from HashiCorp.

```bash
# Simply run packer build - latest versions will be fetched automatically
packer build -only='windows.*' -var-file=windows-2022.pkrvars.hcl .

# Or for Linux
packer build -only='linux.*' -var-file=ubuntu-24.04.pkrvars.hcl .
```

### How It Works

**Windows ([`setup-windows.ps1`](../shared/packer/scripts/setup-windows.ps1)):**
- Parses https://releases.hashicorp.com/consul/, nomad/, vault/
- Extracts latest version from HTML

**Linux ([`setup.sh`](../shared/packer/scripts/setup.sh)):**
- Queries HashiCorp checkpoint API
- Uses `curl` and `jq` to extract latest versions

## Method 1: Using Latest Versions (Default - No Action Required)

Just run packer build:

```bash
packer build -only='windows.*' -var-file=windows-2022.pkrvars.hcl .
```

The scripts will automatically:
1. Fetch latest Consul version
2. Fetch latest Nomad version
3. Fetch latest Vault version
4. Download and install them

## Method 2: Using Specific Versions

### Option A: Set Environment Variables

```bash
export CONSULVERSION=1.22.1
export NOMADVERSION=1.11.1
export VAULTVERSION=1.21.1

packer build -only='windows.*' -var-file=windows-2022.pkrvars.hcl .
```

### Option B: Pass as Packer Variables

```bash
packer build \
  -var consul_version=1.22.1 \
  -var nomad_version=1.11.1 \
  -var vault_version=1.21.1 \
  -only='windows.*' \
  -var-file=windows-2022.pkrvars.hcl .
```

## Version Sources

### HashiCorp Checkpoint API
Used by [`env-pkr-var.sh`](env-pkr-var.sh) and Linux scripts:
```bash
curl -s https://checkpoint-api.hashicorp.com/v1/check/consul | jq -r '.current_version'
curl -s https://checkpoint-api.hashicorp.com/v1/check/nomad | jq -r '.current_version'
curl -s https://checkpoint-api.hashicorp.com/v1/check/vault | jq -r '.current_version'
```

### HashiCorp Releases Page
Used by Windows PowerShell script:
- Parses https://releases.hashicorp.com/consul/
- Parses https://releases.hashicorp.com/nomad/
- Parses https://releases.hashicorp.com/vault/

## Current Defaults (Fallback)

If no environment variables are set and auto-detection fails, these defaults from [`variables.pkr.hcl`](variables.pkr.hcl) are used:

- CNI: v1.8.0
- Consul Template: 0.41.2
- Consul: 1.21.4
- Nomad: 1.10.5
- Vault: 1.20.3

## Recommended Workflow

### For Production Builds
```bash
# 1. Fetch latest versions
source env-pkr-var.sh

# 2. Review versions
echo "Consul: $CONSULVERSION"
echo "Nomad: $NOMADVERSION"
echo "Vault: $VAULTVERSION"

# 3. Build
packer build -only='windows.*' -var-file=windows-2022.pkrvars.hcl .
```

### For Development/Testing
```bash
# Use specific tested versions
export CONSULVERSION=1.21.4
export NOMADVERSION=1.10.5
export VAULTVERSION=1.20.3

packer build -only='windows.*' -var-file=windows-2022.pkrvars.hcl .
```

## Verification

After the AMI is built, verify installed versions:

### Windows
```powershell
C:\HashiCorp\bin\consul.exe version
C:\HashiCorp\bin\nomad.exe version
C:\HashiCorp\bin\vault.exe version
```

### Linux
```bash
consul version
nomad version
vault version
```

## Troubleshooting

### Issue: Old versions being installed
**Solution**: Source [`env-pkr-var.sh`](env-pkr-var.sh) before building

### Issue: API rate limiting
**Solution**: Use specific versions via environment variables

### Issue: Network connectivity during build
**Solution**: Ensure the packer build instance can reach:
- checkpoint-api.hashicorp.com
- releases.hashicorp.com
- api.github.com (for CNI plugins)