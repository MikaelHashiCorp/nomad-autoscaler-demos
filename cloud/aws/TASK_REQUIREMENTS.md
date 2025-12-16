# Task Requirements: Windows Client Support for Terraform Deployment

## Objective

Modify the terraform deployment to support Windows clients alongside Linux clients, with full AWS autoscaling capabilities.

## Requirements

### Terraform Configuration Updates

- Update `terraform.tfvars` with the following new variables:
  - `windows_client_instance_type`
  - `windows_client_count`
  - `windows_ami`

### AMI Management

- AWS will create two AMIs on-the-fly:
  - One for Windows
  - One for Linux
- Both AMIs will be used for creating requested instances from `terraform.tfvars`
- AMIs will be linked via HCL configurations for Nomad and Consul operations as:
  - Nomad Servers
  - Nomad Clients
  - Consul Servers
  - Consul Clients

### Variable Management

- `terraform.tfvars` - Primary source of truth for variables
- `variables.pkr.hcl` - Secondary source of truth for variables

### Cleanup Behavior

- When `terraform destroy` is run:
  - Delete the Linux AMI (current behavior)
  - Delete the Windows AMI (new requirement)

### AMI Selection

- The same options for default and select AMI that apply to Linux AMI should also apply to Windows AMI

## Documentation Updates

- Refresh memory from:
  - `copilot-instructions.md` (for any LLM)
  - `bob-instructions.md` (specific to Bob IBM IDE)
- Update both instruction files with lessons learned
- Note: `logcmd` is only needed in `bob-instructions.md`, not `copilot-instructions.md`, as Copilot handles executions differently

## Open Question

**How do we handle both Linux client autoscaling and Windows client autoscaling?**

This requires architectural consideration for managing two separate autoscaling groups with different operating systems while maintaining integration with Nomad and Consul.