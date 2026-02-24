#!/bin/bash
# Quick Test Script for Multi-OS Support
# Usage: ./quick-test.sh [ubuntu|redhat|windows|mixed] [packer-only|terraform]
#   ubuntu:      Test Ubuntu Linux clients only (default)
#   redhat:      Test RedHat Linux clients only
#   windows:     Test Windows clients only
#   mixed:       Test both Linux and Windows clients together
#   packer-only: Only test Packer build (no Terraform)
#   terraform:   Run Terraform apply (default - Terraform will call Packer if needed)
#
# To destroy infrastructure:
#   cd terraform/control && terraform destroy -auto-approve
#   If AMI was already cleaned up, use: terraform destroy -refresh=false -auto-approve

set -euo pipefail

OS_TYPE="${1:-ubuntu}"
TEST_MODE="${2:-terraform}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Get script directory to create logs relative to it
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/test-logs"
mkdir -p "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
  echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"
}

error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKER_DIR="$SCRIPT_DIR/packer"
TERRAFORM_DIR="$SCRIPT_DIR/terraform/control"

# Read region from terraform.tfvars
if [ -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
  REGION=$(grep '^region' "$TERRAFORM_DIR/terraform.tfvars" | sed 's/region[[:space:]]*=[[:space:]]*"\(.*\)"/\1/' | tr -d ' ')
  if [ -z "$REGION" ]; then
    error "Could not read region from terraform.tfvars"
    exit 1
  fi
else
  error "terraform.tfvars not found at $TERRAFORM_DIR/terraform.tfvars"
  exit 1
fi
log "Using AWS Region: $REGION"

# OS-specific variables
if [[ "$OS_TYPE" == "ubuntu" ]]; then
  log "Testing Ubuntu build..."
  PACKER_VARS=""
  NAME_FILTER="scale-mws-*"
  SSH_USER="ubuntu"
  EXPECTED_OS_ID="ubuntu"
  EXPECTED_PKG_MGR="apt-get"
  TF_OS="Ubuntu"
  TF_OS_VERSION="24.04"
  TF_OS_NAME="noble"
  TF_LINUX_COUNT="1"
  TF_WINDOWS_COUNT="0"
elif [[ "$OS_TYPE" == "redhat" ]]; then
  log "Testing RedHat build..."
  PACKER_VARS="-var 'os=RedHat' -var 'os_version=9.6.0' -var 'os_name=' -var 'name_prefix=scale-mws-rhel'"
  NAME_FILTER="scale-mws-rhel-*"
  SSH_USER="ec2-user"
  EXPECTED_OS_ID="rhel"
  EXPECTED_PKG_MGR="dnf"
  TF_OS="RedHat"
  TF_OS_VERSION="9.6.0"
  TF_OS_NAME=""
  TF_LINUX_COUNT="1"
  TF_WINDOWS_COUNT="0"
elif [[ "$OS_TYPE" == "windows" ]]; then
  log "Testing Windows build..."
  PACKER_VARS="-var 'os=Windows' -var 'os_version=2022' -var 'os_name=' -var 'name_prefix=scale-mws-win'"
  NAME_FILTER="scale-mws-win-*"
  SSH_USER="Administrator"
  EXPECTED_OS_ID="windows"
  EXPECTED_PKG_MGR="choco"
  # For Windows-only clients, we still need Ubuntu for the server
  TF_OS="Ubuntu"
  TF_OS_VERSION="24.04"
  TF_OS_NAME="noble"
  TF_LINUX_COUNT="0"
  TF_WINDOWS_COUNT="1"
elif [[ "$OS_TYPE" == "mixed" ]]; then
  log "Testing mixed Linux + Windows deployment..."
  PACKER_VARS=""
  NAME_FILTER="scale-mws-*"
  SSH_USER="ubuntu"  # For Linux instances
  EXPECTED_OS_ID="ubuntu"
  EXPECTED_PKG_MGR="apt-get"
  TF_OS="Ubuntu"
  TF_OS_VERSION="24.04"
  TF_OS_NAME="noble"
  TF_LINUX_COUNT="1"
  TF_WINDOWS_COUNT="1"
else
  error "Invalid OS type. Use 'ubuntu', 'redhat', 'windows', or 'mixed'"
  exit 1
fi

# Convert to uppercase for display (zsh/bash compatible)
OS_TYPE_UPPER=$(echo "$OS_TYPE" | tr '[:lower:]' '[:upper:]')

# Validate test mode
case "$TEST_MODE" in
  packer-only|terraform)
    ;;
  *)
    error "Invalid test mode. Use 'packer-only' or 'terraform'"
    exit 1
    ;;
