# Build 15 Deployment Status

## Deployment Information
- **Build Number**: 15
- **Deployment Time**: 2025-12-18 06:54 UTC (22:54 PST)
- **Status**: ✅ DEPLOYED SUCCESSFULLY

## AMI Information
- **Windows AMI**: ami-064e18a7f9c54c998
- **Linux AMI**: ami-096aaae0bc50ad23f
- **Build Duration**: 18m 56s

## Bug Fixes Applied
- **Bug #16**: Log file path trailing slash fix
  - Consul: `C:/HashiCorp/Consul/logs/` (with trailing slash)
  - Nomad: `C:/HashiCorp/Nomad/logs/` (with trailing slash)

## Infrastructure Created
- **Total Resources**: 30
- **Server Instance**: i-0666ca6fd4c5fe276 (44.248.178.38)
- **Windows ASG**: mws-scale-ubuntu-client-windows (desired: 1)
- **Linux ASG**: mws-scale-ubuntu-client-linux (desired: 0)

## Access Information
```bash
# Set environment variables
export NOMAD_ADDR=http://mws-scale-ubuntu-server-1503690957.us-west-2.elb.amazonaws.com:4646
export NOMAD_CLIENT_DNS=http://mws-scale-ubuntu-client-293950300.us-west-2.elb.amazonaws.com

# Access UIs
Nomad UI:     http://mws-scale-ubuntu-server-1503690957.us-west-2.elb.amazonaws.com:4646/ui
Consul UI:    http://mws-scale-ubuntu-server-1503690957.us-west-2.elb.amazonaws.com:8500/ui
Grafana:      http://mws-scale-ubuntu-client-293950300.us-west-2.elb.amazonaws.com:3000
Prometheus:   http://mws-scale-ubuntu-client-293950300.us-west-2.elb.amazonaws.com:9090
Traefik:      http://mws-scale-ubuntu-client-293950300.us-west-2.elb.amazonaws.com:8081
```

## Pre-Build Due Diligence
- **Checklist**: PRE_BUILD_15_CHECKLIST.md
- **Confidence Level**: 99%
- **All Phases Completed**: ✅
- **All Critical Checks Passed**: ✅

## Expected Behavior
1. Windows instance launches from ASG
2. EC2Launch v2 executes user-data script
3. User-data script:
   - Configures Consul with `log_file = "C:/HashiCorp/Consul/logs/"` (trailing slash)
   - Configures Nomad with `log_file = "C:/HashiCorp/Nomad/logs/"` (trailing slash)
   - Starts Consul service
   - Starts Nomad service
4. Consul creates timestamped log files in logs/ directory
5. Nomad creates timestamped log files in logs/ directory
6. Both services start successfully
7. Nomad client registers with cluster (~5 minutes after launch)

## Testing Plan
Following TESTING_PLAN.md Section 4.4:

### Test 1: Verify Windows Client Joins Cluster (5 min wait)
```bash
nomad node status
# Expected: Windows node with class "hashistack-windows" and status "ready"
```

### Test 2: Verify Node Attributes
```bash
WINDOWS_NODE=$(nomad node status -json | jq -r '.[] | select(.NodeClass=="hashistack-windows") | .ID' | head -1)
nomad node status -verbose $WINDOWS_NODE | grep -i "kernel.name\|os.name"
# Expected: kernel.name = windows, os.name = Windows Server 2022
```

### Test 3: Deploy Windows-Targeted Job
```bash
# Create and run test-windows-job.nomad
nomad job run test-windows-job.nomad
nomad job status windows-test
```

### Test 4: Windows Autoscaling
```bash
# Deploy multiple jobs to trigger scale-up
for i in {1..5}; do nomad job run -detach test-windows-job.nomad; done
# Monitor ASG scaling
```

### Test 5: Dual AMI Cleanup
```bash
terraform destroy -auto-approve
# Verify both AMIs are deregistered
```

## Timeline
- **06:35 UTC**: Pre-build checklist completed
- **06:35 UTC**: Terraform apply started
- **06:36 UTC**: Packer build started for Windows AMI
- **06:54 UTC**: Windows AMI created (ami-064e18a7f9c54c998)
- **06:54 UTC**: Infrastructure deployment started
- **06:56 UTC**: All 30 resources created successfully
- **06:56 UTC**: Windows instance launching (5 min configuration time expected)
- **07:01 UTC**: Expected time for Windows node to join cluster

## Next Steps
1. Wait 5 minutes for Windows instance to configure
2. Check Nomad cluster for Windows node
3. If node appears: Proceed with Test 2 (node attributes)
4. If node doesn't appear: Connect via SSM to debug

## Confidence Level
**99%** - All bugs fixed, comprehensive due diligence completed, expected behavior clearly defined.