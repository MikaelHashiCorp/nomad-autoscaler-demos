# Testing Plan: Multi-OS Support (Ubuntu, RedHat & Windows Clients)

## Overview

This document outlines the comprehensive testing strategy to validate that Ubuntu, RedHat, and Windows builds work correctly with the Packer → Terraform → HashiStack deployment pipeline. This includes testing mixed OS deployments with Linux servers and flexible client configurations.

## Test Objectives

### Linux Server & Client Testing
1. ✅ Verify Packer builds succeed for both Ubuntu and RedHat
2. ✅ Verify Terraform can deploy infrastructure using both AMI types
3. ✅ Verify HashiStack services (Consul, Nomad, Vault) function correctly on both OS types
4. ✅ Verify autoscaling and demo workloads operate correctly
5. ✅ Verify cleanup process removes both AMIs and instances (or preserves them based on configuration)
6. ✅ Verify DNS resolution works on both OS types, especially RedHat 9+ with systemd-resolved
7. ✅ Verify region configuration is read from terraform.tfvars in all scripts

### Windows Client Testing (New)
8. ⏳ Verify Packer builds succeed for Windows Server 2022
9. ⏳ Verify Windows clients can join Linux-based HashiStack cluster
10. ⏳ Verify mixed OS deployments (Linux + Windows clients simultaneously)
11. ⏳ Verify Windows-specific autoscaling
12. ⏳ Verify job targeting via OS constraints
13. ⏳ Verify dual AMI cleanup on terraform destroy

### Current Focus: Windows Server 2016 KB Validation (Builds 21-26)
14. ⏳ Verify Windows Server 2016 AMI builds successfully
15. ⏳ Validate KB article: Desktop heap exhaustion at ~20-25 allocations
16. ⏳ Test desktop heap fix (768 KB → 4096 KB)
17. ⏳ Verify version compatibility between server and Windows clients
18. ⏳ Document lessons learned from build failures

**Current Goal**: Deploy Windows Server 2016 infrastructure to validate KB article `1-KB-Nomad-Alloc-Fail-On-Windows.md` which documents desktop heap exhaustion causing Nomad clients to fail after ~20-25 allocations.

**Target Architecture**:
- 1 Linux Server (Ubuntu 24.04) - Nomad 1.11.1
- 1 Linux Client (Ubuntu 24.04) - For infrastructure jobs (traefik, grafana, prometheus, webapp)
- 1 Windows Client (Windows Server 2016) - For KB validation testing

## Critical Success Criteria

### Deployment Success Requirements
A deployment is considered **SUCCESSFUL** only when ALL of the following conditions are met:

1. **All ASGs have appropriate capacity**:
   - Linux client ASG: desired ≥ 1 (if Linux workloads expected)
   - Windows client ASG: desired ≥ 1 (if Windows workloads expected)

2. **All expected nodes join cluster within 5 minutes**:
   - Linux server nodes
   - Linux client nodes (if configured)
   - Windows client nodes (if configured)

3. **All infrastructure jobs reach "running" status within 5 minutes**:
   - `traefik`: must be "running"
   - `grafana`: must be "running"
   - `prometheus`: must be "running"
   - `webapp`: must be "running"

4. **Job Status Validation**:
   ```bash
   nomad job status
   # ALL jobs must show Status: running
   # NO jobs should be in "pending" state after 5 minutes
   ```

### 5-Minute Rule
**CRITICAL**: If any infrastructure job remains in "pending" state for more than 5 minutes after deployment, the deployment has **FAILED** and must be investigated.

Common causes of pending jobs:
- Missing client nodes (ASG desired capacity = 0)
- Node constraints not met (wrong OS, insufficient resources)
- Service failures preventing node registration

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

---

## Phase 4: Windows Client Testing

### 4.1 Windows AMI Build Test

**Location**: `aws/packer/`

```bash
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-win-bob/cloud/aws/packer

# Clean any previous builds
rm -f packer.log
rm -f .cleanup-*

# Set environment variables
source env-pkr-var.sh

# Build Windows AMI
packer build -var-file=windows-2022.pkrvars.hcl .
```