esac

log "============================================"
log "  Multi-OS Testing: $OS_TYPE_UPPER"
log "  Test Mode: $TEST_MODE"
log "  Timestamp: $TIMESTAMP"
log "============================================"

# Step 1: Packer Build (only in packer-only mode)
if [[ "$TEST_MODE" == "packer-only" ]]; then
  log ""
  log "Step 1: Building Packer AMI for $OS_TYPE..."
  cd "$PACKER_DIR"

  if [[ ! -f "env-pkr-var.sh" ]]; then
    error "env-pkr-var.sh not found!"
    exit 1
  fi

  log "Sourcing environment variables..."
  source env-pkr-var.sh

  log "Sourcing environment variables..."
  source env-pkr-var.sh

  log "Initializing Packer..."
  packer init . || { error "Packer init failed"; exit 1; }

  log "Validating Packer configuration..."
  packer validate . || { error "Packer validation failed"; exit 1; }

  log "Building AMI (this will take 10-15 minutes)..."
  if [[ -n "$PACKER_VARS" ]]; then
    eval "packer build $PACKER_VARS ." 2>&1 | tee "$LOG_DIR/packer-$OS_TYPE-$TIMESTAMP.log"
  else
    packer build . 2>&1 | tee "$LOG_DIR/packer-$OS_TYPE-$TIMESTAMP.log"
  fi

  if [[ $? -eq 0 ]]; then
    log "✅ Packer build completed successfully"
  else
    error "Packer build failed. Check log: $LOG_DIR/packer-$OS_TYPE-$TIMESTAMP.log"
    exit 1
  fi

  # Get the AMI ID for verification
  log ""
  log "Retrieving AMI ID..."
  AMI_ID=$(aws ec2 describe-images \
    --owners self \
    --filters "Name=name,Values=$NAME_FILTER" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text \
    --region "$REGION")

  if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
    error "Failed to retrieve AMI ID"
    exit 1
  fi

  log "✅ AMI ID: $AMI_ID"

  # Verify AMI tags
  log "Verifying AMI tags..."
  aws ec2 describe-images \
    --image-ids "$AMI_ID" \
    --region "$REGION" \
    --query 'Images[0].Tags[?Key==`OS`||Key==`OS_Version`]' \
    --output table

  # If packer-only mode, exit here
  if [[ "$TEST_MODE" == "packer-only" ]]; then
    log ""
    log "============================================"
    log "  Packer-Only Test Complete!"
    log "  AMI ID: $AMI_ID"
    log "  Log: $LOG_DIR/packer-$OS_TYPE-$TIMESTAMP.log"
    log "============================================"
    exit 0
  fi
fi

