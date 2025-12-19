#!/bin/bash

# Build 16 Monitoring Script - Windows-Only Deployment
# Monitors Windows instance joining cluster and job status

export NOMAD_ADDR=http://mws-scale-ubuntu-server-934743196.us-west-2.elb.amazonaws.com:4646

echo "=== Build 16 Monitoring - Windows-Only Deployment ==="
echo "Started: $(date)"
echo "Configuration: client_count=0, windows_client_count=1"
echo ""

# Wait 5 minutes for Windows instance to configure
echo "Waiting 5 minutes for Windows instance to configure..."
for i in {1..30}; do
    echo -n "."
    sleep 10
done
echo ""
echo ""

# Check node status
echo "=== Checking Nomad Nodes ==="
nomad node status
echo ""

# Check for Windows node
WINDOWS_NODE=$(nomad node status -json | jq -r '.[] | select(.NodeClass=="hashistack-windows") | .ID' 2>/dev/null | head -1)

if [ -n "$WINDOWS_NODE" ]; then
    echo "✅ Windows node found: $WINDOWS_NODE"
    echo ""
    echo "=== Windows Node Details ==="
    nomad node status "$WINDOWS_NODE" | head -20
    echo ""
else
    echo "❌ No Windows node found yet"
    echo ""
fi

# Check job status
echo "=== Checking Job Status ==="
nomad job status
echo ""

# Check for pending jobs
PENDING_JOBS=$(nomad job status -json | jq -r '.[] | select(.Status=="pending") | .ID' 2>/dev/null)

if [ -n "$PENDING_JOBS" ]; then
    echo "⚠️  Pending jobs detected:"
    echo "$PENDING_JOBS"
    echo ""
    
    for job in $PENDING_JOBS; do
        echo "=== Job: $job ==="
        nomad job status "$job" | grep -A 10 "Allocations"
        echo ""
    done
else
    echo "✅ No pending jobs"
fi

# Check for failed allocations
echo "=== Checking for Failed Allocations ==="
nomad job status -json | jq -r '.[] | .ID' | while read job; do
    FAILED=$(nomad job status "$job" 2>/dev/null | grep -c "failed" || true)
    if [ "$FAILED" -gt 0 ]; then
        echo "⚠️  Job $job has failed allocations"
    fi
done
echo ""

echo "=== Monitoring Complete ==="
echo "Finished: $(date)"

# Made with Bob
