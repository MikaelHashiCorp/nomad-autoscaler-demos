#!/bin/bash
# Monitor Build 18 - Windows-only deployment with systematic troubleshooting

export NOMAD_ADDR=http://mws-scale-ubuntu-server-934743196.us-west-2.elb.amazonaws.com:4646

echo "==================================="
echo "Build 18 Monitoring - Windows-Only"
echo "==================================="
echo "Time: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "=== CONFIGURATION ==="
grep -E "client_count|windows_client_count" terraform/control/terraform.tfvars
echo ""

echo "=== NOMAD NODES ==="
nomad node status 2>&1
echo ""

echo "=== JOB STATUS ==="
nomad job status 2>&1
echo ""

echo "=== ALLOCATION SUMMARY ==="
for job in grafana prometheus traefik webapp; do
    echo "--- $job ---"
    nomad job status $job 2>&1 | grep -A 5 "Allocations" || echo "Job not found"
    echo ""
done

echo "=== WINDOWS NODE DETAILS ==="
WINDOWS_NODE=$(nomad node status 2>&1 | grep "hashistack-windows" | awk '{print $1}')
if [ -n "$WINDOWS_NODE" ]; then
    echo "Windows Node ID: $WINDOWS_NODE"
    nomad node status $WINDOWS_NODE 2>&1 | grep -E "ID|Status|Eligibility|Uptime"
    echo ""
    echo "Windows Node Allocations:"
    nomad node status $WINDOWS_NODE 2>&1 | grep -A 10 "Allocations"
else
    echo "No Windows node found yet"
fi
echo ""

echo "=== DEPLOYMENT HEALTH ==="
for job in grafana prometheus webapp; do
    echo "--- $job deployment ---"
    nomad job status $job 2>&1 | grep -A 8 "Latest Deployment" || echo "No deployment info"
    echo ""
done

echo "==================================="
echo "Monitoring complete: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "==================================="

# Made with Bob
