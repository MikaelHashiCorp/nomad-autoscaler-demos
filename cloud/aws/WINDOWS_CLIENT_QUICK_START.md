# Windows Client Quick Start Guide

## Overview

This guide provides quick instructions for deploying HashiStack clusters with Windows clients.

## Prerequisites

- AWS CLI configured
- Packer installed
- Terraform installed
- SSH key pair in AWS
- Sufficient AWS quotas

## Deployment Scenarios

### Scenario 1: Linux-Only (Default - No Changes Needed)

```hcl
# terraform.tfvars
server_count = 1
client_count = 3
windows_client_count = 0  # Default
```

**Result:** Traditional all-Linux deployment

### Scenario 2: Windows-Only Clients

```hcl
# terraform.tfvars
server_count = 1
client_count = 0              # No Linux clients
windows_client_count = 3      # Windows clients only
windows_client_instance_type = "t3a.xlarge"
```

**Result:** Linux servers + Windows clients

### Scenario 3: Mixed OS (Linux + Windows)

```hcl
# terraform.tfvars
server_count = 1
client_count = 2              # Linux clients
windows_client_count = 2      # Windows clients
windows_client_instance_type = "t3a.xlarge"
```

**Result:** Linux servers + both client types

## Quick Deploy

```bash
cd terraform/control

# Copy sample config
cp terraform.tfvars.sample terraform.tfvars

# Edit terraform.tfvars with your settings
# Set windows_client_count > 0 to enable Windows clients

# Deploy
terraform init
terraform plan
terraform apply
```

## AMI Management

### Auto-Build (Default)
Leave `windows_ami = ""` in terraform.tfvars. Terraform will automatically build Windows AMI when `windows_client_count > 0`.

### Use Existing AMI
```hcl
windows_ami = "ami-xxxxx"  # Your pre-built Windows AMI
```

### Preserve AMIs on Destroy
```hcl
cleanup_ami_on_destroy = false
```

## Job Targeting

### Target Windows Clients
```hcl
job "windows-app" {
  constraint {
    attribute = "${attr.kernel.name}"
    value     = "windows"
  }
  # ... rest of job
}
```

### Target Linux Clients
```hcl
job "linux-app" {
  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }
  # ... rest of job
}
```

### Target by Node Class
```hcl
job "specific-app" {
  constraint {
    attribute = "${node.class}"
    value     = "hashistack-windows"  # or "hashistack-linux"
  }
  # ... rest of job
}
```

## Verification Commands

### Check Cluster Status
```bash
export NOMAD_ADDR=$(terraform output -raw nomad_addr)
nomad node status
```

### List Windows Nodes
```bash
nomad node status -json | jq -r '.[] | select(.NodeClass=="hashistack-windows") | [.ID, .Name, .Status] | @tsv'
```

### List Linux Nodes
```bash
nomad node status -json | jq -r '.[] | select(.NodeClass=="hashistack-linux") | [.ID, .Name, .Status] | @tsv'
```

### Check ASGs
```bash
aws autoscaling describe-auto-scaling-groups \
  --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `client`)].{Name:AutoScalingGroupName,Desired:DesiredCapacity,Current:Instances|length(@)}' \
  --output table
```

### Check AMIs
```bash
aws ec2 describe-images \
  --owners self \
  --filters "Name=name,Values=*-windows-*" \
  --query 'Images[*].[ImageId,Name,CreationDate]' \
  --output table
```

## Troubleshooting

### Windows Clients Not Joining Cluster

1. Check Windows instance logs:
```bash
# Get Windows instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*-client-windows" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

# Get console output
aws ec2 get-console-output --instance-id $INSTANCE_ID
```

2. Verify security groups allow Consul/Nomad ports
3. Check Windows AMI has HashiStack components installed

### Windows AMI Build Fails

1. Check Packer logs: `packer.log`
2. Verify WinRM connectivity during build
3. Ensure Windows base AMI is available in your region
4. Check AWS quotas for Windows instances

### Mixed OS Jobs Not Scheduling

1. Verify node classes are correct:
```bash
nomad node status -verbose <node-id> | grep node.class
```

2. Check job constraints match node attributes
3. Verify both client types are healthy

## Cost Optimization

- **Windows instances cost more** than Linux (licensing + larger instance types)
- Use `windows_client_count = 0` when not needed
- Consider spot instances for dev/test environments
- Set `cleanup_ami_on_destroy = true` to avoid AMI storage costs

## Best Practices

1. **Start with Linux-only** to validate infrastructure
2. **Test Windows separately** before mixed deployments
3. **Use node classes** for job targeting (more flexible than OS constraints)
4. **Monitor costs** - Windows instances are more expensive
5. **Keep servers Linux** - optimal for HashiStack
6. **Use t3a.xlarge or larger** for Windows clients (minimum recommended)

## Common Configurations

### Development (Minimal Cost)
```hcl
server_count = 1
client_count = 1
windows_client_count = 1
windows_client_instance_type = "t3a.xlarge"
```

### Testing (Mixed Workloads)
```hcl
server_count = 1
client_count = 2
windows_client_count = 2
windows_client_instance_type = "t3a.xlarge"
```

### Production (High Availability)
```hcl
server_count = 3
client_count = 5
windows_client_count = 3
windows_client_instance_type = "t3.large"
```

## Next Steps

1. Review [`WINDOWS_CLIENT_ARCHITECTURE.md`](WINDOWS_CLIENT_ARCHITECTURE.md:1) for design details
2. Follow [`TESTING_PLAN.md`](TESTING_PLAN.md:1) Phase 4 for comprehensive testing
3. See [`WINDOWS_CLIENT_IMPLEMENTATION.md`](WINDOWS_CLIENT_IMPLEMENTATION.md:1) for implementation details

## Support

- Architecture questions: See `WINDOWS_CLIENT_ARCHITECTURE.md`
- Testing procedures: See `TESTING_PLAN.md`
- Implementation details: See `WINDOWS_CLIENT_IMPLEMENTATION.md`
- Task requirements: See `TASK_REQUIREMENTS.md`