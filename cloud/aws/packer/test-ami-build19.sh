#!/bin/bash
# Build 19 - Test Windows AMI with Bug #17 Fix
# Fix: Added servers configuration to nomad_client.hcl

set -e

echo "=========================================="
echo "Build 19 - Windows AMI with Bug #17 Fix"
echo "=========================================="
echo ""
echo "Fix Applied: Added servers configuration"
echo "  servers = [\"provider=aws tag_key=ConsulAutoJoin tag_value=auto-join\"]"
echo ""
echo "Expected Outcome:"
echo "  - Windows-only deployment should work"
echo "  - All allocations should reach 'running' state"
echo "  - No 'Permission denied' RPC errors"
echo ""

# Source environment variables
if [ -f ./env-pkr-var.sh ]; then
    source ./env-pkr-var.sh
else
    echo "Error: env-pkr-var.sh not found"
    exit 1
fi

# Verify the fix is in place
echo "Verifying fix is applied..."
if grep -q "servers = " ../../shared/packer/config/nomad_client.hcl; then
    echo "✅ Fix confirmed: servers configuration present"
    grep "servers = " ../../shared/packer/config/nomad_client.hcl
else
    echo "❌ ERROR: Fix not found in nomad_client.hcl"
    exit 1
fi
echo ""

# Build Windows AMI
echo "Building Windows AMI..."
echo ""
packer build \
    -var-file=windows-2022.pkrvars.hcl \
    aws-packer.pkr.hcl

echo ""
echo "=========================================="
echo "Build 19 AMI Creation Complete"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Destroy Build 18: cd ../terraform/control && terraform destroy -auto-approve"
echo "2. Deploy Build 19: terraform apply -auto-approve"
echo "3. Wait 5 minutes after deployment"
echo "4. Verify: nomad job status (all should be 'running')"
echo "5. Check logs: No 'Permission denied' errors expected"
echo ""

# Made with Bob
