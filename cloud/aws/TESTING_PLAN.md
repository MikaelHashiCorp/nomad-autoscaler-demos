# Testing Plan: Multi-OS Support (Ubuntu & RedHat)

## Overview

This document outlines the comprehensive testing strategy to validate that both Ubuntu and RedHat builds work correctly with the Packer → Terraform → HashiStack deployment pipeline.

## Test Objectives

1. ✅ Verify Packer builds succeed for both Ubuntu and RedHat
2. ✅ Verify Terraform can deploy infrastructure using both AMI types
3. ✅ Verify HashiStack services (Consul, Nomad, Vault) function correctly on both OS types
4. ✅ Verify autoscaling and demo workloads operate correctly
5. ✅ Verify cleanup process removes both AMIs and instances (or preserves them based on configuration)
6. ✅ Verify DNS resolution works on both OS types, especially RedHat 9+ with systemd-resolved
7. ✅ Verify region configuration is read from terraform.tfvars in all scripts

## Prerequisites

- AWS CLI configured with appropriate credentials
- Packer installed and in PATH
- Terraform installed and in PATH
- SSH key pair configured in AWS (specified in `terraform.tfvars`)
- Sufficient AWS quotas for EC2 instances

## Test Environment Setup

### Directory Structure
```
aws/
├── packer/           # Packer build directory
└── terraform/
    └── control/      # Terraform deployment directory
```

### Test Isolation Strategy

To test both OS types without conflicts:
1. **Option A (Parallel)**: Use different AWS regions for Ubuntu vs RedHat tests
2. **Option B (Sequential)**: Test one OS, destroy, then test the other OS
3. **Option C (Separate Stacks)**: Use different `name_prefix` values in Packer variables

**Recommended**: Option B (Sequential) for initial validation

---

## Phase 1: Ubuntu Build & Deployment Test (Baseline)

### 1.1 Packer Build - Ubuntu

**Location**: `aws/packer/`

```bash
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/packer

# Clean any previous builds
rm -f packer.log
rm -f .cleanup-*

# Set environment variables for HashiCorp versions
source env-pkr-var.sh

# Initialize Packer
packer init .

# Validate configuration
packer validate .

# Build Ubuntu AMI (default configuration)
packer build .
```

**Expected Results**:
- ✅ Packer build completes successfully
- ✅ AMI is created with name: `scale-mws-<timestamp>`
- ✅ AMI tags include: OS=Ubuntu, OS_Version=24.04
- ✅ Build log shows: "OS Detection: Ubuntu"
- ✅ Docker and Java installed via apt-get
- ✅ All provisioning scripts complete without errors

**Capture**:
```bash
# Save the AMI ID
export UBUNTU_AMI_ID=$(aws ec2 describe-images \
  --owners self \
  --filters "Name=name,Values=scale-mws-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text \
  --region us-west-2)

echo "Ubuntu AMI ID: $UBUNTU_AMI_ID"
```

**Verification Commands**:
```bash
# Check AMI exists
aws ec2 describe-images \
  --image-ids $UBUNTU_AMI_ID \
  --region us-west-2 \
  --query 'Images[0].[ImageId,Name,State,Tags]' \
  --output table

# Verify AMI tags
aws ec2 describe-images \
  --image-ids $UBUNTU_AMI_ID \
  --region us-west-2 \
  --query 'Images[0].Tags[?Key==`OS`||Key==`OS_Version`]' \
  --output table
```

### 1.2 Terraform Deployment - Ubuntu

**Location**: `aws/terraform/control/`

```bash
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/terraform/control

# Ensure terraform.tfvars is configured
# Required variables: region, key_name, owner_name, owner_email

# Initialize Terraform
terraform init

# Plan (should detect existing AMI or build if needed)
terraform plan -out=ubuntu.tfplan

# Apply
terraform apply ubuntu.tfplan
```

