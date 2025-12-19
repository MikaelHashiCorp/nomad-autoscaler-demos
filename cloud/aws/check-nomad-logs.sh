#!/bin/bash
# Check Nomad logs on Windows instance via SSM

INSTANCE_ID="i-0f2e74fcb95361c77"

echo "Connecting to Windows instance $INSTANCE_ID via SSM..."
echo "Checking Nomad logs..."
echo ""

aws ssm send-command \
    --region us-west-2 \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunPowerShellScript" \
    --parameters 'commands=["Get-Content C:\HashiCorp\Nomad\logs\nomad-*.log -Tail 100"]' \
    --output text \
    --query 'Command.CommandId'

# Made with Bob