# Step 2: Terraform Deployment (only in terraform mode)
if [[ "$TEST_MODE" == "terraform" ]]; then
  log ""
  log "Terraform Infrastructure Deployment..."
  cd "$TERRAFORM_DIR"

  log "Initializing Terraform..."
  terraform init -upgrade 2>&1 | tee "$LOG_DIR/terraform-init-$OS_TYPE-$TIMESTAMP.log"
  log "✅ Terraform initialized"

  log "Creating Terraform plan..."
  # Let Terraform call Packer if needed, passing OS-specific variables
  terraform plan \
    -var "packer_os=$TF_OS" \
    -var "packer_os_version=$TF_OS_VERSION" \
    -var "packer_os_name=$TF_OS_NAME" \
    -var "client_count=$TF_LINUX_COUNT" \
    -var "windows_client_count=$TF_WINDOWS_COUNT" \
    -out="$LOG_DIR/plan-$OS_TYPE.tfplan" 2>&1 | tee "$LOG_DIR/terraform-plan-$OS_TYPE-$TIMESTAMP.log"
  log "✅ Terraform plan created"

  # Step 3: Terraform Apply
  log ""
  log "Deploying infrastructure (this will take 5-10 minutes)..."
  terraform apply -auto-approve "$LOG_DIR/plan-$OS_TYPE.tfplan" 2>&1 | tee "$LOG_DIR/terraform-apply-$OS_TYPE-$TIMESTAMP.log"

  if [[ $? -eq 0 ]]; then
    log "✅ Infrastructure deployed successfully"
  else
    error "Terraform apply failed. Check log: $LOG_DIR/terraform-apply-$OS_TYPE-$TIMESTAMP.log"
    exit 1
  fi

  # Capture outputs
  terraform output -json > "$LOG_DIR/outputs-$OS_TYPE-$TIMESTAMP.json"

  # Extract ELB DNS from the ip_addresses output text
  # The output contains: "The Nomad UI can be accessed at http://SERVER-DNS:4646/ui"
  # and "export NOMAD_CLIENT_DNS=http://CLIENT-DNS"
  OUTPUT_TEXT=$(terraform output -raw ip_addresses 2>/dev/null || echo "")
  
  if [[ -n "$OUTPUT_TEXT" ]]; then
    # Use sed instead of grep -P for macOS compatibility
    SERVER_LB=$(echo "$OUTPUT_TEXT" | grep 'The Nomad UI can be accessed at http://' | sed -E 's/.*http:\/\/([^:]+).*/\1/' || echo "")
    CLIENT_LB=$(echo "$OUTPUT_TEXT" | grep 'NOMAD_CLIENT_DNS=http://' | sed -E 's/.*http:\/\/([^ ]+).*/\1/' || echo "")
  else
    warn "Could not retrieve terraform outputs"
    SERVER_LB=""
    CLIENT_LB=""
  fi

  log ""
  log "============================================"
  log "  Deployment Complete!"
  log "============================================"
  
  if [[ -n "$SERVER_LB" && -n "$CLIENT_LB" ]]; then
    log "Consul UI:  http://$SERVER_LB:8500/ui"
    log "Nomad UI:   http://$SERVER_LB:4646/ui"
    log "Grafana:    http://$CLIENT_LB:3000"
    log "Web App:    http://$CLIENT_LB"
  else
    warn "Unable to extract ELB DNS names from outputs"
    warn "Run 'cd $TERRAFORM_DIR && terraform output' to see connection details"
  fi
  log "============================================"

  # Step 5: Wait and Test Services
  # Skip service tests if we don't have the ELB DNS names
  if [[ -z "$SERVER_LB" || -z "$CLIENT_LB" ]]; then
    warn "Skipping service tests due to missing ELB DNS names"
  else
  log ""
  log "Waiting for ELB health checks to pass (90 seconds)..."
  for i in {1..18}; do
    echo -n "."
    sleep 5
  done
  echo ""

  log "Testing service accessibility..."

  # Test Consul UI
  log "Testing Consul UI..."
  if curl -f -s -I "http://$SERVER_LB:8500/ui/" > /dev/null 2>&1; then
    log "✅ Consul UI is accessible"
  else
    error "❌ Consul UI is NOT accessible"
  fi

  # Test Nomad UI
  log "Testing Nomad UI..."
  if curl -f -s -I "http://$SERVER_LB:4646/ui/" > /dev/null 2>&1; then
    log "✅ Nomad UI is accessible"
  else
    error "❌ Nomad UI is NOT accessible"
  fi

  # Test Consul members
  log "Checking Consul members..."
  CONSUL_MEMBERS=$(curl -s "http://$SERVER_LB:8500/v1/agent/members" | jq -r '.[].Name' 2>/dev/null | wc -l)
  log "  Found $CONSUL_MEMBERS Consul members"

  # Test Nomad nodes
  log "Checking Nomad nodes..."
  NOMAD_NODES=$(curl -s "http://$SERVER_LB:4646/v1/nodes" | jq -r '.[] | .Name' 2>/dev/null | wc -l)
  log "  Found $NOMAD_NODES Nomad nodes"

  # SSH Test
  log ""
  log "Getting server instance IP for SSH test..."
  SERVER_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=*server*" \
             "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text \
    --region "$REGION")

  if [[ -n "$SERVER_IP" && "$SERVER_IP" != "None" ]]; then
    log "Server IP: $SERVER_IP"
    warn "To SSH into the instance, run:"
    warn "  ssh -i ~/.ssh/your-key.pem $SSH_USER@$SERVER_IP"
    warn ""
    warn "Once connected, verify:"
    warn "  cat /etc/os-release | grep '^ID='  # Should show: ID=$EXPECTED_OS_ID"
    warn "  which $EXPECTED_PKG_MGR"
    warn "  docker ps"
    warn "  consul version && nomad version"
    warn "  tail -50 /var/log/provision.log"
  else
    error "Could not retrieve server IP"
  fi
  fi  # End of service tests if block

  # Summary
  log ""
  log "============================================"
  log "  Test Summary for $OS_TYPE_UPPER ($TEST_MODE mode)"
  log "============================================"
  log "Server LB:    $SERVER_LB"
  log "Client LB:    $CLIENT_LB"
  log "SSH User:     $SSH_USER"
  log "Server IP:    ${SERVER_IP:-N/A}"
  log ""
  log "Logs saved to: $LOG_DIR/"
  log ""
  warn "⚠️  IMPORTANT: Infrastructure is still running!"
  warn "   To destroy and cleanup, run:"
  warn "   cd $TERRAFORM_DIR"
  warn "   terraform destroy -auto-approve"
  log ""
  log "============================================"
  log "  Next Steps:"
  log "============================================"
  if [[ -n "$SERVER_LB" && -n "$CLIENT_LB" ]]; then
    log "1. Open UIs in browser to verify functionality"
    log "2. SSH into instance to verify OS-specific settings"
    if [[ "$OS_TYPE" == "windows" || "$OS_TYPE" == "mixed" ]]; then
      log "   For Windows: Use RDP or AWS Systems Manager Session Manager"
      log "   Windows instances use node class: hashistack-windows"
    fi
    if [[ "$OS_TYPE" == "mixed" ]]; then
      log "   Linux instances use node class: hashistack-linux"
    fi
    log "3. Test autoscaling by generating load:"
    log "   for i in {1..100}; do curl http://$CLIENT_LB; sleep 1; done"
    log "4. Monitor Grafana: http://$CLIENT_LB:3000/d/AQphTqmMk/demo"
    log "5. Verify node classes in Nomad UI:"
    log "   http://$SERVER_LB:4646/ui/clients"
    log "6. When done testing, destroy infrastructure"
  else
    log "1. Check terraform outputs for connection details:"
    log "   cd $TERRAFORM_DIR && terraform output"
    log "2. SSH into instance to verify OS-specific settings"
    log "3. When done testing, destroy infrastructure"
  fi
  log ""

  # Save test report
  REPORT_FILE="$LOG_DIR/test-report-$OS_TYPE-$TIMESTAMP.txt"
  cat > "$REPORT_FILE" << EOF
