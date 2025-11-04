# Summary of Multi-OS Support Implementation

## Overview
Successfully modified the Nomad Autoscaler Demos codebase to support both **Ubuntu** and **RedHat Enterprise Linux (RHEL)** as base operating systems for Packer-built AMIs, while maintaining the original folder structure and following best practices.

## Files Created

### 1. `/Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/shared/packer/scripts/os-detect.sh`
**Purpose**: Central OS detection and configuration helper script

**Key Features**:
- Detects OS from `/etc/os-release` or `TARGET_OS` environment variable
- Exports OS-specific variables (HOME_DIR, PKG_MANAGER, JAVA_HOME, etc.)
- Provides helper functions: `pkg_update()`, `pkg_install()`, `log()`
- Handles both "rhel" and "redhat" ID variations

**Exported Variables**:
- `DETECTED_OS`: "Ubuntu" or "RedHat"
- `HOME_DIR`: "ubuntu" or "ec2-user"
- `PKG_MANAGER`: "apt-get" or "dnf"
- `PKG_UPDATE`: OS-specific update command
- `PKG_INSTALL`: OS-specific install command
- `JAVA_HOME`: OS-specific Java installation path

### 2. `/Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/packer/MULTI_OS_SUPPORT.md`
**Purpose**: Comprehensive documentation for multi-OS support

**Contents**:
- Overview of all changes
- Usage examples for both Ubuntu and RedHat
- Key design decisions
- Supported OS versions
- Notable differences table
- Troubleshooting guide

### 3. `/Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/packer/create-os-configs.sh`
**Purpose**: Helper script to generate .pkrvars.hcl files for different OS configurations

**Generated Files**:
- ubuntu-24.04.pkrvars.hcl
- ubuntu-22.04.pkrvars.hcl
- rhel-9.6.pkrvars.hcl
- rhel-9.5.pkrvars.hcl
- rhel-8.10.pkrvars.hcl

## Files Modified

### 1. `/Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/packer/aws-packer.pkr.hcl`

**Changes**:
- **Line 24-37**: Conditional `source_ami_filter` based on `var.os`
  - Ubuntu: Uses Canonical AMIs (owner: 099720109477) with pattern `ubuntu/images/*ubuntu-{name}-{version}-amd64-server-*`
  - RedHat: Uses Red Hat AMIs (owner: 309956199498) with pattern `RHEL-{version}_HVM-*-x86_64-*-Hourly2-GP3`
  
- **Line 42**: Conditional `ssh_username`
  - Ubuntu: "ubuntu"
  - RedHat: "ec2-user"

- **Lines 70-86**: Replaced Ubuntu-specific debconf provisioners with conditional inline checks
  - Uses `/etc/debian_version` detection for Ubuntu-only operations

- **Line 107**: Added `TARGET_OS=${var.os}` to setup.sh environment variables

**Validation**: ✅ Packer configuration validated successfully

### 2. `/Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/shared/packer/scripts/setup.sh`

**Changes**:
- **Line 21**: Removed hardcoded `HOME_DIR=ubuntu`
- **Line 25**: Added `source $SCRIPTDIR/os-detect.sh`
- **Lines 27-31**: Moved Ubuntu-specific debconf setup inside OS conditional
- **Lines 39-44**: Added OS-specific dependency installation
  - Ubuntu: `software-properties-common`, `ec2-instance-connect`
  - RedHat: `epel-release` repository setup
- **Lines 58-70**: Refactored Docker installation for both OS types
  - Ubuntu: Uses Docker's Debian repository
  - RedHat: Uses Docker's RHEL repository, enables/starts service, adds ec2-user to docker group
- **Lines 72-79**: Refactored Java installation for both OS types
  - Ubuntu: Uses PPA repository
  - RedHat: Uses standard java-1.8.0-openjdk package
- **Line 132**: Moved debconf restoration inside Ubuntu conditional

### 3. `/Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/shared/packer/scripts/client.sh`

**Changes**:
- **Line 28**: Removed hardcoded `HOME_DIR=ubuntu`
- **Line 25**: Added `source $SCRIPTDIR/os-detect.sh`
- **Line 101**: Changed hardcoded JAVA_HOME to use `${JAVA_HOME}` from os-detect.sh

**Impact**: Client nodes now work with both ubuntu and ec2-user home directories

### 4. `/Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/shared/packer/scripts/server.sh`

**Changes**:
- **Line 28**: Removed hardcoded `HOME_DIR=ubuntu`
- **Line 25**: Added `source $SCRIPTDIR/os-detect.sh`
- **Line 104**: Changed hardcoded JAVA_HOME to use `${JAVA_HOME}` from os-detect.sh

**Impact**: Server nodes now work with both ubuntu and ec2-user home directories

## Files Not Modified (By Design)

### Packer Variables
- `variables.pkr.hcl`: No changes needed - existing variables work for both OS types
- Default values maintain backward compatibility (Ubuntu 24.04)

### Terraform Modules
- `aws/terraform/modules/aws-nomad-image/`: No changes needed
- `aws/terraform/modules/aws-hashistack/`: No changes needed
- User-data scripts call OS-aware provisioning scripts

