# Multi-OS Support: Ubuntu and RedHat

This codebase now supports building AMIs with either **Ubuntu** or **RedHat Enterprise Linux (RHEL)** as the base operating system.

## Overview of Changes

The following modifications enable multi-OS support while maintaining the original folder structure and following best practices of tight cohesion and loose coupling:

### 1. Packer Configuration (`aws/packer/`)

#### `variables.pkr.hcl`
The OS-related variables remain unchanged and work for both operating systems:
- `variable "os"` - Set to "Ubuntu" or "RedHat"
- `variable "os_version"` - OS version (e.g., "24.04" for Ubuntu, "9.6.0" for RHEL)
- `variable "os_name"` - OS codename (e.g., "noble" for Ubuntu, "" for RHEL)

#### `aws-packer.pkr.hcl`
- **AMI source filter**: Conditionally selects base AMI based on `var.os`
  - Ubuntu: Uses Canonical's AMIs (owner ID: 099720109477)
  - RedHat: Uses Red Hat's AMIs (owner ID: 309956199498)
- **SSH username**: Automatically set to "ubuntu" or "ec2-user" based on OS
- **OS variable**: Passed to provisioning scripts via `TARGET_OS` environment variable

### 2. Provisioning Scripts (`shared/packer/scripts/`)

#### `os-detect.sh` (New)
Central OS detection and configuration script that:
- Detects OS from `/etc/os-release` or `TARGET_OS` environment variable
- Exports OS-specific variables:
  - `HOME_DIR`: "ubuntu" or "ec2-user"
  - `PKG_MANAGER`: "apt-get" or "dnf"
  - `PKG_UPDATE`: OS-specific update command
  - `PKG_INSTALL`: OS-specific install command
  - `JAVA_HOME`: OS-specific Java path
- Provides helper functions: `pkg_update()`, `pkg_install()`, `log()`

#### `setup.sh` (Modified)
- Sources `os-detect.sh` at the beginning
- Uses OS-agnostic package management functions
- Conditional logic for OS-specific installations:
  - **Ubuntu**: apt-get, software-properties-common, ec2-instance-connect
  - **RedHat**: dnf, epel-release
- Docker installation adapted for both OS types
- Java installation uses appropriate repositories

#### `client.sh` and `server.sh` (Modified)
- Source `os-detect.sh` to get `HOME_DIR` and `JAVA_HOME`
- Use dynamic `HOME_DIR` instead of hardcoded "ubuntu"
- Use dynamic `JAVA_HOME` from OS detection
- **systemd-resolved compatibility**: Conditional DNS configuration for RedHat 9+ which uses systemd-resolved
  - Creates symbolic link from `/run/systemd/resolve/resolv.conf` to `/etc/resolv.conf` if systemd-resolved is active
  - Restarts systemd-resolved to apply dnsmasq configuration
  - Ensures Docker containers can resolve `.consul` domains

### 3. Terraform Compatibility

The Terraform modules remain unchanged as they:
- Don't directly depend on OS type
- Use the same HashiCorp binary installations (Consul, Nomad, Vault)
- Rely on user-data scripts that call the OS-aware provisioning scripts

## Usage Examples

### Building Ubuntu AMI (Default)

```bash
cd aws/packer/
source env-pkr-var.sh
packer init .
packer validate .
packer build .
```

Or with explicit variables:
```bash
packer build \
  -var 'os=Ubuntu' \
  -var 'os_version=24.04' \
  -var 'os_name=noble' \
  -var 'region=us-west-2' \
  .
```

### Building RedHat AMI

Update `variables.pkr.hcl` or pass variables via command line:
```bash
packer build \
  -var 'os=RedHat' \
  -var 'os_version=9.6.0' \
  -var 'os_name=' \
  -var 'region=us-west-2' \
  .
```

Or create an `auto.pkrvars.hcl` file:
```hcl
os         = "RedHat"
os_version = "9.6.0"
os_name    = ""
```

### Deploying Infrastructure

The Terraform workflow remains the same:
```bash
cd aws/terraform/control/
terraform init
terraform apply
```

The `aws-nomad-image` module will automatically build the correct AMI based on the Packer variables.

#### AMI Cleanup Control

You can control whether AMIs are preserved or deleted during `terraform destroy`:

```hcl
# In terraform.tfvars
cleanup_ami_on_destroy = false  # Set to false to keep AMI when running terraform destroy
```

**Default behavior**: AMIs are deregistered and snapshots deleted during destroy (cleanup_ami_on_destroy = true)

**Preserve AMIs**: Set to `false` to keep AMIs for later reuse, saving rebuild time for future deployments

## Key Design Decisions

1. **OS Detection**: Centralized in `os-detect.sh` to avoid duplication
2. **Minimal Refactoring**: Original folder structure preserved
3. **Backward Compatibility**: Default values in `variables.pkr.hcl` maintain Ubuntu as default
4. **Loose Coupling**: Scripts don't hardcode OS-specific values; they derive them from detection
5. **Tight Cohesion**: All OS-specific logic contained within provisioning scripts

## Supported OS Versions

### Ubuntu
- 24.04 LTS (Noble) - Default
- 22.04 LTS (Jammy)
- 20.04 LTS (Focal)

### RedHat Enterprise Linux
- RHEL 9.6 (Recommended)
- RHEL 9.x series
- RHEL 8.x series

## Notable Differences

| Aspect | Ubuntu | RedHat |
|--------|--------|--------|
| Default User | ubuntu | ec2-user |
| Package Manager | apt-get | dnf |
| Java Path | /usr/lib/jvm/java-8-openjdk-amd64/jre | /usr/lib/jvm/jre-1.8.0-openjdk |
| AMI Owner | Canonical (099720109477) | Red Hat (309956199498) |
| AMI Naming | ubuntu/images/*ubuntu-{name}-{version}-amd64-server-* | RHEL-{version}_HVM-*-x86_64-*-Hourly2-GP3 |
| DNS Resolver | resolvconf | systemd-resolved (RHEL 9+) |

## Troubleshooting

### Issue: Packer fails with "source_ami not found"
- **Ubuntu**: Verify os_name matches a valid Ubuntu codename
- **RedHat**: Ensure os_version matches available RHEL versions in your region

### Issue: Package installation fails
- Check that EPEL repository is enabled for RedHat (handled automatically in setup.sh)
- Verify package names are correct for the target OS

### Issue: Docker doesn't start
- **RedHat**: Ensure docker service is enabled and started (handled in setup.sh)
- Check user permissions: ec2-user must be in docker group

### Issue: DNS resolution fails for .consul domains (RedHat 9+)
- **Symptom**: Docker containers can't pull images, `dig @127.0.0.1 consul.service.consul` fails
- **Cause**: systemd-resolved conflict with dnsmasq
- **Solution**: Automatically handled in `client.sh` and `server.sh` - creates symlink and restarts systemd-resolved
- **Verification**: Check `/etc/resolv.conf` points to `/run/systemd/resolve/resolv.conf`

## Testing

To verify the build works for both OS types:

1. Build Ubuntu AMI:
   ```bash
   packer build -var 'os=Ubuntu' -var 'os_version=24.04' -var 'os_name=noble' .
   ```

2. Build RedHat AMI:
   ```bash
   packer build -var 'os=RedHat' -var 'os_version=9.6.0' -var 'os_name=' .
   ```

3. Deploy and verify:
   - SSH into instances
   - Check `echo $HOME_DIR` matches expected user
   - Verify HashiCorp services: `consul members`, `nomad node status`
   - Test Docker: `docker ps`
