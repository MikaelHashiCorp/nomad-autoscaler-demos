#!/bin/bash
# Post-Deployment Verification Script
# Validates that all services are running and DNS resolution is working

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[✓]${NC} $*"
}

log_error() {
  echo -e "${RED}[✗]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[!]${NC} $*"
}

# Get Terraform outputs
cd terraform/control

log_info "Fetching Terraform outputs..."
NOMAD_SERVER_LB=$(terraform output -raw ip_addresses | grep "Nomad UI" | sed 's/.*http:\/\/\(.*\):4646.*/\1/')
CLIENT_LB=$(terraform output -raw ip_addresses | grep "Grafana dashboard" | sed 's/.*http:\/\/\(.*\):3000.*/\1/')
AWS_REGION=$(terraform output -json | jq -r '.ip_addresses.value' | grep -o 'us-[a-z]*-[0-9]*' | head -1)

# If region not found in outputs, read from terraform.tfvars
if [ -z "$AWS_REGION" ]; then
  if [ -f "terraform.tfvars" ]; then
    AWS_REGION=$(grep '^region' terraform.tfvars | sed 's/region[[:space:]]*=[[:space:]]*"\(.*\)"/\1/' | tr -d ' ')
  fi
fi

# Final fallback
if [ -z "$AWS_REGION" ]; then
  log_warn "Could not determine AWS region, using default: us-west-2"
  AWS_REGION="us-west-2"
fi

if [ -z "$NOMAD_SERVER_LB" ]; then
  log_error "Could not determine Nomad server load balancer address"
  exit 1
fi

export NOMAD_ADDR="http://${NOMAD_SERVER_LB}:4646"

log_info "Using NOMAD_ADDR: $NOMAD_ADDR"
log_info "Using AWS Region: ${AWS_REGION}"
log_info ""

# Test 1: Nomad Node Status
log_info "Test 1: Checking Nomad node status..."
if NODE_OUTPUT=$(nomad node status 2>&1); then
  NODE_COUNT=$(echo "$NODE_OUTPUT" | grep -c "ready" || true)
  if [ "$NODE_COUNT" -gt 0 ]; then
    log_success "Found $NODE_COUNT ready Nomad client node(s)"
    
    # Get first node ID
    NODE_ID=$(echo "$NODE_OUTPUT" | grep "ready" | head -1 | awk '{print $1}')
    log_info "   Node ID: $NODE_ID"
  else
    log_warn "No ready nodes found yet (may still be starting up)"
  fi
else
  log_error "Failed to query Nomad node status"
  exit 1
fi
echo ""

# Test 2: Get Client Instance IP
log_info "Test 2: Finding client instance IP address..."

# Check if AWS credentials are available
if ! aws sts get-caller-identity --region "${AWS_REGION}" >/dev/null 2>&1; then
  log_warn "AWS credentials not found. Skipping client IP lookup."
  log_warn "   To authenticate: doormat login -f && eval \$(doormat aws export --account <account>)"
  CLIENT_IP=""
else
  CLIENT_IP=$(aws ec2 describe-instances \
    --region "${AWS_REGION}" \
    --filters "Name=tag:Name,Values=*-client" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text 2>/dev/null || echo "")

  if [ -n "$CLIENT_IP" ] && [ "$CLIENT_IP" != "None" ]; then
    log_success "Client instance IP: $CLIENT_IP"
  else
    log_warn "Could not retrieve client instance IP (may not be needed if jobs are running)"
    CLIENT_IP=""
  fi
fi
echo ""

# Test 3: Nomad Job Status
log_info "Test 3: Checking Nomad job status..."
if JOB_OUTPUT=$(nomad job status 2>&1); then
  RUNNING_JOBS=$(echo "$JOB_OUTPUT" | grep -c "running" || true)
  
  if [ "$RUNNING_JOBS" -gt 0 ]; then
    log_success "Found $RUNNING_JOBS running job(s):"
    echo "$JOB_OUTPUT" | grep "running" | while read -r line; do
      JOB_NAME=$(echo "$line" | awk '{print $1}')
      log_success "   - $JOB_NAME"
    done
  else
    log_error "No running jobs found"
    echo "$JOB_OUTPUT"
    exit 1
  fi
else
  log_error "Failed to query Nomad jobs"
  exit 1
fi
echo ""

