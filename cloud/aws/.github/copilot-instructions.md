# Nomad Autoscaler Demos - AI Coding Agent Instructions

## General Instruction

DO NOT PUT ANY MATCHED PUBLIC CODE in your response!

## Project Overview

This is a **HashiCorp Nomad Autoscaler demonstration environment** that provisions cloud infrastructure (AWS) with a complete "hashistack" (Nomad, Consul, Vault) for testing horizontal and vertical autoscaling capabilities. The project uses **Packer** to build AMIs and **Terraform** to deploy infrastructure with Auto Scaling Groups managed by the Nomad Autoscaler.

## Architecture

### Three-Layer Structure
1. **Packer Layer** (`aws/packer/`, `shared/packer/`): Builds AMIs with pre-installed HashiCorp binaries (Consul, Nomad, Vault, CNI plugins)
2. **Terraform Layer** (`aws/terraform/`): Infrastructure provisioning with modules for AMI management and cluster deployment
3. **Nomad Jobs Layer** (`shared/terraform/modules/shared-nomad-jobs/`): Demo workloads (webapp, Traefik, Prometheus, Grafana)

### Key Components
- **Server nodes**: Run Consul/Nomad servers with service discovery and cluster management
- **Client nodes**: Run Nomad clients in an AWS Auto Scaling Group that scales based on CPU/memory metrics
- **Monitoring stack**: Prometheus scrapes metrics, Grafana visualizes, Traefik provides ingress routing
- **Demo webapp**: Simulated latency via Toxiproxy to demonstrate load-based autoscaling

## Critical Developer Workflows

### Connect to AWS using HashiCorp Doormat

**IMPORTANT**: Always authenticate to AWS via Doormat before running any Terraform or Packer commands.

**CRITICAL**: AWS credentials are session-specific. Once authenticated, **STAY IN THE SAME TERMINAL** for all subsequent commands. Opening a new terminal will lose your credentials and require re-authentication.

When opening a new Terminal session, navigate to your repository's Terraform control directory:
```bash
# Navigate to wherever you cloned this repository, then:
cd cloud/aws/terraform/control
```

**Example paths** (yours will vary based on where you cloned the repo):
- `cd ~/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/terraform/control`
- `cd ~/projects/nomad-autoscaler-demos/cloud/aws/terraform/control`
- `cd ~/workspace/nomad-demos/cloud/aws/terraform/control`

Then authenticate:
```bash
doormat login -f ; eval $(doormat aws export --account <your_doormat_account>) ; curl -s https://ipinfo.io/ip ; echo ; aws sts get-caller-identity --output table
```

**Note**: Replace `<your_doormat_account>` with your Doormat AWS account name (e.g., `aws_mikael.sikora_test`).


## Bob-Specific Instructions

**CRITICAL**: Bob must follow the mandatory command execution rules defined in [`.github/bob-instructions.md`](.github/bob-instructions.md).

### Quick Reference for Bob:
- **Every command** must start with: `source ~/.zshrc 2>/dev/null && logcmd <command>`
- **Every packer build** must use: `source ~/.zshrc 2>/dev/null && cd packer && ./run-with-timestamps.sh packer build <options> .`
- See [bob-instructions.md](.github/bob-instructions.md) for complete details

**Verification**: The `aws sts get-caller-identity` command should show your authenticated identity.

**⚠️ REMEMBER**: After authentication, use the same terminal for all AWS/Terraform/Packer commands. Do not switch terminals or run commands that spawn new shells (like `./quick-test.sh`) unless you re-authenticate first.

### Building AMIs with Packer

**Prerequisites**: Ensure you've authenticated via Doormat (see above).

```bash
# From your repository root, navigate to:
cd cloud/aws/packer/
source env-pkr-var.sh  # Fetches latest HashiCorp versions from checkpoint API
packer build .
```

**Version Management**: Hybrid fallback system (priority: CLI args > env vars > defaults in `variables.pkr.hcl`). See `aws/packer/VERSION_MANAGEMENT.md` for details.

**Important**: The `env-pkr-var.sh` script sets `PACKER_LOG=1` and queries GitHub/HashiCorp APIs for latest versions. Built AMIs include tags for all component versions.

### Deploying Infrastructure

**Prerequisites**: Ensure you've authenticated via Doormat (see above).