**Expected Results**:
- ✅ Terraform detects the existing Ubuntu AMI (no Packer rebuild)
- ✅ Creates server instances (ELB, EC2)
- ✅ Creates client Auto Scaling Group
- ✅ Outputs include: `client_lb_dns`, `server_lb_dns`

**Capture Outputs**:
```bash
# Save Terraform outputs
terraform output -json > ubuntu-outputs.json

# Extract key URLs
export UBUNTU_NOMAD_UI=$(terraform output -raw server_lb_dns):4646/ui
export UBUNTU_CONSUL_UI=$(terraform output -raw server_lb_dns):8500/ui
export UBUNTU_GRAFANA_UI=$(terraform output -raw client_lb_dns):3000
export UBUNTU_WEBAPP=$(terraform output -raw client_lb_dns)

echo "=== Ubuntu Deployment URLs ==="
echo "Nomad UI:   http://$UBUNTU_NOMAD_UI"
echo "Consul UI:  http://$UBUNTU_CONSUL_UI"
echo "Grafana:    http://$UBUNTU_GRAFANA_UI"
echo "Web App:    http://$UBUNTU_WEBAPP"
```

### 1.3 Service Validation - Ubuntu

**Wait for Services to Start** (2-3 minutes):
```bash
sleep 180
```

#### Test 1: Consul UI & API
```bash
# Test Consul UI accessibility
curl -I http://$(terraform output -raw server_lb_dns):8500/ui/ | head -1

# Check Consul members via API
curl -s http://$(terraform output -raw server_lb_dns):8500/v1/agent/members | jq '.[].Name'

# Expected: Should see server nodes listed
```

**Manual Verification**:
- [ ] Open Consul UI in browser: `http://<server_lb_dns>:8500/ui`
- [ ] Verify 1+ server nodes visible
- [ ] Verify services are registering
- [ ] Check "Nodes" tab shows healthy servers

#### Test 2: Nomad UI & API
```bash
# Test Nomad UI accessibility
curl -I http://$(terraform output -raw server_lb_dns):4646/ui/ | head -1

# Check Nomad server members
curl -s http://$(terraform output -raw server_lb_dns):4646/v1/agent/members | jq '.Members[].Name'

# Check Nomad client nodes
curl -s http://$(terraform output -raw server_lb_dns):4646/v1/nodes | jq '.[] | {Name: .Name, Status: .Status}'
```

