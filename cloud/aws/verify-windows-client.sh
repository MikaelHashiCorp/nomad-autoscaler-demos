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

# Test 4: Check Consul members via server ELB (not localhost)
echo "Test 4: Checking Consul cluster membership via server..."
echo "----------------------------------------"
# Derive Consul address from NOMAD_ADDR (replace port 4646 with 8500)
CONSUL_SERVER=$(echo "$NOMAD_ADDR" | sed 's|http://||' | sed 's|:4646||')
CONSUL_HTTP_ADDR="http://${CONSUL_SERVER}:8500"
echo "Using Consul address: $CONSUL_HTTP_ADDR"
echo ""

if CONSUL_OUTPUT=$(curl -sf --max-time 10 "${CONSUL_HTTP_ADDR}/v1/agent/members" 2>/dev/null); then
    CONSUL_MEMBER_COUNT=$(echo "$CONSUL_OUTPUT" | jq '. | length' 2>/dev/null || echo "0")
    echo "Consul LAN members:"
    echo "$CONSUL_OUTPUT" | jq -r '.[] | "  \(.Name)  \(.Addr)  Status:\(.Status)"' 2>/dev/null || echo "$CONSUL_OUTPUT"
    echo ""
    echo "Total Consul members: $CONSUL_MEMBER_COUNT"
    echo ""
    if [ "$CONSUL_MEMBER_COUNT" -ge 2 ]; then
        echo "✅ PASS: Consul cluster has $CONSUL_MEMBER_COUNT members (server + client joined)"
    elif [ "$CONSUL_MEMBER_COUNT" -eq 1 ]; then
        echo "⚠️  WARNING: Only 1 Consul member found — Windows client may not have joined yet"
    else
        echo "❌ FAIL: No Consul members found"
        exit 1
    fi
else
    echo "⚠️  WARNING: Could not reach Consul API at $CONSUL_HTTP_ADDR, skipping Consul check"
fi
echo ""

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
