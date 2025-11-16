# Quick Reference: Ubuntu vs RedHat vs Windows Configuration

This reference now covers Windows Server 2022 alongside Ubuntu and RedHat.

## Packer Variables

| Variable | Ubuntu Value | RedHat Value | Windows Value | Notes |
|----------|--------------|-------------|---------------|-------|
| `os` | Ubuntu | RedHat | Windows | Required selector |
| `os_version` | 24.04 | 9.6.0 | 2022 | Ubuntu/RedHat use semantic versions; Windows uses year |
| `os_name` | noble | (empty) | (empty) | Ubuntu codename only |

## Base AMI Details

| Property | Ubuntu | RedHat | Windows |
|----------|--------|--------|---------|
| AMI Owner ID | 099720109477 (Canonical) | 309956199498 (Red Hat) | 801119661308 (Amazon) |
| AMI Name Pattern | ubuntu/images/*ubuntu-{name}-{version}-amd64-server-* | RHEL-{version}_HVM-*-x86_64-*-Hourly2-GP3 | Windows_Server-2022-English-Full-Base-* |
| Default SSH User | ubuntu | ec2-user | Administrator |
| Home Directory | /home/ubuntu | /home/ec2-user | C:\\Users\\Administrator |

## System Configuration

| Component | Ubuntu | RedHat | Windows |
|-----------|--------|--------|---------|
| Package Manager | apt-get | dnf | (N/A default) |
| Update Command | sudo apt-get update | sudo dnf check-update | (N/A default) |
| Install Command | sudo apt-get install -y | sudo dnf install -y | Add-WindowsCapability / (future package manager) |
| Java Path | /usr/lib/jvm/java-8-openjdk-amd64/jre | /usr/lib/jvm/jre-1.8.0-openjdk | (Not preinstalled) |
| Docker | Installed (CE) | Installed (CE) | Not installed (can be added) |
| DNS Mgmt | resolvconf | systemd-resolved (RHEL 9+) | Windows DNS Client |

## Package / Component Summary

| Component | Ubuntu | RedHat | Windows | Notes |
|-----------|--------|--------|---------|-------|
| EC2 Instance Connect | ec2-instance-connect | N/A | N/A | Ubuntu push-only keys |
| SSM Agent | amazon-ssm-agent | amazon-ssm-agent | Preinstalled | Windows AMI already includes agent |
| OpenSSH Server | Preinstalled | Preinstalled | Added in Packer build | We enable & open firewall rule |
| Java 8 | openjdk-8-jdk | java-1.8.0-openjdk(-devel) | Not installed | Optional |
| Docker | docker-ce | docker-ce docker-ce-cli containerd.io | Not installed | Optional future enhancement |

## Build Commands

### Ubuntu 24.04
```bash
cd aws/packer/
packer build -var 'os=Ubuntu' -var 'os_version=24.04' -var 'os_name=noble' -var 'region=us-west-2' .
```

### RedHat 9.6
```bash
cd aws/packer/
packer build -var 'os=RedHat' -var 'os_version=9.6.0' -var 'os_name=' -var 'region=us-west-2' .
```

### Windows Server 2022
```bash
cd aws/packer/
packer build -var 'os=Windows' -var 'os_version=2022' -var 'os_name=' -var 'region=us-west-2' aws-packer-windows.pkr.hcl
```

## Runtime Environment Variables (Linux builds)

| Variable | Ubuntu | RedHat | Windows |
|----------|--------|--------|---------|
| TARGET_OS | Ubuntu | RedHat | Windows | Provided to scripts |
| DETECTED_OS | Ubuntu | RedHat | (Not used) | Windows provisioning uses PowerShell |
| HOME_DIR | ubuntu | ec2-user | Administrator | For path construction |
| PKG_MANAGER | apt-get | dnf | (N/A) | Linux only |
| JAVA_HOME | /usr/lib/jvm/java-8-openjdk-amd64/jre | /usr/lib/jvm/jre-1.8.0-openjdk | (Unset) | Not set for Windows |

## Supported Versions

### Ubuntu
- 24.04 (Noble) Recommended
- 22.04 (Jammy)
- 20.04 (Focal)

### RedHat Enterprise Linux
- 9.6 Recommended
- 9.x series
- 8.x series

### Windows Server
- 2022 English Full Base (Recommended)
  - OpenSSH enabled
  - SSM Agent auto-start
  - Administrator password randomization optional (EC2Launch v2 config)

## SSH / SSM Access

### Ubuntu
```bash
ssh ubuntu@<public_ip_or_dns>
```

### RedHat
```bash
ssh ec2-user@<public_ip_or_dns>
```

### Windows
```bash
# SSH (key-based)
ssh Administrator@<windows_public_dns>

# SSM Session (requires IAM role with AmazonSSMManagedInstanceCore)
aws ssm start-session --target <windows_instance_id> --region <region>
```

## Verification Commands

### Linux (OS release)
```bash
cat /etc/os-release | grep '^ID='
```

### Windows (PowerShell)
```powershell
[System.Environment]::OSVersion.Version
Get-ComputerInfo | Select-Object OsName,OsVersion
Get-Service sshd
```

### HashiCorp Binaries (Linux)
```bash
consul version
nomad version
systemctl status consul
systemctl status nomad
```

## Common Issues

### Cannot SSH to Windows
Causes:
1. OpenSSH not installed (Packer build failed). Rebuild AMI.
2. Key not injected (user-data failed). Check `C:\\ProgramData\\ssh\\administrators_authorized_keys`.
3. Security group missing port 22. Add inbound rule.
4. Local key mismatch. Use the private key matching `key_name` in terraform.

### Windows SSM Session Fails
Missing IAM instance profile or permission. Ensure Windows instance uses `iam_instance_profile` with policy `AmazonSSMManagedInstanceCore`.

### RedHat DNS / Docker Pull Failures
systemd-resolved port 53 conflict handled in scripts; verify `dnsmasq` listening and `/etc/resolv.conf` content.

## IAM Policy Requirements

Attach (at minimum) to instance roles:
- `AmazonSSMManagedInstanceCore` (all OS for SSM / Session Manager)
- `AmazonEC2ReadOnlyAccess` (optional for diagnostics)
- For autoscaling clients: existing inline policy already includes required Auto Scaling actions.
- For Ubuntu EC2 Instance Connect: `AmazonEC2InstanceConnect` (optional; we use traditional key pairs primarily).

## Cost Comparison (t3a.medium illustrative)

| OS | Approx Hourly | Notes |
|----|---------------|-------|
| Ubuntu | ~$0.0376 | Lowest cost |
| RedHat | ~$0.0876 | Includes RHEL license |
| Windows | ~$0.12-0.14 | Includes Windows license |

## Windows Build Notes
Packer Windows build uses WinRM communicator. Ensure local network egress to reach instance. Build can take 20–30 minutes the first time (OpenSSH capability install + EC2Launch config writes).

## Minimal Terraform Flags For Windows-Only Test
```bash
terraform plan \
  -var 'packer_os=Windows' \
  -var 'packer_os_version=2022' \
  -var 'packer_os_name=' \
  -var 'enable_windows_test=true' \
  -var 'server_count=0' \
  -var 'client_count=0' \
  -out win.tfplan
terraform apply -auto-approve win.tfplan
```

## Troubleshooting Order
1. Confirm AMI tags (OS, OS_Version).
2. Confirm instance profile attached (for SSM).
3. Check user-data execution (Windows event log: `Microsoft-Windows-CloudInit` / EC2Launch).
4. Validate OpenSSH service `Get-Service sshd`.
5. Attempt SSM session if SSH blocked.

# Quick Reference: Ubuntu vs RedHat Configuration

## Packer Variables

| Variable | Ubuntu Value | RedHat Value | Notes |
|----------|-------------|--------------|-------|
| `os` | Ubuntu | RedHat | Required |
| `os_version` | 24.04 | 9.6.0 | Major.Minor or Major.Minor.Patch |
| `os_name` | noble | "" (empty) | Ubuntu codename, not used for RHEL |

## Base AMI Details

| Property | Ubuntu | RedHat |
|----------|--------|--------|
| AMI Owner ID | 099720109477 (Canonical) | 309956199498 (Red Hat) |
| AMI Name Pattern | ubuntu/images/*ubuntu-{name}-{version}-amd64-server-* | RHEL-{version}_HVM-*-x86_64-*-Hourly2-GP3 |
| Default SSH User | ubuntu | ec2-user |
| Home Directory | /home/ubuntu | /home/ec2-user |

## System Configuration

| Component | Ubuntu | RedHat |
|-----------|--------|--------|
| Package Manager | apt-get | dnf |
| Update Command | sudo apt-get update | sudo dnf check-update |
| Install Command | sudo apt-get install -y | sudo dnf install -y |
| Java Path | /usr/lib/jvm/java-8-openjdk-amd64/jre | /usr/lib/jvm/jre-1.8.0-openjdk |
| Docker Repo | download.docker.com/linux/ubuntu | download.docker.com/linux/rhel |
| DNS Management | resolvconf | systemd-resolved (RHEL 9+) |

## Package Names

| Package | Ubuntu | RedHat | Notes |
|---------|--------|--------|-------|
| Software Properties | software-properties-common | dnf-plugins-core | Repo management |
| EC2 Instance Connect | ec2-instance-connect | N/A | Ubuntu-specific |
| EPEL Repository | N/A | epel-release | RedHat-specific |
| Java 8 | openjdk-8-jdk | java-1.8.0-openjdk java-1.8.0-openjdk-devel | |
| Docker | docker-ce | docker-ce docker-ce-cli containerd.io | |

## Build Commands Comparison

### Ubuntu 24.04 Build
```bash
cd aws/packer/
packer build \
  -var 'os=Ubuntu' \
  -var 'os_version=24.04' \
  -var 'os_name=noble' \
  -var 'region=us-west-2' \
  .
```

### RedHat 9.6 Build
```bash
cd aws/packer/
packer build \
  -var 'os=RedHat' \
  -var 'os_version=9.6.0' \
  -var 'os_name=' \
  -var 'region=us-west-2' \
  .
```

## Environment Variables Set During Build

| Variable | Purpose | Ubuntu Value | RedHat Value |
|----------|---------|--------------|--------------|
| TARGET_OS | OS detection override | Ubuntu | RedHat |
| DETECTED_OS | Detected OS from script | Ubuntu | RedHat |
| HOME_DIR | User home directory name | ubuntu | ec2-user |
| PKG_MANAGER | Package manager name | apt-get | dnf |
| JAVA_HOME | Java installation path | /usr/lib/jvm/java-8-openjdk-amd64/jre | /usr/lib/jvm/jre-1.8.0-openjdk |

## Supported OS Versions

### Ubuntu
- ✅ 24.04 LTS (Noble Numbat) - **Recommended**
- ✅ 22.04 LTS (Jammy Jellyfish)
- ✅ 20.04 LTS (Focal Fossa)

### RedHat Enterprise Linux
- ✅ RHEL 9.6 - **Recommended**
- ✅ RHEL 9.5
- ✅ RHEL 9.4
- ✅ RHEL 8.10
- ✅ RHEL 8.8

## Pre-configured Variable Files

After running `./create-os-configs.sh`:

| File | OS | Version |
|------|-----|---------|
| ubuntu-24.04.pkrvars.hcl | Ubuntu | 24.04 (Noble) |
| ubuntu-22.04.pkrvars.hcl | Ubuntu | 22.04 (Jammy) |
| rhel-9.6.pkrvars.hcl | RedHat | 9.6.0 |
| rhel-9.5.pkrvars.hcl | RedHat | 9.5.0 |
| rhel-8.10.pkrvars.hcl | RedHat | 8.10.0 |

Usage:
```bash
packer build -var-file=rhel-9.6.pkrvars.hcl .
```

## Files Modified by OS Type

| File | Ubuntu-Specific Code | RedHat-Specific Code | OS-Agnostic |
|------|---------------------|---------------------|-------------|
| os-detect.sh | ✅ Lines 40-49 | ✅ Lines 50-59 | ✅ Lines 1-39, 60-82 |
| setup.sh | ✅ Lines 27-31, 42-43 | ✅ Lines 44-46, 66-70 | ✅ Most of file |
| client.sh | ✅ (via os-detect) | ✅ (via os-detect) | ✅ All logic |
| server.sh | ✅ (via os-detect) | ✅ (via os-detect) | ✅ All logic |
| aws-packer.pkr.hcl | ✅ Lines 25-29, 36 | ✅ Lines 30-35, 36 | ✅ Lines 1-24, 37+ |

## SSH Access After Instance Launch

### Ubuntu Instance
```bash
# From Terraform outputs
ssh ubuntu@<server_elb_dns>
ssh ubuntu@<client_instance_ip>

# With SSH key
ssh -i ~/.ssh/your-key.pem ubuntu@<ip>
```

### RedHat Instance
```bash
# From Terraform outputs
ssh ec2-user@<server_elb_dns>
ssh ec2-user@<client_instance_ip>

# With SSH key
ssh -i ~/.ssh/your-key.pem ec2-user@<ip>
```

## Verification Commands

### Check OS Type
```bash
# Ubuntu
cat /etc/os-release | grep "^ID="
# Output: ID=ubuntu

# RedHat
cat /etc/os-release | grep "^ID="
# Output: ID=rhel
```

### Check Package Manager
```bash
# Ubuntu
which apt-get
dpkg -l | grep consul

# RedHat
which dnf
rpm -qa | grep consul
```

### Check Docker
```bash
# Both OS types
docker --version
docker ps
systemctl status docker
```

### Check Java
```bash
# Both OS types
java -version
echo $JAVA_HOME
```

### Check HashiCorp Services
```bash
# Both OS types
consul version
nomad version
systemctl status consul
systemctl status nomad
```

## Common Issues and Solutions

### Issue: AMI not found

**Ubuntu:**
```bash
# Check available versions for your region
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/*ubuntu-noble-24.04-amd64-server-*" \
  --region us-west-2 \
  --query 'Images[*].[Name,ImageId]' \
  --output table
```

**RedHat:**
```bash
# Check available versions for your region
aws ec2 describe-images \
  --owners 309956199498 \
  --filters "Name=name,Values=RHEL-9.6.0_HVM-*" \
  --region us-west-2 \
  --query 'Images[*].[Name,ImageId]' \
  --output table
```

### Issue: SSH connection refused

**Solution:** Ensure you're using the correct username:
- Ubuntu AMIs: `ubuntu`
- RedHat AMIs: `ec2-user`

### Issue: Package installation fails

**Ubuntu:** Check `/var/log/provision.log` for apt errors
**RedHat:** Check `/var/log/provision.log` for dnf errors

Common causes:
- Network connectivity issues
- Repository mirrors down
- Insufficient disk space

### Issue: DNS resolution fails on RedHat 9+

**Symptom:** Docker containers can't pull images, `.consul` domain doesn't resolve
**Cause:** systemd-resolved conflicts with dnsmasq
**Solution:** Automatically fixed in provisioning scripts - creates symlink `/etc/resolv.conf` → `/run/systemd/resolve/resolv.conf`
**Verification:** 
```bash
systemctl status systemd-resolved  # Should be active
dig @127.0.0.1 consul.service.consul  # Should resolve
```

### Issue: AMI not deleted after terraform destroy

**Solution:** Check `cleanup_ami_on_destroy` variable in `terraform.tfvars`
- Default: `true` (AMI is deleted)
- Set to `false` to preserve AMI for reuse
- Preserved AMIs must be manually deregistered via AWS Console or CLI

## Migration Path

### From Ubuntu-only to Multi-OS

1. **No changes needed** to existing Ubuntu builds
2. To build RedHat: Change variables only
3. Terraform modules work with both OS types
4. User-data scripts are OS-aware

### Testing Strategy

1. Build Ubuntu AMI first (proven configuration)
2. Deploy and validate Ubuntu infrastructure
3. Build RedHat AMI with new variables
4. Deploy RedHat infrastructure in separate region/account
5. Compare behavior and performance
6. Gradually adopt preferred OS type

## Cost Considerations

| OS Type | Licensing | Typical Hourly Cost (t3a.medium) |
|---------|-----------|----------------------------------|
| Ubuntu | Free (community) | ~$0.0376 |
| RedHat | RHEL license included in hourly rate | ~$0.0876 |

**Note:** RedHat AMIs cost approximately 2-3x more due to included RHEL licensing.

## Performance Characteristics

Both OS types provide similar performance for HashiCorp workloads:
- ✅ Identical Consul/Nomad/Vault binaries
- ✅ Similar Docker performance
- ✅ Comparable network throughput
- ✅ Similar disk I/O

Choose based on:
- **Ubuntu**: Lower cost, larger community, more tutorials
- **RedHat**: Enterprise support, stricter security defaults, corporate compliance requirements
