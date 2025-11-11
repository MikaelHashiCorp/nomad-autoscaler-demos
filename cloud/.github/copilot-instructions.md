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

When opening a new Terminal session, navigate to your repository's Terraform control directory:
```bash
# Navigate to wherever you cloned this repository, then:
cd cloud/aws/terraform/control
```

**Example paths** (yours will vary based on where you cloned the repo):
- `cd ~/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/terraform/control`
- `cd ~/projects/nomad-autoscaler-demos/cloud/aws/terraform/control`
- `cd ~/workspace/nomad-autoscaler-demos/cloud/aws/terraform/control`

Then authenticate:
```bash
doormat login -f ; eval $(doormat aws export --account <your_doormat_account>) ; curl https://ipinfo.io/ip ; echo ; aws sts get-caller-identity --output table
```

**Note**: Replace `<your_doormat_account>` with your Doormat AWS account name (e.g., `aws_mikael.sikora_test`).

**Verification**: The `aws sts get-caller-identity` command should show your authenticated identity.

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

**AMI Resolution**: The `aws-nomad-image` module checks if `var.ami_id` exists; if not (or AMI doesn't exist), triggers Packer build automatically via `null_resource.packer_build`.

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
2. **Wrong working directory**: Terraform commands must be run from `aws/terraform/control/`. Packer commands from `aws/packer/`.
3. **Stale AMI references**: If Packer builds succeed but Terraform uses old AMI, check `ami_id` in `terraform.tfvars` and ensure `data.aws_ami.built` filter matches `name_prefix`
4. **Client nodes not joining**: Verify `ConsulAutoJoin` tag exists on instances and IAM role has `ec2:DescribeInstances` permission
5. **Autoscaler not scaling**: Check Prometheus is scraping Nomad metrics (`http://<prometheus>:9090/targets`) and autoscaler logs (`nomad logs -job autoscaler`)
6. **Port conflicts**: Dynamic ports require security group ingress rules for 20000-32000 (configured in `sg.tf`)
7. **DNS resolution failures**: Ensure dnsmasq is running (`systemctl status dnsmasq`) and `/etc/resolv.conf` has `nameserver 127.0.0.1`

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