**Expected Results**:
- ✅ Packer build completes successfully (may take 30-45 minutes)
- ✅ AMI created with name: `scale-mws-windows-<timestamp>`
- ✅ AMI tags include: OS=Windows, OS_Version=2022
- ✅ HashiStack components installed in `C:\HashiCorp\bin\`
- ✅ Docker service installed and configured
- ✅ WinRM communication successful during build

**Verification**:
```bash
# Save the Windows AMI ID
export WINDOWS_AMI_ID=$(aws ec2 describe-images \
  --owners self \
  --filters "Name=name,Values=*-windows-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text \
  --region us-west-2)

echo "Windows AMI ID: $WINDOWS_AMI_ID"

# Verify AMI details
aws ec2 describe-images \
  --image-ids $WINDOWS_AMI_ID \
  --region us-west-2 \
  --query 'Images[0].[ImageId,Name,State,Platform,Tags]' \
  --output table
```

### 4.2 Windows-Only Client Deployment

**Location**: `aws/terraform/control/`

**Test Configuration** (`terraform.tfvars`):
```hcl
region             = "us-west-2"
availability_zones = ["us-west-2a"]
key_name           = "my-dev-ec2-keypair"
owner_name         = "test-user"
owner_email        = "test@example.com"
stack_name         = "win-test"

# Linux servers only
server_count = 1
client_count = 0  # No Linux clients

# Windows clients only
windows_client_count = 2
windows_client_instance_type = "t3a.xlarge"
# windows_ami = ""  # Leave empty to auto-build
```

**Deploy**:
```bash
cd /Users/mikael/2-git/repro/nomad-autoscaler-demos/1-win-bob/cloud/aws/terraform/control

terraform init
terraform plan
terraform apply -auto-approve
```

**Expected Results**:
- ✅ Linux AMI built automatically (for servers)
- ✅ Windows AMI built automatically (for clients)
- ✅ 1 Linux server instance created
- ✅ 2 Windows client instances created via ASG
- ✅ Both AMIs tagged correctly
- ✅ Resources named with `-linux` and `-windows` suffixes

**Verification**:
```bash
# Check instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=win-test-*" \
  --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name,Platform]' \
  --output table

# Verify ASGs
aws autoscaling describe-auto-scaling-groups \
  --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `win-test`)].{Name:AutoScalingGroupName,Desired:DesiredCapacity,Current:Instances|length(@)}' \
  --output table
```

### 4.3 Mixed OS Deployment (Linux + Windows Clients)

**Test Configuration** (`terraform.tfvars`):
```hcl
region             = "us-west-2"
availability_zones = ["us-west-2a"]
key_name           = "my-dev-ec2-keypair"
owner_name         = "test-user"
owner_email        = "test@example.com"
stack_name         = "mixed-test"

# Linux infrastructure
server_count = 1
client_count = 2  # Linux clients

# Windows clients
windows_client_count = 2
windows_client_instance_type = "t3a.xlarge"
```

**Deploy**:
```bash
terraform apply -auto-approve
```

**Expected Results**:
- ✅ 2 AMIs built (Linux and Windows)
- ✅ 1 Linux server
- ✅ 2 Linux clients (via linux ASG)
- ✅ 2 Windows clients (via windows ASG)
- ✅ Total: 5 instances (1 server + 4 clients)

### 4.4 Service Validation - Windows Clients

#### Test 1: Verify Windows Clients Join Cluster

```bash
# Get Nomad server address
export NOMAD_ADDR=$(terraform output -raw nomad_addr)

# List all clients
nomad node status

# Expected output should show both Linux and Windows nodes
# Look for node class: hashistack-linux and hashistack-windows
```

**Expected Results**:
- ✅ All Windows clients appear in `nomad node status`
- ✅ Node class is `hashistack-windows`
- ✅ Status is `ready`
- ✅ Consul and Nomad services running

#### Test 2: Verify Node Attributes

```bash
# Get a Windows node ID
WINDOWS_NODE=$(nomad node status -json | jq -r '.[] | select(.NodeClass=="hashistack-windows") | .ID' | head -1)

# Inspect Windows node
nomad node status $WINDOWS_NODE

