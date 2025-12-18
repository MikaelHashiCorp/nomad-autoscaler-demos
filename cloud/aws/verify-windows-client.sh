#!/bin/bash
# Verify Windows Client Deployment
# This script checks if Windows clients have successfully joined the Nomad cluster

set -e

echo "============================================"
echo "  Windows Client Verification"
echo "============================================"
echo ""

# Check if NOMAD_ADDR is set
if [ -z "$NOMAD_ADDR" ]; then
    echo "❌ ERROR: NOMAD_ADDR environment variable not set"
    echo "   Please set it to your Nomad server address:"
    echo "   export NOMAD_ADDR=http://<server-lb-dns>:4646"
    exit 1
fi

echo "Using Nomad server: $NOMAD_ADDR"
echo ""

# Test 1: Check all Nomad nodes
echo "Test 1: Checking Nomad node status..."
echo "----------------------------------------"
nomad node status
echo ""

# Test 2: Count nodes by class
echo "Test 2: Node class distribution..."
echo "----------------------------------------"
LINUX_NODES=$(nomad node status -json | jq -r '.[] | select(.NodeClass=="hashistack-linux") | .ID' | wc -l | tr -d ' ')
WINDOWS_NODES=$(nomad node status -json | jq -r '.[] | select(.NodeClass=="hashistack-windows") | .ID' | wc -l | tr -d ' ')

echo "Linux nodes (hashistack-linux):     $LINUX_NODES"
echo "Windows nodes (hashistack-windows): $WINDOWS_NODES"
echo ""

if [ "$WINDOWS_NODES" -eq 0 ]; then
    echo "❌ FAIL: No Windows nodes found!"
    exit 1
else
    echo "✅ PASS: Found $WINDOWS_NODES Windows node(s)"
fi
echo ""

# Test 3: Get Windows node details
echo "Test 3: Windows node attributes..."
echo "----------------------------------------"
WINDOWS_NODE_ID=$(nomad node status -json | jq -r '.[] | select(.NodeClass=="hashistack-windows") | .ID' | head -1)

if [ -z "$WINDOWS_NODE_ID" ]; then
    echo "❌ ERROR: Could not find Windows node ID"
    exit 1
fi

echo "Windows Node ID: $WINDOWS_NODE_ID"
echo ""
echo "OS Information:"
nomad node status -verbose "$WINDOWS_NODE_ID" | grep -E "kernel.name|os.name|os.version" || echo "  (OS attributes not found)"
echo ""

echo "Driver Status:"
nomad node status -verbose "$WINDOWS_NODE_ID" | grep -E "driver.docker|driver.exec|driver.raw_exec" || echo "  (Driver attributes not found)"
echo ""

# Test 4: Check Consul members
echo "Test 4: Checking Consul cluster..."
echo "----------------------------------------"
if command -v consul &> /dev/null; then
    consul members
    echo ""
    
    CONSUL_MEMBERS=$(consul members | wc -l | tr -d ' ')
    # Subtract 1 for header line
    CONSUL_MEMBERS=$((CONSUL_MEMBERS - 1))
    echo "Total Consul members: $CONSUL_MEMBERS"
    echo ""
else
    echo "⚠️  WARNING: consul CLI not available, skipping Consul check"
    echo ""
fi

# Test 5: Check node health
echo "Test 5: Node health status..."
echo "----------------------------------------"
NODE_STATUS=$(nomad node status -json "$WINDOWS_NODE_ID" | jq -r '.Status')
NODE_ELIGIBILITY=$(nomad node status -json "$WINDOWS_NODE_ID" | jq -r '.SchedulingEligibility')

echo "Status:       $NODE_STATUS"
echo "Eligibility:  $NODE_ELIGIBILITY"
echo ""

if [ "$NODE_STATUS" != "ready" ]; then
    echo "❌ FAIL: Node status is not 'ready'"
    exit 1
fi

if [ "$NODE_ELIGIBILITY" != "eligible" ]; then
    echo "❌ FAIL: Node is not eligible for scheduling"
    exit 1
fi

echo "✅ PASS: Node is ready and eligible"
echo ""

# Summary
echo "============================================"
echo "  Verification Summary"
echo "============================================"
echo "✅ Windows client successfully joined cluster"
echo "✅ Node class: hashistack-windows"
echo "✅ Node status: ready"
echo "✅ Scheduling: eligible"
echo ""
echo "Next steps:"
echo "1. Deploy a Windows-targeted test job"
echo "2. Test autoscaling behavior"
echo "3. Verify service health via SSM"
echo ""

# Made with Bob
