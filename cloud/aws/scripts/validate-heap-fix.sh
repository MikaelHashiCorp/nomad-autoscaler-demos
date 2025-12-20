#!/bin/bash
# Validate Windows Desktop Heap Fix and Run Test Job
# This script validates that the fix was applied and then runs the heap stress test

set -euo pipefail

WINDOWS_IP="${1:-34.222.139.178}"
SSH_KEY="${2:-$HOME/.ssh/mhc-aws-mws-west-2.pem}"
SSH_USER="Administrator"
NOMAD_ADDR="http://mws-scale-ubuntu-server-495511731.us-west-2.elb.amazonaws.com:4646"
JOB_FILE="/Users/mikael/2-git/repro/nomad-autoscaler-demos/1-win-bob/cloud/aws/jobs/windows-heap-test.nomad"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== Validating Desktop Heap Fix and Running Test ===${NC}"
echo ""

# Step 1: Wait for Windows node to be ready
echo -e "${YELLOW}Step 1: Waiting for Windows node to reconnect to Nomad cluster...${NC}"
export NOMAD_ADDR="$NOMAD_ADDR"
for i in {1..30}; do
    NODE_STATUS=$(nomad node status | grep "EC2AMAZ" | awk '{print $NF}')
    if [ "$NODE_STATUS" == "ready" ]; then
        echo -e "${GREEN}✓ Windows node is ready!${NC}"
        echo ""
        break
    fi
    echo "  Attempt $i/30: Node status is '$NODE_STATUS', waiting..."
    sleep 10
done

if [ "$NODE_STATUS" != "ready" ]; then
    echo -e "${RED}ERROR: Windows node did not become ready after 5 minutes${NC}"
    exit 1
fi

# Step 2: Verify the fix was applied
echo -e "${YELLOW}Step 2: Verifying desktop heap fix was applied...${NC}"
HEAP_OUTPUT=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "${SSH_USER}@${WINDOWS_IP}" \
    "powershell.exe -Command \"(Get-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\SubSystems' -Name 'Windows').Windows\"")

echo "Registry value: $HEAP_OUTPUT" | head -c 200
echo ""

# Extract the third value from SharedSection (non-interactive heap)
HEAP_VALUE=$(echo "$HEAP_OUTPUT" | grep -o 'SharedSection=[0-9]*,[0-9]*,[0-9]*' | cut -d'=' -f2 | cut -d',' -f3)

echo "  Non-Interactive Heap: $HEAP_VALUE KB"
if [ "$HEAP_VALUE" == "4096" ]; then
    echo -e "${GREEN}✓ Fix verified: Desktop heap is set to 4096 KB${NC}"
    echo ""
else
    echo -e "${RED}ERROR: Desktop heap is $HEAP_VALUE KB (expected 4096 KB)${NC}"
    echo "Full output: $HEAP_OUTPUT"
    exit 1
fi

# Step 3: Deploy the test job
echo -e "${YELLOW}Step 3: Deploying 80-allocation stress test job...${NC}"
nomad job run "$JOB_FILE"
echo ""

# Step 4: Monitor deployment
echo -e "${YELLOW}Step 4: Monitoring deployment...${NC}"
echo "  Waiting 60 seconds for allocations to place..."
sleep 60

# Check job status
echo ""
echo -e "${CYAN}=== Job Status ===${NC}"
nomad job status windows-heap-test | head -20

echo ""
echo -e "${CYAN}=== Allocation Summary ===${NC}"
nomad job status windows-heap-test | grep "heap-stress" | head -1

echo ""
echo -e "${GREEN}Validation complete!${NC}"
echo ""
echo "View in Nomad UI:"
echo "  $NOMAD_ADDR/ui/jobs/windows-heap-test@default"
