#!/bin/bash
# Monitor Build 14 Windows Node Registration

export NOMAD_ADDR=http://mws-scale-ubuntu-server-434870546.us-west-2.elb.amazonaws.com:4646
INSTANCE_ID="i-0e6717b7bebf82974"
LAUNCH_TIME="2025-12-18T05:11:47+00:00"

echo "=== Build 14 Monitoring ==="
echo "Instance: $INSTANCE_ID"
echo "Launch Time: $LAUNCH_TIME"
echo "Current Time: $(date -u +"%Y-%m-%dT%H:%M:%S+00:00")"
echo ""

# Calculate elapsed time since launch
LAUNCH_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S+00:00" "$LAUNCH_TIME" +%s 2>/dev/null || date -d "$LAUNCH_TIME" +%s 2>/dev/null)
CURRENT_EPOCH=$(date +%s)
ELAPSED=$((CURRENT_EPOCH - LAUNCH_EPOCH))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

echo "Time since launch: ${MINUTES}m ${SECONDS}s"
echo ""

# Check Nomad nodes
echo "=== Nomad Node Status ==="
NODES=$(nomad node status 2>&1)
if echo "$NODES" | grep -q "No nodes registered"; then
    echo "❌ No nodes registered yet"
    echo "   Expected: User-data typically takes 3-5 minutes"
    echo "   Action: Wait and check again in 1-2 minutes"
elif echo "$NODES" | grep -q "hashistack-windows"; then
    echo "✅ Windows node registered!"
    echo ""
    nomad node status
    echo ""
    echo "=== Next Steps ==="
    echo "1. Run: ./verify-windows-client.sh"
    echo "2. Check node details with node ID from above"
else
    echo "⚠️  Nodes registered but no Windows node yet:"
    echo "$NODES"
fi

echo ""
echo "=== Quick Commands ==="
echo "Check again:        ./monitor-build14.sh"
echo "Connect via SSM:    aws ssm start-session --region us-west-2 --target $INSTANCE_ID"
echo "Full verification:  ./verify-windows-client.sh"

# Made with Bob