Multi-OS Test Report
====================
OS Type:      $OS_TYPE_UPPER
Test Mode:    $TEST_MODE
Date:         $(date)

Infrastructure:
--------------
Server LB:    ${SERVER_LB:-N/A}
Client LB:    ${CLIENT_LB:-N/A}
Server IP:    ${SERVER_IP:-N/A}
SSH User:     $SSH_USER

Service Status:
--------------
Consul UI:    http://${SERVER_LB:-N/A}:8500/ui
Nomad UI:     http://${SERVER_LB:-N/A}:4646/ui
Grafana:      http://${CLIENT_LB:-N/A}:3000
Web App:      http://${CLIENT_LB:-N/A}

Cluster Info:
------------
Consul Members: ${CONSUL_MEMBERS:-N/A}
Nomad Nodes:    ${NOMAD_NODES:-N/A}

Logs:
----
Terraform Init:  $LOG_DIR/terraform-init-$OS_TYPE-$TIMESTAMP.log
Terraform Plan:  $LOG_DIR/terraform-plan-$OS_TYPE-$TIMESTAMP.log
Terraform Apply: $LOG_DIR/terraform-apply-$OS_TYPE-$TIMESTAMP.log
Outputs:         $LOG_DIR/outputs-$OS_TYPE-$TIMESTAMP.json
EOF

  log "Test report saved to: $REPORT_FILE"
fi

log ""
log "✅ Testing complete!"
