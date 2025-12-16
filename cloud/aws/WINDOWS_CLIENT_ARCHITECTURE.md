# Windows Client Support - Architectural Analysis

## Current State Analysis

### Existing Architecture
The current Terraform deployment supports:
- **Single OS Type**: Either Linux (Ubuntu/RedHat) OR Windows for all instances, but not mixed deployments
- **Single AMI**: One AMI built via Packer, used for all instances (servers + clients)
- **Single Client ASG**: One autoscaling group for Nomad clients using the same AMI as servers
- **AMI Selection**: Can specify existing AMI or build new one automatically
- **Cleanup**: Deregisters AMI and deletes snapshots on `terraform destroy`

### Current File Structure
```
terraform/
├── control/
│   ├── main.tf                    # Orchestrates modules
│   ├── variables.tf               # Input variables
│   └── terraform.tfvars.sample    # Example configuration
└── modules/
    ├── aws-nomad-image/           # AMI build/selection module
    │   └── image.tf
    └── aws-hashistack/            # Infrastructure module
        ├── asg.tf                 # Client autoscaling group
        ├── instances.tf           # Server instances
        ├── variables.tf
        └── templates/
            ├── user-data-server.sh
            └── user-data-client.sh
```

## Required Changes for Windows Client Support

### Key Architectural Decision: Mixed OS Deployment Strategy

**Requirement**: Support flexible client OS configurations:
- **Linux-only clients**: Traditional deployment (Linux servers + Linux clients)
- **Windows-only clients**: Linux servers + Windows clients only
- **Mixed OS clients**: Linux servers + BOTH Linux AND Windows clients simultaneously

**Solution**: Build and manage TWO AMIs independently:
1. **Linux AMI** - For Linux servers and Linux clients (always built)
2. **Windows AMI** - For Windows clients (built only when `windows_client_count > 0`)

**Server Strategy**: Servers remain Linux-only for optimal HashiStack performance and stability.

### Deployment Scenarios

The architecture supports three flexible deployment modes:

#### Scenario 1: Linux-Only Deployment (Default)
```hcl
# terraform.tfvars
server_count = 1              # Linux servers
client_count = 3              # Linux clients
windows_client_count = 0      # No Windows clients
```
**Result**: Traditional all-Linux deployment
- 1 Linux AMI built
- Linux servers + Linux clients only

#### Scenario 2: Windows-Only Clients
```hcl
# terraform.tfvars
server_count = 1              # Linux servers
client_count = 0              # No Linux clients
windows_client_count = 3      # Windows clients
```
**Result**: Linux servers with Windows clients
- 2 AMIs built (Linux for servers, Windows for clients)
- Linux servers + Windows clients only

#### Scenario 3: Mixed OS Clients (Linux + Windows)
```hcl
# terraform.tfvars
server_count = 1              # Linux servers
client_count = 2              # Linux clients
windows_client_count = 2      # Windows clients
```
**Result**: Heterogeneous cluster with both client types
- 2 AMIs built (Linux and Windows)
- Linux servers + Linux clients + Windows clients
- Independent autoscaling for each client type
- Jobs can target specific OS via constraints

### Critical Design Considerations

#### 1. AMI Management Strategy

**Option A: Separate AMI Modules (RECOMMENDED)**
```hcl
module "linux_image" {
  source = "../modules/aws-nomad-image"
  ami_id = var.ami  # Linux AMI
  packer_os = var.packer_os
  # ... Linux-specific config
}

module "windows_image" {
  source = "../modules/aws-nomad-image"
  ami_id = var.windows_ami  # Windows AMI
  packer_os = "Windows"
  # ... Windows-specific config
}
```

**Pros**:
- Clean separation of concerns
- Independent AMI lifecycle management
- Easier to maintain and debug
- Supports different cleanup policies per OS

**Cons**:
- Slightly more verbose configuration
- Two separate Packer builds (but can run in parallel)

**Option B: Single Module with Conditional Logic**
- More complex conditionals
- Harder to maintain
- Not recommended for this use case

#### 2. Autoscaling Group Strategy

**Current**: Single ASG for all clients
**Required**: Two separate ASGs:

```hcl
# Linux Client ASG (existing)
resource "aws_autoscaling_group" "nomad_client_linux" {
  name = "${var.stack_name}-client-linux"
  launch_template {
    id = aws_launch_template.nomad_client_linux.id
  }
  desired_capacity = var.client_count
  # ...
}

# Windows Client ASG (new)
resource "aws_autoscaling_group" "nomad_client_windows" {
  name = "${var.stack_name}-client-windows"
  launch_template {
    id = aws_launch_template.nomad_client_windows.id
  }
  desired_capacity = var.windows_client_count
  # ...
}
```

#### 3. User Data Templates

**Linux**: `user-data-client.sh` (existing)
- Bash script
- Calls `/ops/scripts/client.sh`

**Windows**: `user-data-client-windows.ps1` (new)
- PowerShell script
- Calls `C:\ops\scripts\client.ps1`
- Must handle Windows-specific paths and service management

#### 4. Variable Management

**New Variables Required**:
```hcl
# terraform/control/variables.tf
variable "windows_ami" {
  description = "Windows AMI ID. If empty, builds automatically."
  type        = string
  default     = ""
}

variable "windows_client_instance_type" {
  description = "EC2 instance type for Windows clients"
  type        = string
  default     = "t3a.xlarge"  # Windows needs more resources
}

variable "windows_client_count" {
  description = "Number of Windows Nomad clients"
  type        = number
  default     = 0  # Opt-in by default
}

variable "packer_windows_version" {
  description = "Windows Server version (e.g., 2022)"
  type        = string
  default     = "2022"
}
```

