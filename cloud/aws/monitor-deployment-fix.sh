#!/bin/bash
# Monitor deployment fix - Wait for Linux client and jobs to stabilize
# TIMEOUT: 5 minutes (30 checks x 10 seconds)

export NOMAD_ADDR=http://mws-scale-ubuntu-server-1503690957.us-west-2.elb.amazonaws.com:4646

echo "============================================"
echo "  Deployment Fix Monitoring"
echo "  Started: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo "  Timeout: 5 minutes"
echo "============================================"
echo ""
echo "Waiting for Linux client to join cluster and jobs to stabilize..."
echo ""

for i in {1..30}; do
    echo "Check $i/30 ($(date -u +"%H:%M:%S UTC")):"
    
    # Check node status
    NODES=$(nomad node status 2>&1)
    
    if echo "$NODES" | grep -q "Connection refused\|timeout"; then
        echo "  ⏳ Cannot connect to Nomad server yet"
    else
        # Count nodes
        LINUX_CLIENTS=$(echo "$NODES" | grep -c "hashistack-linux" || echo "0")
        WINDOWS_CLIENTS=$(echo "$NODES" | grep -c "hashistack-windows" || echo "0")
        
        echo "  Nodes: Linux clients=$LINUX_CLIENTS, Windows clients=$WINDOWS_CLIENTS"
        
        # Check job status
        JOBS=$(nomad job status 2>&1)
        
        if echo "$JOBS" | grep -q "No jobs"; then
            echo "  ⏳ No jobs found"
        else
            RUNNING=$(echo "$JOBS" | grep -c "running" || echo "0")
            PENDING=$(echo "$JOBS" | grep -c "pending" || echo "0")
            
            echo "  Jobs: Running=$RUNNING, Pending=$PENDING"
            
            # Check if all critical jobs are running
            if [ "$LINUX_CLIENTS" -ge 1 ] && [ "$WINDOWS_CLIENTS" -ge 1 ]; then
                echo ""
                echo "✅ Both node types present!"
                
                # Check specific jobs
                GRAFANA=$(nomad job status grafana 2>&1 | grep "Status" | awk '{print $3}')
                PROMETHEUS=$(nomad job status prometheus 2>&1 | grep "Status" | awk '{print $3}')
                WEBAPP=$(nomad job status webapp 2>&1 | grep "Status" | awk '{print $3}')
                TRAEFIK=$(nomad job status traefik 2>&1 | grep "Status" | awk '{print $3}')
                
                echo "  grafana: $GRAFANA"
                echo "  prometheus: $PROMETHEUS"
                echo "  webapp: $WEBAPP"
                echo "  traefik: $TRAEFIK"
                
                if [ "$GRAFANA" = "running" ] && [ "$PROMETHEUS" = "running" ] && [ "$WEBAPP" = "running" ] && [ "$TRAEFIK" = "running" ]; then
                    echo ""
                    echo "🎉 SUCCESS! All infrastructure jobs are running!"
                    echo ""
                    echo "Final Status:"
                    nomad job status
                    exit 0
                fi
            fi
        fi
    fi
    
    echo ""
    sleep 10
done

echo "❌ FAILURE: Jobs did not stabilize within 5 minutes"
echo ""
echo "Current status:"
nomad node status 2>&1 || echo "Cannot connect to Nomad"
echo ""
nomad job status 2>&1 || echo "Cannot get job status"
exit 1

# Made with Bob
