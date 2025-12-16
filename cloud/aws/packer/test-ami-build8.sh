#!/bin/bash
# Test script for Build #8 AMI (ami-0a7ba5fe6ab153cd6)
# Tests automatic SSH key injection from EC2 metadata

set -e

AMI_ID="ami-0a7ba5fe6ab153cd6"
REGION="us-west-2"
INSTANCE_TYPE="t3a.xlarge"
KEY_NAME="aws-mikael-test"
SECURITY_GROUP_NAME="test-build8-sg-$(date +%s)"

echo "=========================================="
echo "Testing Build #8 AMI: $AMI_ID"
echo "Feature: Automatic SSH Key Injection"
echo "=========================================="
echo ""

# Create security group
echo "[1/6] Creating security group..."
SG_ID=$(aws ec2 create-security-group \
    --group-name "$SECURITY_GROUP_NAME" \
    --description "Test security group for Build #8 AMI" \
    --region "$REGION" \
    --output text --query 'GroupId')
echo "  Security Group ID: $SG_ID"

# Add rules for RDP, SSH, WinRM
echo "[2/6] Adding security group rules..."
aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --ip-permissions \
        IpProtocol=tcp,FromPort=3389,ToPort=3389,IpRanges='[{CidrIp=0.0.0.0/0,Description="RDP"}]' \
        IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=0.0.0.0/0,Description="SSH"}]' \
        IpProtocol=tcp,FromPort=5985,ToPort=5985,IpRanges='[{CidrIp=0.0.0.0/0,Description="WinRM HTTP"}]' \
        IpProtocol=tcp,FromPort=5986,ToPort=5986,IpRanges='[{CidrIp=0.0.0.0/0,Description="WinRM HTTPS"}]' \
    --region "$REGION"
echo "  Rules added: RDP (3389), SSH (22), WinRM (5985, 5986)"

# Launch instance with key pair
echo "[3/6] Launching instance from AMI..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --region "$REGION" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=test-build8-$(date +%Y%m%d-%H%M%S)}]" \
    --output text --query 'Instances[0].InstanceId')
echo "  Instance ID: $INSTANCE_ID"

# Wait for instance to be running
echo "[4/6] Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"
echo "  Instance is running"

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --output text --query 'Reservations[0].Instances[0].PublicIpAddress')
echo "  Public IP: $PUBLIC_IP"

# Wait for instance to fully boot and run scheduled task
echo "[5/6] Waiting for instance to fully boot (90 seconds)..."
echo "  This allows time for:"
echo "    - Windows to complete startup"
echo "    - Scheduled task 'InjectEC2SSHKey' to run"
echo "    - SSH key to be injected from EC2 metadata"
sleep 90

# Test SSH connectivity with automatic key injection
echo "[6/6] Testing SSH connectivity with automatic key injection..."
echo "  Attempting SSH connection to Administrator@$PUBLIC_IP"
echo "  Using key: ~/.ssh/${KEY_NAME}.pem"
echo ""

# Try SSH connection
if ssh -i ~/.ssh/${KEY_NAME}.pem \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=30 \
    Administrator@$PUBLIC_IP \
    'echo "SSH connection successful!"; hostname; whoami; echo ""; echo "Checking scheduled task:"; schtasks /query /tn InjectEC2SSHKey /fo LIST; echo ""; echo "Checking authorized_keys:"; if (Test-Path C:\ProgramData\ssh\administrators_authorized_keys) { Write-Host "authorized_keys file exists"; Get-Content C:\ProgramData\ssh\administrators_authorized_keys | Select-Object -First 1 } else { Write-Host "authorized_keys file NOT found" }'; then
    echo ""
    echo "=========================================="
    echo "✅ SUCCESS: Automatic SSH key injection works!"
    echo "=========================================="
    echo ""
    echo "The scheduled task successfully:"
    echo "  1. Fetched the public key from EC2 metadata"
    echo "  2. Wrote it to administrators_authorized_keys"
    echo "  3. Set proper permissions"
    echo "  4. Enabled SSH access without manual configuration"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "❌ FAILED: SSH connection failed"
    echo "=========================================="
    echo ""
    echo "Possible issues:"
    echo "  1. Scheduled task didn't run"
    echo "  2. EC2 metadata not accessible"
    echo "  3. Key injection script failed"
    echo "  4. SSH service not running"
    echo ""
    echo "Checking via SSM..."
    aws ssm send-command \
        --instance-ids "$INSTANCE_ID" \
        --document-name "AWS-RunPowerShellScript" \
        --parameters 'commands=["Get-ScheduledTask -TaskName InjectEC2SSHKey | Format-List","","Get-Content C:\ProgramData\ssh\administrators_authorized_keys -ErrorAction SilentlyContinue","","Get-Service sshd | Format-List"]' \
        --region "$REGION" \
        --output text
fi

echo ""
echo "=========================================="
echo "Instance Details"
echo "=========================================="
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "Security Group: $SG_ID"
echo "Key Pair: $KEY_NAME"
echo ""
echo "To connect manually:"
echo "  ssh -i ~/.ssh/${KEY_NAME}.pem Administrator@$PUBLIC_IP"
echo ""
echo "To check scheduled task via SSM:"
echo "  aws ssm send-command \\"
echo "    --instance-ids $INSTANCE_ID \\"
echo "    --document-name AWS-RunPowerShellScript \\"
echo "    --parameters 'commands=[\"Get-ScheduledTask -TaskName InjectEC2SSHKey | Format-List\"]' \\"
echo "    --region $REGION"
echo ""
echo "To terminate instance:"
echo "  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"
echo ""
echo "To delete security group (after instance terminated):"
echo "  aws ec2 delete-security-group --group-id $SG_ID --region $REGION"
echo ""
echo "Instance left running for manual testing."
echo "=========================================="

# Made with Bob