# Test 4: Webapp Job Detailed Status (key DNS verification)
log_info "Test 4: Checking webapp job allocation status (verifies DNS/Docker pulls)..."
if WEBAPP_STATUS=$(nomad job status webapp 2>&1); then
  RUNNING_ALLOCS=$(echo "$WEBAPP_STATUS" | grep "^demo" | awk '{print $3}' | tr -d '\r\n ')
  FAILED_ALLOCS=$(echo "$WEBAPP_STATUS" | grep "^demo" | awk '{print $4}' | tr -d '\r\n ')
  
  if [ "$RUNNING_ALLOCS" -gt 0 ]; then
    log_success "Webapp has $RUNNING_ALLOCS running allocation(s)"
    
    # Get allocation ID and check events
    ALLOC_ID=$(echo "$WEBAPP_STATUS" | grep -A20 "Allocations" | grep "run" | head -1 | awk '{print $1}')
    if [ -n "$ALLOC_ID" ]; then
      log_info "   Checking allocation $ALLOC_ID for Docker pull errors..."
      
      if ALLOC_EVENTS=$(nomad alloc status "$ALLOC_ID" 2>&1 | grep -A10 "Recent Events"); then
        if echo "$ALLOC_EVENTS" | grep -qi "error\|failed"; then
          log_error "Found errors in allocation events:"
          echo "$ALLOC_EVENTS" | grep -i "error\|failed"
          exit 1
        else
          log_success "   No errors found in allocation events"
          if echo "$ALLOC_EVENTS" | grep -q "Downloading image"; then
            log_success "   Docker image download completed successfully (DNS working!)"
          fi
        fi
      fi
    fi
  else
    log_error "Webapp has no running allocations (Failed: $FAILED_ALLOCS)"
    echo "$WEBAPP_STATUS"
    exit 1
  fi
else
  log_error "Failed to query webapp job status"
  exit 1
fi
echo ""

# Test 5: Service Endpoint HTTP Status
log_info "Test 5: Testing service endpoint accessibility..."

test_endpoint() {
  local NAME=$1
  local URL=$2
  local EXPECTED_CODES=$3
  
  if HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" 2>/dev/null); then
    if echo "$EXPECTED_CODES" | grep -q "$HTTP_CODE"; then
      log_success "   $NAME: HTTP $HTTP_CODE ✓"
      return 0
    else
      log_warn "   $NAME: HTTP $HTTP_CODE (expected: $EXPECTED_CODES)"
      return 1
    fi
  else
    log_error "   $NAME: Failed to connect"
    return 1
  fi
}

ENDPOINTS_OK=true

test_endpoint "Consul UI    " "http://${NOMAD_SERVER_LB}:8500/ui" "200|301|302" || ENDPOINTS_OK=false
test_endpoint "Nomad UI     " "http://${NOMAD_SERVER_LB}:4646/ui" "200|301|302" || ENDPOINTS_OK=false
test_endpoint "Grafana      " "http://${CLIENT_LB}:3000" "200|302" || ENDPOINTS_OK=false
test_endpoint "Prometheus   " "http://${CLIENT_LB}:9090" "200|302" || ENDPOINTS_OK=false
test_endpoint "Webapp       " "http://${CLIENT_LB}:80" "200" || ENDPOINTS_OK=false

if [ "$ENDPOINTS_OK" = false ]; then
  log_warn "Some endpoints are not accessible yet (may still be starting)"
else
  log_success "All service endpoints are accessible"
fi
echo ""

# Test 6: Webapp Response Content
log_info "Test 6: Testing webapp response content..."
if WEBAPP_RESPONSE=$(curl -s --max-time 10 "http://${CLIENT_LB}:80" 2>/dev/null); then
  if echo "$WEBAPP_RESPONSE" | grep -q "Welcome"; then
    log_success "Webapp returned expected content:"
    log_success "   $(echo "$WEBAPP_RESPONSE" | head -1)"
  else
    log_warn "Webapp returned unexpected content: $WEBAPP_RESPONSE"
  fi
else
  log_error "Failed to get webapp response"
fi
echo ""

# Summary
echo "═══════════════════════════════════════════════════════════════"
log_success "VERIFICATION COMPLETE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Service URLs:"
echo "  Nomad UI:    http://${NOMAD_SERVER_LB}:4646/ui"
echo "  Consul UI:   http://${NOMAD_SERVER_LB}:8500/ui"
echo "  Grafana:     http://${CLIENT_LB}:3000/d/AQphTqmMk/demo"
echo "  Prometheus:  http://${CLIENT_LB}:9090"
echo "  Webapp:      http://${CLIENT_LB}:80"
echo ""
if [ -n "$CLIENT_IP" ]; then
  echo "Client Node: ssh ec2-user@${CLIENT_IP}"
  echo ""
fi
echo "To destroy infrastructure:"
echo "  cd terraform/control && terraform destroy -auto-approve"
echo ""
