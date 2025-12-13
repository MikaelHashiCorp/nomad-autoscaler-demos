#!/bin/bash
# Helper script to check the status of a running Packer build instance
# Usage: ./check-instance-status.sh [instance-id]

set -e

INSTANCE_ID="$1"

if [ -z "$INSTANCE_ID" ]; then
    echo "Usage: $0 <instance-id>"
    echo ""
    echo "To find the instance ID, look for 'amazon-ebs.hashistack: Found Instance ID:' in packer output"
    exit 1
fi

echo "=========================================="
echo "Checking Instance Status"
echo "=========================================="
echo "Instance ID: $INSTANCE_ID"
echo ""

# Check instance state
echo "Instance State:"
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].State.Name' --output text
echo ""

# Check instance public IP
echo "Public IP:"
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "$PUBLIC_IP"
echo ""

# Check if Windows (look for Platform field)
PLATFORM=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].Platform' --output text 2>/dev/null || echo "linux")

if [ "$PLATFORM" = "windows" ]; then
    echo "Platform: Windows"
    echo ""
    echo "To connect via RDP:"
    echo "  1. Get password: aws ec2 get-password-data --instance-id $INSTANCE_ID --priv-launch-key <path-to-private-key>"
    echo "  2. Connect to: $PUBLIC_IP:3389"
    echo ""
    echo "To check WinRM connectivity:"
    echo "  Test-NetConnection -ComputerName $PUBLIC_IP -Port 5985"
    echo ""
    echo "To run PowerShell commands remotely (from Windows host):"
    echo "  \$cred = Get-Credential"
    echo "  Invoke-Command -ComputerName $PUBLIC_IP -Credential \$cred -ScriptBlock { Get-Process | Where-Object { \$_.ProcessName -like '*docker*' -or \$_.ProcessName -like '*powershell*' } }"
    echo ""
    echo "To check what's running:"
    echo "  Invoke-Command -ComputerName $PUBLIC_IP -Credential \$cred -ScriptBlock { Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 ProcessName, CPU, WorkingSet }"
else
    echo "Platform: Linux"
    echo ""
    echo "To SSH into the instance:"
    echo "  ssh -i <path-to-private-key> ec2-user@$PUBLIC_IP"
    echo ""
    echo "To check what's running:"
    echo "  ssh -i <path-to-private-key> ec2-user@$PUBLIC_IP 'top -bn1 | head -20'"
fi

echo ""
echo "To view console output:"
echo "  aws ec2 get-console-output --instance-id $INSTANCE_ID --output text"
echo ""
echo "To terminate the instance (if needed):"
echo "  aws ec2 terminate-instances --instance-ids $INSTANCE_ID"
echo ""

# Made with Bob