# Check attributes
nomad node status -verbose $WINDOWS_NODE | grep -i "kernel.name\|os.name"
```

**Expected Results**:
- ✅ `kernel.name = windows`
- ✅ `os.name = Windows Server 2022`
- ✅ Docker driver available
- ✅ Correct node class

#### Test 3: Deploy Windows-Targeted Job

Create `test-windows-job.nomad`:
```hcl
job "windows-test" {
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "windows"
  }

  group "test" {
    count = 1

    task "powershell" {
      driver = "exec"

      config {
        command = "powershell.exe"
        args    = ["-Command", "while($true) { Write-Host 'Windows task running'; Start-Sleep -Seconds 10 }"]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
```

**Deploy**:
```bash
nomad job run test-windows-job.nomad
nomad job status windows-test
nomad alloc logs <alloc-id>
```

**Expected Results**:
- ✅ Job placed on Windows node only
- ✅ Allocation running successfully
- ✅ Logs show "Windows task running"

#### Test 4: Deploy Linux-Targeted Job

Create `test-linux-job.nomad`:
```hcl
job "linux-test" {
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }

  group "test" {
    count = 1

    task "bash" {
      driver = "exec"

      config {
        command = "bash"
        args    = ["-c", "while true; do echo 'Linux task running'; sleep 10; done"]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
```

**Deploy**:
```bash
nomad job run test-linux-job.nomad
nomad job status linux-test
```

**Expected Results**:
- ✅ Job placed on Linux node only
- ✅ Does NOT run on Windows nodes
- ✅ Allocation running successfully

### 4.5 Windows Autoscaling Test

**Trigger Scale-Up**:
```bash
# Deploy multiple Windows jobs to trigger autoscaling
for i in {1..5}; do
  nomad job run -detach test-windows-job.nomad
done

# Monitor ASG
watch -n 5 'aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names mixed-test-client-windows \
  --query "AutoScalingGroups[0].{Desired:DesiredCapacity,Current:Instances|length(@),Min:MinSize,Max:MaxSize}"'
```

**Expected Results**:
- ✅ Windows ASG scales up based on demand
- ✅ New Windows instances join cluster automatically
- ✅ Jobs are placed on new instances
- ✅ Linux ASG remains unchanged

### 4.6 Dual AMI Cleanup Test

```bash
# Capture AMI IDs before destroy
export LINUX_AMI=$(terraform output -raw ami_id 2>/dev/null || echo "")
export WINDOWS_AMI=$(aws ec2 describe-images \
  --owners self \
  --filters "Name=name,Values=*-windows-*" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text)

echo "Linux AMI: $LINUX_AMI"
echo "Windows AMI: $WINDOWS_AMI"

# Destroy infrastructure
terraform destroy -auto-approve

# Wait for cleanup
sleep 30

# Verify both AMIs are deregistered
aws ec2 describe-images --image-ids $LINUX_AMI --region us-west-2 2>&1 | grep -q "InvalidAMIID.NotFound" && echo "✅ Linux AMI cleaned up" || echo "❌ Linux AMI still exists"

aws ec2 describe-images --image-ids $WINDOWS_AMI --region us-west-2 2>&1 | grep -q "InvalidAMIID.NotFound" && echo "✅ Windows AMI cleaned up" || echo "❌ Windows AMI still exists"
```

**Expected Results**:
- ✅ All instances terminated
- ✅ Both ASGs deleted
- ✅ Linux AMI deregistered
- ✅ Windows AMI deregistered
- ✅ Both snapshots deleted
- ✅ No orphaned resources

### 4.7 Edge Cases - Windows

#### Test: Windows-Only with Existing AMI

```hcl
# terraform.tfvars
windows_ami = "ami-xxxxx"  # Specify existing Windows AMI
windows_client_count = 2
client_count = 0
```

**Expected Results**:
- ✅ No Windows AMI build triggered
- ✅ Uses specified AMI
- ✅ Deployment succeeds

#### Test: Zero Windows Clients

```hcl
# terraform.tfvars
windows_client_count = 0
client_count = 2
```

**Expected Results**:
- ✅ No Windows AMI built
- ✅ No Windows ASG created
- ✅ Only Linux resources created
- ✅ Backward compatible behavior

#### Test: Invalid Windows AMI

```hcl
# terraform.tfvars
windows_ami = "ami-invalid"
windows_client_count = 1
```

**Expected Results**:
- ✅ Terraform plan fails with clear error
- ✅ No resources created
- ✅ Error message indicates invalid AMI

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


## Lessons Learned: Builds 21-25

### Build History Summary

#### Build 20 ✅ SUCCESS
- **Status**: Successful deployment with Bug #17 and Bug #18 fixes
- **Configuration**: Ubuntu 24.04 server + clients, Nomad 1.11.1
- **Key Achievement**: Docker service starts automatically, version compatibility confirmed

#### Build 21 ❌ FAILED - Version Mismatch Redux
- **Issue**: Windows client had Nomad 1.10.5, server had 1.11.1
- **Root Cause**: Packer configuration had environment variables "intentionally removed"
- **Impact**: Windows client couldn't join cluster (RPC protocol incompatibility)
- **Lesson**: Always verify version compatibility between server and clients

#### Build 22 ❌ FAILED - Missing User-Data Template
- **Issue**: File `terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1` not found
- **Root Cause**: Template file was never created during Windows implementation
- **Fix**: Created Windows user-data template with logging and EC2Launch v2 documentation
- **Lesson**: Verify all referenced files exist before deployment

#### Build 23 ❌ FAILED - Missing Environment Variables
- **Issue**: Linux build failed with "CNIVERSION: unbound variable"
- **Root Cause**: CNIVERSION not included in environment_vars list for shell provisioner
- **Fix**: Added CNIVERSION to environment_vars parameter
- **Lesson**: Both shell and PowerShell provisioners need explicit environment_vars in Packer

#### Build 24 ❌ FAILED - Windows SCP Path Error
- **Issue**: `scp: c:/Windows/Temp: No such file or directory`
- **Root Cause**: Packer's PowerShell provisioner with environment_vars tries to upload temp script to non-existent path
- **Fix**: Changed from environment_vars to inline script that sets variables and calls setup script
- **Lesson**: Packer's environment_vars parameter has platform-specific issues on Windows

#### Build 25 ⚠️ PARTIAL SUCCESS - Wrong Versions
- **Linux AMI**: ✅ Created successfully (ami-0a91d5b822ca3c233)
- **Windows AMI**: ✅ Created successfully (ami-06ee351ed56954425)
- **Issue**: Both AMIs have wrong versions (Nomad 1.10.5 instead of 1.11.1)
- **Root Cause**: Missing `source env-pkr-var.sh &&` in terraform/modules/aws-nomad-image/image.tf
- **Impact**: Packer used hardcoded defaults instead of fetching from HashiCorp APIs
- **Lesson**: Always verify the complete command chain when refactoring

### Critical Lessons Learned

#### 1. Environment Variable Inheritance in Packer
**Problem**: Bash environment variables don't automatically pass to Packer provisioners.

**Solution**: Must explicitly use `environment_vars` parameter for BOTH shell and PowerShell provisioners:
```hcl
provisioner "shell" {
  script = "setup.sh"
  environment_vars = [
    "CONSULVERSION=${var.consul_version}",
    "NOMADVERSION=${var.nomad_version}",
    "VAULTVERSION=${var.vault_version}",
    "CNIVERSION=${var.cni_version}"
  ]
}
```

**Exception**: Windows PowerShell provisioner with environment_vars has SCP path issues. Use inline script instead:
```hcl
provisioner "powershell" {
  inline = [
    "$env:NOMADVERSION = '${var.nomad_version}'",
    "& C:\\ops\\scripts\\setup-windows.ps1"
  ]
}
```

#### 2. Version Management Strategy
**Problem**: Multiple version sources causing confusion and drift.

**Version Sources**:
1. `env-pkr-var.sh` - Fetches latest from HashiCorp APIs (dynamic)
2. `packer/variables.pkr.hcl` - Hardcoded defaults (static fallback)
3. Terraform variables - Can override Packer variables (optional)

**Best Practice**: Use `source env-pkr-var.sh` in Terraform's local-exec provisioner to ensure consistent versions across all builds.

**Critical**: The command must be:
```bash
source env-pkr-var.sh && packer build ...
```
NOT just:
```bash
packer build ...
```

#### 3. Infrastructure Job Requirements
**Problem**: Infrastructure jobs (traefik, grafana, prometheus, webapp) remained in "pending" state.

**Root Cause**: These jobs use Docker Linux containers and require Linux clients. Setting `client_count = 0` causes jobs to never run.

**Solution**: Always maintain at least 1 Linux client for infrastructure jobs:
```hcl
server_count = 1              # Linux server
client_count = 1              # Linux client (for infrastructure jobs)
windows_client_count = 1      # Windows client (for Windows workloads)
```

#### 4. Due Diligence Process
**Problem**: Initial hypothesis about PowerShell environment variable inheritance was wrong.

**Correct Process**:
1. ✅ Check build logs for actual evidence
2. ✅ Compare current vs. working version in git history
3. ✅ Verify assumptions with data before proposing solutions
4. ✅ Document findings with evidence

**Key Insight**: Build logs contained the truth all along - environment variables WERE being passed correctly to scripts. The real issue was that wrong values were set at the Packer level.

#### 5. Terraform State Management
**Problem**: Orphaned resources (ELBs) blocking security group deletion.

**Solution**: Manually clean up orphaned resources:
```bash
aws elb delete-load-balancer --load-balancer-name <name> --region <region>
```

**Prevention**: Use `terraform destroy` carefully and verify all resources are removed.

#### 6. Git Merge Conflict Resolution
**Problem**: Merge conflict markers in code causing syntax errors.

**Solution**: Always escape conflict markers in apply_diff:
```
\<<<<<<< Updated upstream
\=======
\>>>>>>> Stashed changes
```

**Prevention**: Resolve conflicts properly before committing, use git status to check for unresolved conflicts.

### Testing Best Practices

#### Pre-Deployment Checklist
Before running `terraform apply`:
1. ✅ Verify terraform.tfvars configuration
   - server_count ≥ 1
   - client_count ≥ 1 (for infrastructure jobs)
   - windows_client_count as needed
2. ✅ Verify image.tf has `source env-pkr-var.sh &&`
3. ✅ Check for merge conflicts in code
4. ✅ Review bob-instructions.md for command format
5. ✅ Verify all referenced files exist

#### Post-Deployment Verification
After `terraform apply` completes:
1. ✅ Check all nodes joined cluster: `nomad node status`
2. ✅ Verify versions match: `nomad node status -json <ID> | jq '.Attributes["nomad.version"]'`
3. ✅ Check job status: `nomad job status` (all should be "running" within 5 minutes)
4. ✅ Verify ASG desired capacity matches configuration
5. ✅ Check for any "pending" jobs and investigate immediately

#### Build Failure Response
When a build fails:
1. ✅ Check build logs for error messages
2. ✅ Verify all fixes were applied
3. ✅ Compare with last working version
4. ✅ Document the failure and root cause
5. ✅ Test fix in isolation if possible
6. ✅ Update documentation with lessons learned

### Version Compatibility Matrix

| Component | Build 20 | Build 25 | Current API |
|-----------|----------|----------|-------------|
| Consul    | 1.22.2   | 1.21.4   | 1.21.4      |
| Nomad     | 1.11.1   | 1.10.5   | 1.10.5      |
| Vault     | 1.21.1   | 1.20.3   | 1.20.3      |
| CNI       | v1.9.0   | v1.8.0   | v1.8.0      |

**Note**: API versions change over time. Build 20 used versions from an earlier API fetch. Build 25 used current API versions (via hardcoded defaults that happened to match).

### Next Steps for Build 26

1. ⏳ Fix terraform.tfvars: `client_count = 1`
2. ⏳ Fix image.tf: Add `source env-pkr-var.sh &&`
3. ⏳ Destroy Build 25 infrastructure
4. ⏳ Deploy Build 26 with corrected configuration
5. ⏳ Verify all nodes join cluster with matching versions
6. ⏳ Verify all infrastructure jobs reach "running" status
7. ⏳ Proceed with Windows Server 2016 KB validation testing

### Documentation Updates

New documentation created during Builds 21-25:
- `BUILD_25_STATUS.md` - Build 25 results and analysis
- `BUILD_25_ROOT_CAUSE_ANALYSIS.md` - Complete root cause investigation
- `BUILD_26_PREFLIGHT_CHECKLIST.md` - Pre-flight checklist for Build 26
- `TESTING_PLAN.md` (this file) - Updated with current goals and lessons learned

### Success Metrics

**Build Success Rate**: 1/5 (20%) for Builds 21-25
- Build 21: ❌ Version mismatch
- Build 22: ❌ Missing template
- Build 23: ❌ Missing env var
- Build 24: ❌ SCP path error
- Build 25: ⚠️ Wrong versions

**Key Improvements Needed**:
- Better pre-flight validation
- Automated version verification
- Comprehensive testing before deployment
- Documentation of all configuration dependencies

**Target for Build 26**: 100% success rate with all fixes applied and verified.
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