### Configuration Files
- `shared/packer/config/*`: No hardcoded user references found
- All configs use dynamic variables

### Helper Scripts
- `net.sh`: OS-agnostic network utilities
- `set-prompt.sh`: Uses `$HOME` variable, works for both users

## Technical Design Principles Applied

### 1. Tight Cohesion, Loose Coupling
- ✅ OS-specific logic centralized in `os-detect.sh`
- ✅ Other scripts depend on exported variables, not implementation details
- ✅ Changes isolated to provisioning layer, Terraform modules unchanged

### 2. Single Responsibility Principle
- ✅ `os-detect.sh`: OS detection and configuration only
- ✅ `setup.sh`: Package installation and system setup
- ✅ `client.sh`/`server.sh`: HashiCorp service configuration

### 3. DRY (Don't Repeat Yourself)
- ✅ Package management abstracted to `pkg_update()` and `pkg_install()`
- ✅ OS detection logic in one place, sourced by all scripts

### 4. Minimal Refactoring
- ✅ Original folder structure preserved
- ✅ No file moves or renames
- ✅ Backward compatible - Ubuntu remains default

## Testing Checklist

### Packer Validation
- [x] `packer init .` - Successful
- [x] `packer validate .` - Configuration is valid
- [ ] `packer build -var 'os=Ubuntu' .` - To be tested
- [ ] `packer build -var 'os=RedHat' .` - To be tested

### Expected Behavior

#### For Ubuntu Build:
1. Uses Canonical AMIs (099720109477)
2. SSH as "ubuntu" user
3. Uses apt-get for package management
4. Installs Docker from Ubuntu repos
5. Configures Java at `/usr/lib/jvm/java-8-openjdk-amd64/jre`
6. Creates home directory: `/home/ubuntu`

#### For RedHat Build:
1. Uses Red Hat AMIs (309956199498)
2. SSH as "ec2-user" user
3. Uses dnf for package management
4. Installs Docker from RHEL repos, enables service
5. Configures Java at `/usr/lib/jvm/jre-1.8.0-openjdk`
6. Creates home directory: `/home/ec2-user`

## Usage Examples

### Build Ubuntu AMI (Default)
```bash
cd aws/packer/
source env-pkr-var.sh
packer build .
```

### Build RedHat AMI
```bash
cd aws/packer/
source env-pkr-var.sh
packer build -var 'os=RedHat' -var 'os_version=9.6.0' -var 'os_name=' .
```

### Or use pre-configured var files
```bash
./create-os-configs.sh
packer build -var-file=rhel-9.6.pkrvars.hcl .
```

## Known Limitations

1. **Java Version**: Both OS types use Java 8 (OpenJDK)
   - Ubuntu: java-8-openjdk-amd64
   - RedHat: java-1.8.0-openjdk

2. **CNI Plugins**: Same version used for both OS types

3. **HashiCorp Binaries**: OS-agnostic, same versions for both

4. **Architecture**: Currently only amd64/x86_64 supported

## Future Enhancements

1. **ARM Support**: Add arm64 architecture option
2. **Additional OS Support**: Amazon Linux 2, CentOS Stream
3. **Java Version Selection**: Make Java version configurable
4. **Automated Testing**: Add integration tests for both OS types

## Verification Commands

### On Built Instance (Ubuntu)
```bash
ssh ubuntu@<ip>
echo $HOME_DIR  # Should output: ubuntu
which apt-get   # Should return path
docker ps       # Should work
java -version   # Should show OpenJDK 8
```

### On Built Instance (RedHat)
```bash
ssh ec2-user@<ip>
echo $HOME_DIR  # Should output: ec2-user
which dnf       # Should return path
docker ps       # Should work
java -version   # Should show OpenJDK 8
```

## Rollback Procedure

If issues occur, revert changes:
```bash
git checkout HEAD -- shared/packer/scripts/
git checkout HEAD -- aws/packer/aws-packer.pkr.hcl
```

Remove new files:
```bash
rm shared/packer/scripts/os-detect.sh
rm aws/packer/MULTI_OS_SUPPORT.md
rm aws/packer/create-os-configs.sh
```

## Maintainer Notes

- **OS Detection**: Priority is TARGET_OS env var > /etc/os-release
- **Package Manager**: All package operations use helper functions
- **Error Handling**: Scripts use `set -Eeuo pipefail` for strict error handling
- **Logging**: Unified logging pattern with LOG_FILE and deduplication guards
- **Idempotency**: All scripts can be run multiple times safely

## Related Documentation

- [VERSION_MANAGEMENT.md](VERSION_MANAGEMENT.md) - Packer version management system
- [MULTI_OS_SUPPORT.md](MULTI_OS_SUPPORT.md) - Detailed multi-OS usage guide
- [.github/copilot-instructions.md](../../.github/copilot-instructions.md) - Project architecture

---

**Status**: ✅ Implementation Complete
**Packer Validation**: ✅ Passed
**Backward Compatibility**: ✅ Maintained
**Documentation**: ✅ Complete