#### 5. Cleanup Strategy

**Challenge**: Must clean up BOTH AMIs on `terraform destroy`

**Solution**: Extend existing cleanup mechanism:
```hcl
# In aws-nomad-image module
resource "local_file" "cleanup_linux" {
  count = local.build_linux_image && var.cleanup_ami_on_destroy ? 1 : 0
  content = "${local.linux_image_id},${local.linux_snapshot_id},${var.region}"
  filename = ".cleanup-linux-${local.linux_image_id}"
  # ... provisioner for cleanup
}

resource "local_file" "cleanup_windows" {
  count = local.build_windows_image && var.cleanup_ami_on_destroy ? 1 : 0
  content = "${local.windows_image_id},${local.windows_snapshot_id},${var.region}"
  filename = ".cleanup-windows-${local.windows_image_id}"
  # ... provisioner for cleanup
}
```

## Implementation Plan

### Phase 1: Variable and Configuration Updates
1. ✅ Add Windows-specific variables to `terraform/control/variables.tf`
2. ✅ Update `terraform.tfvars.sample` with Windows examples
3. ✅ Add Windows parameters to `terraform/modules/aws-hashistack/variables.tf`

### Phase 2: AMI Management
4. ✅ Refactor `terraform/modules/aws-nomad-image/image.tf` to support dual AMI builds
   - Add conditional logic for Windows AMI
   - Implement separate Packer build triggers
   - Handle both AMI lookups

### Phase 3: Infrastructure Updates
5. ✅ Update `terraform/modules/aws-hashistack/asg.tf`:
   - Rename existing ASG to `nomad_client_linux`
   - Add new `nomad_client_windows` ASG
   - Create Windows launch template
6. ✅ Create `templates/user-data-client-windows.ps1`
7. ✅ Update `terraform/control/main.tf` to orchestrate both AMI modules

### Phase 4: Cleanup Implementation
8. ✅ Implement dual AMI cleanup in `aws-nomad-image` module
9. ✅ Test cleanup with both AMIs

### Phase 5: Testing & Documentation
10. ✅ Test Packer builds (Linux + Windows)
11. ✅ Test Terraform deployment with both client types
12. ✅ Update `TESTING_PLAN.md`
13. ✅ Document lessons learned

## Open Questions & Decisions Needed

### 1. Server OS Strategy
**Decision**: Servers remain Linux-only because:
- HashiStack (Consul/Nomad/Vault) is primarily Linux-optimized
- Windows servers add significant complexity
- Most production deployments use Linux servers
- Clients can be mixed OS while servers stay Linux

### 2. Client OS Flexibility
**Decision**: Support three deployment modes:
- **Linux-only**: `client_count > 0`, `windows_client_count = 0` (default)
- **Windows-only**: `client_count = 0`, `windows_client_count > 0`
- **Mixed OS**: `client_count > 0`, `windows_client_count > 0`

**AMI Build Optimization**:
- Linux AMI: Always built (needed for servers)
- Windows AMI: Only built when `windows_client_count > 0`

### 3. Mixed OS Autoscaling
**Decision**: Independent autoscaling per OS type:
- Each ASG (Linux and Windows) has independent autoscaling policies
- Nomad Autoscaler can target specific node classes:
  - Linux clients: `node_class = "hashistack-linux"`
  - Windows clients: `node_class = "hashistack-windows"`
- Jobs specify constraints to target appropriate OS:
  ```hcl
  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"  # or "windows"
  }
  ```

### 4. Naming Convention
**Question**: How to name resources to distinguish Linux vs Windows?

**Recommendation**:
```
${stack_name}-client-linux    # Linux client ASG
${stack_name}-client-windows  # Windows client ASG
${stack_name}-linux-timestamp # Linux AMI name
${stack_name}-windows-timestamp # Windows AMI name
```

## Risk Assessment

### High Risk
- **Dual AMI builds increase deployment time**: Mitigate by allowing parallel builds
- **Cleanup complexity**: Must ensure both AMIs are cleaned up properly
- **Cost increase**: Running both Linux and Windows clients doubles client costs

### Medium Risk
- **User data template differences**: Windows PowerShell vs Linux Bash
- **Path differences**: `/ops` vs `C:\ops`
- **Service management**: systemd vs Windows Services

### Low Risk
- **Packer already supports Windows**: Proven in BUILD_13
- **ASG pattern is well-established**: Just duplicating existing pattern
- **Nomad supports mixed OS clusters**: This is a standard use case

## Success Criteria

### Must Have
- ✅ Deploy Linux clients and Windows clients simultaneously
- ✅ Both client types join Nomad cluster successfully
- ✅ Both AMIs are cleaned up on `terraform destroy`
- ✅ Independent autoscaling for each client type

### Should Have
- ✅ Clear documentation for configuration
- ✅ Example terraform.tfvars with both client types
- ✅ Testing plan covering mixed OS scenarios

### Nice to Have
- ⚪ Parallel AMI builds to reduce deployment time
- ⚪ Validation that prevents invalid configurations
- ⚪ Cost estimation for mixed OS deployments

## Next Steps

1. **Start with Phase 1**: Update variables and configuration files
2. **Validate approach**: Review with stakeholders before major refactoring
3. **Implement incrementally**: Test each phase before moving to next
4. **Document as you go**: Update this document with decisions and learnings

## References

- Task Requirements: `TASK_REQUIREMENTS.md`
- Testing Plan: `TESTING_PLAN.md`
- Windows AMI Success: `packer/BUILD_13_VALIDATION_SUCCESS.md`
- Current Packer Config: `packer/aws-packer.pkr.hcl`
- Current Terraform: `terraform/control/main.tf`