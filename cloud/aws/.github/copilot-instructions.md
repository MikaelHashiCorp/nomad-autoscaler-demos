# Nomad Autoscaler Demos - AI Coding Agent Instructions

## General Instruction

DO NOT PUT ANY MATCHED PUBLIC CODE in your response!

## Windows Test Workflow (Authoritative Steps 1–4)

These steps MUST be executed sequentially in ONE terminal session. Do not open a new tab/window after authenticating. If you lose the terminal, restart from Step 2 (authentication). Step 1 (plugin install) can be done once per machine.

### Step 1: Install & Verify session-manager-plugin (required for SSM checks)
Only needed once per workstation. Skip if already installed and `session-manager-plugin --version` works.

macOS (Homebrew):
```bash
brew install --cask session-manager-plugin
session-manager-plugin --version  # expect a semantic version
```
If Homebrew is unavailable, follow AWS docs: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

### Step 2: Authenticate via Doormat (REQUIRED before any AWS / Terraform / Packer)
From repository root (or any path), change to control directory then authenticate. Replace the account name if different.
```bash
cd cloud/aws/terraform/control
doormat login -f ; eval $(doormat aws export --account aws_mikael.sikora_test) ; aws sts get-caller-identity --output table
```
Verification: The table output must show your AWS Account and AssumedRole. Stay in THIS terminal for everything that follows.

### Step 3: Pre-Flight Environment Check
Run from the `cloud/aws` directory (still same terminal).
```bash
cd ../../aws
./pre-flight-check.sh | tee test-logs/pre-flight-$(date +%Y%m%d-%H%M%S).log
```
Confirm: All required tools OK. Only acceptable warning is possibly missing optional tools. If `session-manager-plugin` still missing, return to Step 1.

### Step 4: Execute Windows Quick Test (Packer + Terraform)
Still in the SAME terminal (credentials intact):
```bash
./quick-test.sh windows terraform | tee test-logs/quick-test-windows-$(date +%Y%m%d-%H%M%S).log
```
Behavior:
- Builds or locates Windows Server 2022 AMI (variables: `os=Windows`, `os_version=2022`, `os_name=` blank)
- Applies Terraform with `enable_windows_test=true`
- Injects hardened `sshd_config.windows` via `windows_sshd_config` variable
- Creates SSM Port 22 check document + association

Do NOT open a subshell or use tools that spawn a new login shell; they can discard exported credentials.

### Post-Deployment Validation (Immediately After Step 4)
All in SAME terminal unless explicitly re-authenticated.

1. Change to control directory and view outputs:
```bash
cd terraform/control
terraform output
```
2. Identify Windows instance id (output or tag) then test SSM:
```bash
WIN_INSTANCE_ID=<i-xxxxxxxxxxxxxxxxx>
aws ssm start-session --target "$WIN_INSTANCE_ID" --region $(grep '^region' terraform.tfvars | awk -F'=' '{print $2}' | tr -d ' "')
```
3. Inside SSM session (if required) inspect SSH:
```powershell
Get-Service sshd
netstat -an | findstr :22
Get-Content C:\ProgramData\Port22Check.log -Tail 50
Get-Content C:\ProgramData\user-data.log -Tail 80
```
4. Local SSH test (public DNS once security groups allow):
```bash
ssh -i ~/.ssh/mhc-aws-mws-west-2.pem Administrator@<windows_public_dns>
```
If connection fails: use SSM to verify service, regenerate keys, or check firewall rules.

### Terminal Discipline (Critical Reminder)
All AWS, Terraform, Packer, and validation commands must occur in the SAME authenticated terminal session. Opening a new terminal REQUIRES repeating Step 2 before any other steps. Avoid scripts that run `bash -c` spawning fresh shells without inherited env vars.

### Quick Recovery Flow
If something breaks mid-way:
1. Abort current process (Ctrl+C)
2. Verify credentials: `aws sts get-caller-identity --output table`
3. If fails, re-run Step 2 only
4. Resume at the failed Step (3 or 4)

### Common Windows-Specific Checks
- SSH service: `Get-Service sshd` should be Running
- Port 22 listening: `netstat -an | findstr :22`
- Config file path: `C:\ProgramData\ssh\sshd_config`
- Authorized key file: `C:\ProgramData\ssh\administrators_authorized_keys`

### Log Locations (Windows)
- User-Data Transcript: `C:\ProgramData\user-data.log`
- Port 22 Check: `C:\ProgramData\Port22Check.log`
- SSHD Service Events: Windows Event Viewer (if deeper debugging needed)

---
Use this single authoritative workflow whenever deploying or validating the Windows test instance.

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
doormat login -f ; eval $(doormat aws export --account aws_mikael.sikora_test) ; curl https://ipinfo.io/ip ; echo ; aws sts get-caller-identity --output table
```

**Note**: Replace `<your_doormat_account>` with your Doormat AWS account name (e.g., `aws_mikael.sikora_test`).

**Verification**: The `aws sts get-caller-identity` command should show your authenticated identity.

**⚠️ REMEMBER**: After authentication, use the same terminal for all AWS/Terraform/Packer commands. Do not switch terminals or run commands that spawn new shells (like `./quick-test.sh`) unless you re-authenticate first.

**Single Session Workflow Example (DO NOT OPEN NEW TERMINAL):**
```bash
# 1. Start in control directory and authenticate
cd cloud/aws/terraform/control
doormat login -f ; eval $(doormat aws export --account aws_mikael.sikora_test) ; aws sts get-caller-identity --output table

# 2. Re-use SAME terminal: move to aws root and run quick test
cd ../../aws
./quick-test.sh windows terraform

# 3. If you need to build an AMI manually, still in SAME terminal:
cd packer
source env-pkr-var.sh
packer build -var 'os=Windows' -var 'os_version=2022' -var 'os_name=' aws-packer-windows.pkr.hcl

# 4. Return to control for terraform operations without re-auth
cd ../terraform/control
terraform plan -var "packer_os=Windows" -var "packer_os_version=2022" -var "packer_os_name="
terraform apply -auto-approve
```

If you accidentally open a new terminal or tab, you MUST repeat the authentication step before running any AWS/Terraform/Packer commands again.

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