**Manual Verification**:
- [ ] Open Nomad UI in browser: `http://<server_lb_dns>:4646/ui`
- [ ] Verify server status is "ready"
- [ ] Verify client nodes are visible (may be 0 initially if ASG hasn't scaled)
- [ ] Check "Jobs" tab shows autoscaler and demo jobs running

#### Test 3: SSH into Ubuntu Instance
```bash
# Get a server instance IP
SERVER_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*server*" \
           "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text \
  --region us-west-2)

# SSH into server (use correct key path)
ssh -i ~/.ssh/your-key.pem ubuntu@$SERVER_IP
```

**On the instance, verify**:
```bash
# Check OS
cat /etc/os-release | grep "^ID="  # Should show: ID=ubuntu

# Check HOME_DIR
echo $HOME                          # Should show: /home/ubuntu

# Check package manager
which apt-get                       # Should return path

# Check Docker
docker --version
docker ps

# Check Java
java -version
echo $JAVA_HOME                     # Should show: /usr/lib/jvm/java-8-openjdk-amd64/jre

# Check HashiCorp services
consul version
nomad version
systemctl status consul
systemctl status nomad

# Check logs
tail -50 /var/log/provision.log     # Should show OS Detection: Ubuntu

# Check DNS resolution (important for Docker)
dig @127.0.0.1 consul.service.consul  # Should resolve
systemctl status dnsmasq             # Should be active

# Exit
exit
```

#### Test 4: Autoscaling & Demo Jobs
```bash
# Check if autoscaler job is running
curl -s http://$(terraform output -raw server_lb_dns):4646/v1/job/autoscaler/summary | jq '.Summary'

# Check demo webapp job
curl -s http://$(terraform output -raw server_lb_dns):4646/v1/job/webapp/summary | jq '.Summary'

# Generate some load to test autoscaling
for i in {1..100}; do 
  curl -s http://$(terraform output -raw client_lb_dns) > /dev/null
  echo "Request $i"
  sleep 1
done

# Check if ASG scaled up (wait a few minutes)
sleep 120
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(aws autoscaling describe-auto-scaling-groups \
    --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'client')].AutoScalingGroupName" \
    --output text --region us-west-2) \
  --query 'AutoScalingGroups[0].[DesiredCapacity,MinSize,MaxSize]' \
  --output table \
  --region us-west-2
```

**Manual Verification**:
- [ ] Grafana dashboard shows metrics: `http://<client_lb_dns>:3000/d/AQphTqmMk/demo`
- [ ] Webapp responds: `http://<client_lb_dns>`
- [ ] Under load, ASG scales up client nodes in Nomad UI

### 1.4 Terraform Destroy - Ubuntu

```bash
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/terraform/control

# Destroy infrastructure (default: cleanup_ami_on_destroy = true)
terraform destroy -auto-approve

# Wait for completion
# Expected: All instances terminated, AMI deregistered, snapshots deleted (unless cleanup_ami_on_destroy = false)
```

**Note**: To test AMI preservation, set `cleanup_ami_on_destroy = false` in terraform.tfvars before running terraform apply.

**Verification**:
```bash
# Verify AMI is deleted
aws ec2 describe-images \
  --image-ids $UBUNTU_AMI_ID \
  --region us-west-2 2>&1 | grep -q "InvalidAMIID.NotFound" && echo "✅ AMI deleted" || echo "❌ AMI still exists"

# Verify instances are terminated
aws ec2 describe-instances \
  --filters "Name=tag:OwnerName,Values=*" \
           "Name=instance-state-name,Values=running,pending" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text \
  --region us-west-2

# Should return empty if all destroyed
```

---

## Phase 2: RedHat Build & Deployment Test

### 2.1 Packer Build - RedHat

**Location**: `aws/packer/`

```bash
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/packer

# Clean previous builds
rm -f packer.log
rm -f .cleanup-*

# Set environment variables
source env-pkr-var.sh

# Build RedHat AMI with explicit variables
packer build \
  -var 'os=RedHat' \
  -var 'os_version=9.6.0' \
  -var 'os_name=' \
  -var 'name_prefix=scale-mws-rhel' \
  .
```

**Expected Results**:
- ✅ Packer selects RedHat base AMI (owner: 309956199498)
- ✅ Connects via SSH as `ec2-user`
- ✅ AMI created with name: `scale-mws-rhel-<timestamp>`
- ✅ AMI tags include: OS=RedHat, OS_Version=9.6.0
- ✅ Build log shows: "OS Detection: RedHat"
- ✅ Docker and Java installed via dnf
- ✅ EPEL repository enabled
- ✅ All provisioning scripts complete without errors

**Capture**:
```bash
# Save the AMI ID
export RHEL_AMI_ID=$(aws ec2 describe-images \
  --owners self \
  --filters "Name=name,Values=scale-mws-rhel-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text \
  --region us-west-2)

echo "RedHat AMI ID: $RHEL_AMI_ID"
```

**Verification Commands**:
```bash
# Check AMI exists
aws ec2 describe-images \
  --image-ids $RHEL_AMI_ID \
  --region us-west-2 \
  --query 'Images[0].[ImageId,Name,State,Tags]' \
  --output table

# Verify AMI tags
aws ec2 describe-images \
  --image-ids $RHEL_AMI_ID \
  --region us-west-2 \
  --query 'Images[0].Tags[?Key==`OS`||Key==`OS_Version`]' \
  --output table
```

### 2.2 Terraform Deployment - RedHat

**Update Terraform variables** to use RedHat AMI:

**Option A**: Update `terraform.tfvars` temporarily:
```bash
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/terraform/control

# Backup existing tfvars
cp terraform.tfvars terraform.tfvars.ubuntu.bak

# Add ami_id to force using the RedHat AMI
echo "ami_id = \"$RHEL_AMI_ID\"" >> terraform.tfvars
```

**Option B**: Pass via command line:
```bash
# Plan with RedHat AMI
terraform plan -var="ami_id=$RHEL_AMI_ID" -out=rhel.tfplan

# Apply
terraform apply rhel.tfplan
```

**Expected Results**:
- ✅ Terraform uses the RedHat AMI specified
- ✅ Creates server instances (ELB, EC2)
- ✅ Creates client Auto Scaling Group
- ✅ Outputs include: `client_lb_dns`, `server_lb_dns`

**Capture Outputs**:
```bash
# Save Terraform outputs
terraform output -json > rhel-outputs.json

# Extract key URLs
export RHEL_NOMAD_UI=$(terraform output -raw server_lb_dns):4646/ui
export RHEL_CONSUL_UI=$(terraform output -raw server_lb_dns):8500/ui
export RHEL_GRAFANA_UI=$(terraform output -raw client_lb_dns):3000
export RHEL_WEBAPP=$(terraform output -raw client_lb_dns)

echo "=== RedHat Deployment URLs ==="
echo "Nomad UI:   http://$RHEL_NOMAD_UI"
echo "Consul UI:  http://$RHEL_CONSUL_UI"
echo "Grafana:    http://$RHEL_GRAFANA_UI"
echo "Web App:    http://$RHEL_WEBAPP"
```

### 2.3 Service Validation - RedHat

**Wait for Services to Start** (2-3 minutes):
```bash
sleep 180
```

#### Test 1: Consul UI & API
```bash
# Test Consul UI accessibility
curl -I http://$(terraform output -raw server_lb_dns):8500/ui/ | head -1

# Check Consul members via API
curl -s http://$(terraform output -raw server_lb_dns):8500/v1/agent/members | jq '.[].Name'
```

**Manual Verification**:
- [ ] Open Consul UI in browser: `http://<server_lb_dns>:8500/ui`
- [ ] Verify 1+ server nodes visible
- [ ] Verify services are registering
- [ ] Check "Nodes" tab shows healthy servers

#### Test 2: Nomad UI & API
```bash
# Test Nomad UI accessibility
curl -I http://$(terraform output -raw server_lb_dns):4646/ui/ | head -1

# Check Nomad server members
curl -s http://$(terraform output -raw server_lb_dns):4646/v1/agent/members | jq '.Members[].Name'

# Check Nomad client nodes
curl -s http://$(terraform output -raw server_lb_dns):4646/v1/nodes | jq '.[] | {Name: .Name, Status: .Status}'
```

**Manual Verification**:
- [ ] Open Nomad UI in browser: `http://<server_lb_dns>:4646/ui`
- [ ] Verify server status is "ready"
- [ ] Verify client nodes are visible
- [ ] Check "Jobs" tab shows autoscaler and demo jobs running

#### Test 3: SSH into RedHat Instance
```bash
# Get a server instance IP
SERVER_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*server*" \
           "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text \
  --region us-west-2)

# SSH into server (NOTE: Use ec2-user for RedHat)
ssh -i ~/.ssh/your-key.pem ec2-user@$SERVER_IP
```

**On the instance, verify**:
```bash
# Check OS
cat /etc/os-release | grep "^ID="  # Should show: ID=rhel

# Check HOME_DIR
echo $HOME                          # Should show: /home/ec2-user

# Check package manager
which dnf                           # Should return path

# Check Docker
docker --version
docker ps
systemctl status docker             # Should be active/enabled

# Check Java
java -version
echo $JAVA_HOME                     # Should show: /usr/lib/jvm/jre-1.8.0-openjdk

# Check HashiCorp services
consul version
nomad version
systemctl status consul
systemctl status nomad

# Check logs
tail -50 /var/log/provision.log     # Should show OS Detection: RedHat

# Check docker group membership
groups | grep docker                # Should show docker in groups

# CRITICAL: Check DNS resolution (RedHat 9+ with systemd-resolved)
dig @127.0.0.1 consul.service.consul  # Should resolve
systemctl status systemd-resolved    # Should be active
systemctl status dnsmasq             # Should be active
ls -la /etc/resolv.conf              # Should be symlink to /run/systemd/resolve/resolv.conf

# Test Docker can pull images (validates DNS works)
docker pull alpine:latest            # Should succeed

# Exit
exit
```

#### Test 4: Autoscaling & Demo Jobs
```bash
# Check if autoscaler job is running
curl -s http://$(terraform output -raw server_lb_dns):4646/v1/job/autoscaler/summary | jq '.Summary'

# Check demo webapp job
curl -s http://$(terraform output -raw server_lb_dns):4646/v1/job/webapp/summary | jq '.Summary'

# Generate load
for i in {1..100}; do 
  curl -s http://$(terraform output -raw client_lb_dns) > /dev/null
  echo "Request $i"
  sleep 1
done

# Check ASG scaling
sleep 120
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(aws autoscaling describe-auto-scaling-groups \
    --query "AutoScalingGroups[?contains(AutoScalingGroupName, 'client')].AutoScalingGroupName" \
    --output text --region us-west-2) \
  --query 'AutoScalingGroups[0].[DesiredCapacity,MinSize,MaxSize]' \
  --output table \
  --region us-west-2
```

**Manual Verification**:
- [ ] Grafana dashboard shows metrics: `http://<client_lb_dns>:3000/d/AQphTqmMk/demo`
- [ ] Webapp responds: `http://<client_lb_dns>`
- [ ] Under load, ASG scales up client nodes in Nomad UI

### 2.4 Terraform Destroy - RedHat

```bash
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/terraform/control

# Destroy infrastructure
terraform destroy -auto-approve

# Wait for completion
```

**Verification**:
```bash
# Verify AMI is deleted
aws ec2 describe-images \
  --image-ids $RHEL_AMI_ID \
  --region us-west-2 2>&1 | grep -q "InvalidAMIID.NotFound" && echo "✅ AMI deleted" || echo "❌ AMI still exists"

# Verify instances are terminated
aws ec2 describe-instances \
  --filters "Name=tag:OwnerName,Values=*" \
           "Name=instance-state-name,Values=running,pending" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text \
  --region us-west-2
```

---

## Phase 3: Comparison Testing

### 3.1 Create Comparison Report

```bash
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/terraform/control

# Compare outputs
echo "=== Ubuntu vs RedHat Comparison ==="
echo ""
echo "Ubuntu Outputs:"
cat ubuntu-outputs.json | jq '.'
echo ""
echo "RedHat Outputs:"
cat rhel-outputs.json | jq '.'
```

### 3.2 Feature Parity Checklist

| Feature | Ubuntu | RedHat | Notes |
|---------|--------|--------|-------|
| Packer build succeeds | ☐ | ☐ | |
| Correct SSH user | ☐ | ☐ | ubuntu vs ec2-user |
| Correct package manager | ☐ | ☐ | apt-get vs dnf |
| Docker installed | ☐ | ☐ | |
| Docker service running | ☐ | ☐ | |
| Java installed | ☐ | ☐ | |
| Consul starts | ☐ | ☐ | |
| Nomad starts | ☐ | ☐ | |
| Consul UI accessible | ☐ | ☐ | |
| Nomad UI accessible | ☐ | ☐ | |
| Client nodes join cluster | ☐ | ☐ | |
| Demo jobs deploy | ☐ | ☐ | |
| Autoscaler works | ☐ | ☐ | |
| ASG scales on load | ☐ | ☐ | |
| Grafana shows metrics | ☐ | ☐ | |
| Webapp responds | ☐ | ☐ | |
| Terraform destroy cleans up | ☐ | ☐ | |
| AMI deleted on destroy | ☐ | ☐ | Or preserved if cleanup_ami_on_destroy=false |
| DNS resolution works | ☐ | ☐ | Critical for RedHat 9+ |
| Docker can pull images | ☐ | ☐ | Validates DNS working |

---

## Phase 4: New Features Testing

### 4.1 Test: AMI Preservation Feature

**Test cleanup_ami_on_destroy = false:**

```bash
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/terraform/control

# Update terraform.tfvars
echo 'cleanup_ami_on_destroy = false' >> terraform.tfvars

# Deploy
terraform apply -auto-approve

# Capture AMI ID
PRESERVED_AMI=$(terraform output -json | jq -r '.ami_id.value')
echo "AMI to preserve: $PRESERVED_AMI"

# Destroy
terraform destroy -auto-approve

# Verify AMI still exists
aws ec2 describe-images --image-ids $PRESERVED_AMI --region us-west-2

# Expected: AMI should still exist
```

**Test cleanup_ami_on_destroy = true (default):**

```bash
# Reset terraform.tfvars (remove or comment out cleanup_ami_on_destroy)
sed -i.bak '/cleanup_ami_on_destroy/d' terraform.tfvars

# Deploy
terraform apply -auto-approve

# Capture AMI ID
CLEANUP_AMI=$(terraform output -json | jq -r '.ami_id.value')
echo "AMI to cleanup: $CLEANUP_AMI"

# Destroy
terraform destroy -auto-approve

# Verify AMI is deleted
aws ec2 describe-images --image-ids $CLEANUP_AMI --region us-west-2 2>&1 | grep "InvalidAMIID.NotFound"

# Expected: AMI should be deregistered
```

### 4.2 Test: Region Configuration

**Verify all scripts read region from terraform.tfvars:**

```bash
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws

# Check quick-test.sh
bash -c 'REPO_ROOT="$(pwd)"; TERRAFORM_DIR="$REPO_ROOT/terraform/control"; REGION=$(grep "^region" "$TERRAFORM_DIR/terraform.tfvars" | sed '\''s/region[[:space:]]*=[[:space:]]*"\(.*\)"/\1/'\'' | tr -d " "); echo "quick-test.sh detected region: $REGION"'

# Check pre-flight-check.sh
bash pre-flight-check.sh | grep "Region:"

# Check verify-deployment.sh
cd terraform/control
bash ../../verify-deployment.sh | grep "Region:"

# Expected: All scripts should show the same region from terraform.tfvars
```

### 4.3 Test: RedHat DNS Resolution (systemd-resolved)

**Verify DNS fix on RedHat 9+:**

```bash
# After deploying RedHat infrastructure
SERVER_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*server*" \
           "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text \
  --region us-west-2)

ssh -i ~/.ssh/your-key.pem ec2-user@$SERVER_IP << 'EOF'
# Check systemd-resolved is active
systemctl is-active systemd-resolved

# Check resolv.conf is properly configured
ls -la /etc/resolv.conf | grep "/run/systemd/resolve/resolv.conf"

# Test .consul domain resolution
dig @127.0.0.1 consul.service.consul

# Test Docker can resolve and pull
docker pull alpine:latest

# Check provision log for DNS setup
grep -i "systemd-resolved\|DNS\|resolv.conf" /var/log/provision.log

echo "✅ DNS resolution test passed"
EOF
```

---

## Phase 5: Edge Cases & Error Scenarios

### 5.1 Test: Invalid OS Variable
```bash
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/packer

# Try to build with invalid OS
packer build -var 'os=CentOS' .

# Expected: Should fail with error message about unsupported OS
```

### 5.2 Test: Mixed OS Deployment (Not Supported)
```bash
# Build Ubuntu AMI
packer build -var 'os=Ubuntu' .

# Build RedHat AMI
packer build -var 'os=RedHat' -var 'name_prefix=test-mixed' .

# Try to deploy - Terraform should pick one consistently
# This tests that the deployment doesn't mix OS types
```

### 4.3 Test: Packer Rebuild Trigger
```bash
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/terraform/control

# Remove AMI manually
aws ec2 deregister-image --image-id $UBUNTU_AMI_ID --region us-west-2

# Run terraform plan
terraform plan

# Expected: Should trigger new Packer build automatically
```

---

## Test Results Documentation

### Test Execution Log Template

```markdown
## Test Execution: [Date]
**Tester**: [Name]
**Environment**: AWS us-west-2
**Versions**: 
- Packer: [version]
- Terraform: [version]
- Consul: [version]
- Nomad: [version]

### Ubuntu Test Results
- Packer Build: [PASS/FAIL] - Duration: [X min]
- Terraform Apply: [PASS/FAIL] - Duration: [X min]
- Consul UI: [PASS/FAIL]
- Nomad UI: [PASS/FAIL]
- SSH Access: [PASS/FAIL] - User: ubuntu
- Autoscaling: [PASS/FAIL]
- Terraform Destroy: [PASS/FAIL] - Duration: [X min]
- **Notes**: [Any observations]

### RedHat Test Results
- Packer Build: [PASS/FAIL] - Duration: [X min]
- Terraform Apply: [PASS/FAIL] - Duration: [X min]
- Consul UI: [PASS/FAIL]
- Nomad UI: [PASS/FAIL]
- SSH Access: [PASS/FAIL] - User: ec2-user
- Autoscaling: [PASS/FAIL]
- Terraform Destroy: [PASS/FAIL] - Duration: [X min]
- **Notes**: [Any observations]

### Issues Found
1. [Issue description]
   - **Severity**: [Critical/High/Medium/Low]
   - **OS Affected**: [Ubuntu/RedHat/Both]
   - **Workaround**: [If any]

### Recommendations
- [Any recommendations from testing]
```

---

## Automated Testing Script

Create a test automation script:

```bash
#!/bin/bash
# File: test-multi-os.sh
# Usage: ./test-multi-os.sh [ubuntu|redhat|both]

set -e

TEST_OS="${1:-both}"
REGION="us-west-2"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="test-${TEST_OS}-${TIMESTAMP}.log"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

test_ubuntu() {
  log "=== Starting Ubuntu Test ==="
  
  cd aws/packer
  log "Building Ubuntu AMI..."
  source env-pkr-var.sh
  packer init .
  packer build . | tee -a "$LOG_FILE"
  
  UBUNTU_AMI=$(aws ec2 describe-images \
    --owners self \
    --filters "Name=name,Values=scale-mws-*" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text --region $REGION)
  log "Ubuntu AMI: $UBUNTU_AMI"
  
  cd ../terraform/control
  log "Deploying Ubuntu infrastructure..."
  terraform init
  terraform apply -auto-approve | tee -a "$LOG_FILE"
  
  log "Waiting for services to start..."
  sleep 180
  
  SERVER_LB=$(terraform output -raw server_lb_dns)
  log "Testing Consul UI: http://$SERVER_LB:8500/ui/"
  curl -f -I "http://$SERVER_LB:8500/ui/" || log "ERROR: Consul UI not accessible"
  
  log "Testing Nomad UI: http://$SERVER_LB:4646/ui/"
  curl -f -I "http://$SERVER_LB:4646/ui/" || log "ERROR: Nomad UI not accessible"
  
  log "Destroying Ubuntu infrastructure..."
  terraform destroy -auto-approve | tee -a "$LOG_FILE"
  
  log "=== Ubuntu Test Complete ==="
}

test_redhat() {
  log "=== Starting RedHat Test ==="
  
  cd aws/packer
  log "Building RedHat AMI..."
  source env-pkr-var.sh
  packer init .
  packer build \
    -var 'os=RedHat' \
    -var 'os_version=9.6.0' \
    -var 'os_name=' \
    -var 'name_prefix=scale-mws-rhel' \
    . | tee -a "$LOG_FILE"
  
  RHEL_AMI=$(aws ec2 describe-images \
    --owners self \
    --filters "Name=name,Values=scale-mws-rhel-*" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text --region $REGION)
  log "RedHat AMI: $RHEL_AMI"
  
  cd ../terraform/control
  log "Deploying RedHat infrastructure..."
  terraform init
  terraform apply -var="ami_id=$RHEL_AMI" -auto-approve | tee -a "$LOG_FILE"
  
  log "Waiting for services to start..."
  sleep 180
  
  SERVER_LB=$(terraform output -raw server_lb_dns)
  log "Testing Consul UI: http://$SERVER_LB:8500/ui/"
  curl -f -I "http://$SERVER_LB:8500/ui/" || log "ERROR: Consul UI not accessible"
  
  log "Testing Nomad UI: http://$SERVER_LB:4646/ui/"
  curl -f -I "http://$SERVER_LB:4646/ui/" || log "ERROR: Nomad UI not accessible"
  
  log "Destroying RedHat infrastructure..."
  terraform destroy -auto-approve | tee -a "$LOG_FILE"
  
  log "=== RedHat Test Complete ==="
}

case $TEST_OS in
  ubuntu)
    test_ubuntu
    ;;
  redhat)
    test_redhat
    ;;
  both)
    test_ubuntu
    sleep 60
    test_redhat
    ;;
  *)
    echo "Usage: $0 [ubuntu|redhat|both]"
    exit 1
    ;;
esac

log "All tests complete. Log saved to: $LOG_FILE"
```

---

## Success Criteria

### Critical (Must Pass)
- ✅ Both Ubuntu and RedHat Packer builds complete successfully
- ✅ Terraform deploys infrastructure using both AMI types
- ✅ Consul UI accessible on both OS types
- ✅ Nomad UI accessible on both OS types
- ✅ SSH access works with correct username (ubuntu/ec2-user)
- ✅ Terraform destroy removes both AMIs and instances

### Important (Should Pass)
- ✅ Demo jobs deploy and run on both OS types
- ✅ Autoscaler functions correctly on both OS types
- ✅ Docker containers run on both OS types
- ✅ Grafana displays metrics on both OS types

### Nice to Have (May Vary)
- ⚪ Performance parity between Ubuntu and RedHat
- ⚪ Similar build times for both OS types
- ⚪ Cost comparison documented

---

## Troubleshooting Common Issues

### Issue: Packer build fails for RedHat
**Check**:
- Verify AMI exists in region: `aws ec2 describe-images --owners 309956199498 --filters "Name=name,Values=RHEL-9.6.0*" --region us-west-2`
- Check SSH connectivity with ec2-user
- Review `/var/log/provision.log` on failed instance

### Issue: Terraform doesn't trigger Packer rebuild
**Check**:
- Verify AMI ID in tfvars
- Check `data.external.ami_check` output
- Manually deregister AMI and retry

### Issue: Services don't start on RedHat
**Check**:
- SELinux may block services: `sudo setenforce 0` (temporary)
- Firewall rules: `sudo systemctl status firewalld`
- Check systemd logs: `sudo journalctl -u consul -u nomad`

### Issue: Docker not accessible
**RedHat**: Verify ec2-user in docker group and service running
**Ubuntu**: Verify docker service started

---

## Sign-off Checklist

Before considering testing complete:

- [ ] Both OS types tested in same AWS region
- [ ] All UIs accessible for both OS types
- [ ] SSH access verified with correct usernames
- [ ] Provisioning logs reviewed for both builds
- [ ] Terraform destroy verified cleanup for both
- [ ] Documentation updated with any findings
- [ ] Screenshots captured for both UIs
- [ ] Performance notes documented
- [ ] Cost comparison documented

**Test Sign-off**:
- Tester: _______________
- Date: _______________
- Result: PASS / FAIL (with notes)
