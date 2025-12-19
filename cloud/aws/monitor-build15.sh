#!/bin/bash
# Monitor Build 15 - Windows Node Registration

export NOMAD_ADDR=http://mws-scale-ubuntu-server-1503690957.us-west-2.elb.amazonaws.com:4646

echo "============================================"
echo "  Build 15 Monitoring"
echo "  Started: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo "============================================"
echo ""

# Wait 5 minutes for Windows instance to configure
echo "Waiting 5 minutes for Windows instance to configure..."
echo "Expected completion: 07:01 UTC"
echo ""

for i in {1..30}; do
    echo "Check $i/30 ($(date -u +"%H:%M:%S UTC")):"
    
    # Check node status
    NODES=$(nomad node status 2>&1)
    
    if echo "$NODES" | grep -q "No nodes registered"; then
        echo "  ⏳ No nodes registered yet"
    else
        echo "  ✅ Nodes found!"
        echo "$NODES"
        
        # Check for Windows node
        if echo "$NODES" | grep -q "hashistack-windows"; then
            echo ""
            echo "🎉 SUCCESS! Windows node has joined the cluster!"
            echo ""
            
            # Get Windows node details
            WINDOWS_NODE=$(nomad node status -json | jq -r '.[] | select(.NodeClass=="hashistack-windows") | .ID' | head -1)
            echo "Windows Node ID: $WINDOWS_NODE"
            echo ""
            echo "Node Details:"
            nomad node status "$WINDOWS_NODE"
            exit 0
        fi
    fi
    
    echo ""
    sleep 10
done

echo "❌ Timeout: Windows node did not join cluster after 5 minutes"
echo "Next steps: Connect via SSM to debug"
exit 1

# Made with Bob