```bash
# From your repository root, navigate to:
cd cloud/aws/terraform/control/
# Edit terraform.tfvars (required: region, key_name, owner_name, owner_email)
terraform init
terraform apply
```

**Region Configuration**: All scripts read the region from `terraform.tfvars` as the single source of truth. This includes:
- `quick-test.sh` - Automated testing script
- `pre-flight-check.sh` - Pre-deployment validation
- `verify-deployment.sh` - Post-deployment verification
- No hardcoded regions in any script

**AMI Resolution**: The `aws-nomad-image` module checks if `var.ami_id` exists; if not (or AMI doesn't exist), triggers Packer build automatically via `null_resource.packer_build`.

**AMI Cleanup Control**: Control whether AMIs are preserved during `terraform destroy`:
```hcl
# In terraform.tfvars
cleanup_ami_on_destroy = false  # Set to false to keep AMI for reuse (default: true)
```
This is useful for keeping tested AMIs for future deployments without rebuilding.

**Auto-scaling**: Client nodes use `aws_autoscaling_group.nomad_client` (min=0, max=10). The Nomad Autoscaler job (`templates/aws_autoscaler.nomad.tpl`) monitors Prometheus metrics and adjusts ASG capacity.

### Accessing Services
After `terraform apply`, outputs provide:
- Nomad UI: `http://<server_elb_dns>:4646/ui`
- Consul UI: `http://<server_elb_dns>:8500/ui`
- Grafana: `http://<client_elb_dns>:3000/d/AQphTqmMk/demo`
- Webapp: `http://<client_elb_dns>:80`

## Project-Specific Conventions

### Bash Provisioning Scripts
- **Logging pattern**: All scripts (`setup.sh`, `server.sh`, `client.sh`, `net.sh`) use unified logging with `tee` to `/var/log/provision.log` and prevent duplicate logging with `_PROVISION_LOG_INITIALIZED` guard
- **Error handling**: `set -Eeuo pipefail` and `trap 'log "failed (exit code $?)"' ERR` for all provisioners
- **Single execution**: `set-prompt.sh` uses marker file `/etc/.custom_prompt_set` to ensure idempotency
- **OS Detection**: `os-detect.sh` provides centralized OS detection and package manager abstraction for Ubuntu/RedHat support
- **DNS Compatibility**: RedHat 9+ systemd-resolved automatically configured to work with dnsmasq

### Terraform Module Pattern
- **Shared modules**: `aws/terraform/modules/` contains AWS-specific modules; `shared/terraform/modules/` contains cloud-agnostic Nomad job specs
- **Template interpolation**: User-data scripts use `templatefile()` with variables like `${nomad_binary}`, `${retry_join}`, `${node_class}`
- **Cleanup automation**: AMI cleanup uses `local_file.cleanup` resource with `when=destroy` provisioner to deregister AMIs and delete snapshots

### Nomad Job Conventions
- **Service discovery**: All jobs use Consul for service discovery (`consul_sd_configs` in Prometheus)
- **Dynamic ports**: Jobs use `network { port "name" {} }` for dynamic allocation (20000-32000 range)
- **Traefik integration**: Services expose via Traefik tags: `traefik.enable=true`, `traefik.http.routers.<name>.entrypoints=<entrypoint>`
- **Autoscaling policy**: `webapp.nomad` includes inline `scaling` block with Prometheus query: `sum(traefik_entrypoint_open_connections)/scalar(nomad_nomad_job_summary_running)` with target=10

### DNS Configuration
- **dnsmasq setup**: All nodes configure dnsmasq to forward `.consul` domain to Consul agent on port 8600 (`10-consul.dnsmasq`)
- **Cloud-specific DNS**: Fallback DNS varies by cloud (`99-default.dnsmasq.aws` uses `169.254.169.253`)

## Integration Points

### Consul <-> Nomad
- Nomad clients register with `retry_join` via AWS tag `ConsulAutoJoin=auto-join`
- Nomad servers bootstrap via `bootstrap_expect` set dynamically by `server_count` variable
- Services auto-register in Consul catalog for discovery

### Prometheus <-> Autoscaler
- Nomad exports Prometheus metrics via `/v1/metrics?format=prometheus`
- Autoscaler queries Prometheus for `nomad_client_allocated_cpu`, `nomad_client_unallocated_cpu`, `nomad_client_allocated_memory`
- Target-value strategy scales ASG when cluster average exceeds 70% CPU/memory allocation

### AWS IAM Permissions
- **Server role**: `ec2:DescribeInstances`, `ec2:DescribeTags`, `autoscaling:DescribeAutoScalingGroups` (for Consul retry_join)
- **Client role**: Additional ASG mutation permissions (`UpdateAutoScalingGroup`, `TerminateInstanceInAutoScalingGroup`) for Nomad Autoscaler

## Common Pitfalls

1. **Missing AWS authentication**: Always run Doormat authentication before any AWS/Terraform/Packer commands. Verify with `aws sts get-caller-identity`.
2. **Wrong working directory**: 
   - Terraform commands must be run from `cloud/aws/terraform/control/` (relative to repo root)
   - Packer commands must be run from `cloud/aws/packer/` (relative to repo root)
   - Use `pwd` to verify your current directory
3. **Stale AMI references**: If Packer builds succeed but Terraform uses old AMI, check `ami_id` in `terraform.tfvars` and ensure `data.aws_ami.built` filter matches `name_prefix`
4. **Client nodes not joining**: Verify `ConsulAutoJoin` tag exists on instances and IAM role has `ec2:DescribeInstances` permission
5. **Autoscaler not scaling**: Check Prometheus is scraping Nomad metrics (`http://<prometheus>:9090/targets`) and autoscaler logs (`nomad logs -job autoscaler`)
6. **Port conflicts**: Dynamic ports require security group ingress rules for 20000-32000 (configured in `sg.tf`)
7. **DNS resolution failures**: Ensure dnsmasq is running (`systemctl status dnsmasq`) and `/etc/resolv.conf` has `nameserver 127.0.0.1`
8. **RedHat DNS issues**: On RHEL 9+, systemd-resolved must be configured to work with dnsmasq (automatically handled in provisioning scripts)
9. **AMI not cleaned up**: Check `cleanup_ami_on_destroy` setting in terraform.tfvars (default: true for cleanup)

## File Organization Patterns

- **Multi-cloud design**: `aws/` and `shared/` separation allows future Azure/GCP support
- **Config vs. Scripts**: `shared/packer/config/` contains static configs (HCL, systemd units); `scripts/` contains dynamic provisioners
- **Terraform state separation**: `terraform/control/` is the single entry point; modules are reusable
- **Workspace files**: `.code-workspace` files include remote paths to `/etc/nomad.d`, `/etc/consul.d` for easy SSH editing

## Testing the Autoscaler

1. Generate load: `while true; do curl http://<client_elb_dns>; done`
2. Watch Grafana: Open dashboard to see `running_allocs_demo` and `current_connections` metrics
3. Observe scaling: `nomad node status` shows new nodes joining after ~2min cooldown
4. Check ASG activity: `aws autoscaling describe-scaling-activities --auto-scaling-group-name <client_asg_name>`

## Windows Client Support (Added 2025-12-16)

### Overview

The project now supports **mixed OS deployments** with three flexible scenarios:
1. **Linux-only** (default): Linux servers + Linux clients
2. **Windows-only clients**: Linux servers + Windows clients
3. **Mixed OS**: Linux servers + BOTH Linux AND Windows clients

### Architecture

**Key Design**: Dual AMI strategy with separate autoscaling groups
- **Linux AMI**: Always built (needed for servers and Linux clients)
- **Windows AMI**: Built conditionally when `windows_client_count > 0`
- **Linux Client ASG**: `nomad_client_linux` with node class `hashistack-linux`
- **Windows Client ASG**: `nomad_client_windows` with node class `hashistack-windows`

### Configuration Variables

**New Variables in terraform.tfvars**:
```hcl
# Windows Client Configuration (optional)
windows_client_instance_type = "t3a.medium"  # Windows needs more resources
windows_client_count         = 1             # Set to 0 to disable
windows_ami                  = ""            # Empty = auto-build
packer_windows_version       = "2022"        # Windows Server version
```

### Deployment Scenarios

**Linux-only (default)**:
```hcl
client_count = 1
windows_client_count = 0  # or omit
```

**Windows-only clients**:
```hcl
client_count = 0
windows_client_count = 1
```

**Mixed OS**:
```hcl
client_count = 1
windows_client_count = 1
```

### Building Windows AMIs

**Windows AMI Build**:
```bash
cd cloud/aws/packer/
source env-pkr-var.sh
packer build -var-file=windows-2022.pkrvars.hcl .
```

**Critical**: Always include `-var-file=windows-2022.pkrvars.hcl` to set `os = "Windows"`.

### Job Targeting

**Target Windows clients**:
```hcl
job "windows-app" {
  constraint {
    attribute = "${attr.kernel.name}"
    value     = "windows"
  }
  # or use node class
  constraint {
    attribute = "${node.class}"
    value     = "hashistack-windows"
  }
}
```

**Target Linux clients**:
```hcl
job "linux-app" {
  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }
  # or use node class
  constraint {
    attribute = "${node.class}"
    value     = "hashistack-linux"
  }
}
```

### Key Implementation Patterns

#### 1. Dual AMI Module Pattern
```hcl
# Linux AMI (always)
module "hashistack_image_linux" {
  source = "../modules/aws-nomad-image"
  ami_id = var.ami
  packer_os = var.packer_os
}

# Windows AMI (conditional)
module "hashistack_image_windows" {
  count = var.windows_client_count > 0 ? 1 : 0
  source = "../modules/aws-nomad-image"
  ami_id = var.windows_ami
  packer_os = "Windows"
}
```

#### 2. Conditional Resource Creation
```hcl
resource "aws_autoscaling_group" "nomad_client_windows" {
  count = var.windows_client_count > 0 ? 1 : 0
  # configuration
}
```

**Access**: Always use index: `aws_autoscaling_group.nomad_client_windows[0]`

#### 3. Resource Naming Convention
- Linux resources: `nomad_client_linux`, `hashistack-linux`
- Windows resources: `nomad_client_windows`, `hashistack-windows`
- Include OS tags for easy identification

### User Data Templates

**Linux**: `templates/user-data-client.sh` (bash)
- Calls `/ops/scripts/client.sh`
- Uses systemd for service management

**Windows**: `templates/user-data-client-windows.ps1` (PowerShell)
- Calls `C:\ops\scripts\client.ps1`
- Uses Windows Services for service management

### Common Pitfalls

1. **Module reference errors**: After renaming resources, update ALL references in outputs.tf, templates.tf, etc.
2. **Conditional resource access**: Always check count before accessing: `var.windows_client_count > 0 ? resource[0] : ""`
3. **Block device names**: Linux uses `/dev/xvdd`, Windows uses `/dev/sda1`
4. **Instance sizing**: Windows requires larger instances (t3.medium minimum vs t3.small for Linux)
5. **Cost implications**: Windows instances cost ~20-30% more than Linux

### Backward Compatibility

✅ **Fully backward compatible**:
- Default behavior unchanged (Linux-only)
- Existing terraform.tfvars work without modification
- Windows support is opt-in via `windows_client_count`

### Testing Windows Deployments

**Verify Windows clients joined**:
```bash
nomad node status
# Look for nodes with class "hashistack-windows"
```

**Check Windows node attributes**:
```bash
WINDOWS_NODE=$(nomad node status -json | jq -r '.[] | select(.NodeClass=="hashistack-windows") | .ID' | head -1)
nomad node status -verbose $WINDOWS_NODE | grep -i "kernel.name\|os.name"
```

**Deploy Windows-targeted job**:
```bash
nomad job run windows-test-job.nomad
nomad job status windows-test
```

### Documentation

Comprehensive documentation available:
- [`WINDOWS_CLIENT_ARCHITECTURE.md`](../WINDOWS_CLIENT_ARCHITECTURE.md) - Design decisions
- [`WINDOWS_CLIENT_IMPLEMENTATION.md`](../WINDOWS_CLIENT_IMPLEMENTATION.md) - Implementation details
- [`WINDOWS_CLIENT_QUICK_START.md`](../WINDOWS_CLIENT_QUICK_START.md) - Quick reference
- [`TESTING_PLAN.md`](../TESTING_PLAN.md) - Phase 4 Windows testing scenarios
- [`VALIDATION_RESULTS.md`](../VALIDATION_RESULTS.md) - Validation proof

### Updates
- 2025-12-16: Added Windows client support with mixed OS deployment capability
