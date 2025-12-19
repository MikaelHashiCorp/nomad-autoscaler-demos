#!/bin/bash
set -e

# Configuration
REGION="us-west-2"
AMI_ID="ami-0d98b7855341abf8a"  # Build #7
INSTANCE_TYPE="t3a.xlarge"
VPC_ID="vpc-0f17d0e52823a5128"
SUBNET_ID="subnet-0813a2057d98f32c3"
SG_NAME="windows-test-build7-$(date +%s)"

echo "Testing AMI: $AMI_ID (Build #7 - SSH + Docker)"
echo "Creating security group: $SG_NAME"
SG_ID=$(aws ec2 create-security-group \
  --group-name "$SG_NAME" \
  --description "Security group for Build #7 testing" \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --output text \
  --query 'GroupId')

echo "Security Group ID: $SG_ID"

echo "Adding ingress rules..."
# Allow RDP
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 3389 \
  --cidr 0.0.0.0/0 \
  --region "$REGION"

# Allow SSH
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0 \
  --region "$REGION"

# Allow WinRM HTTP
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 5985 \
  --cidr 0.0.0.0/0 \
  --region "$REGION"

# Allow WinRM HTTPS
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 5986 \
  --cidr 0.0.0.0/0 \
  --region "$REGION"

echo "Security group configured successfully"

echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --region "$REGION" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=test-build7-ami},{Key=Purpose,Value=ami-testing},{Key=Build,Value=7}]" \
  --output text \
  --query 'Instances[0].InstanceId')

echo "Instance ID: $INSTANCE_ID"

echo "Waiting for instance to be running..."
aws ec2 wait instance-running \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION"

echo "Getting instance details..."
INSTANCE_INFO=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --output json)

PUBLIC_IP=$(echo "$INSTANCE_INFO" | jq -r '.Reservations[0].Instances[0].PublicIpAddress')
PRIVATE_IP=$(echo "$INSTANCE_INFO" | jq -r '.Reservations[0].Instances[0].PrivateIpAddress')

echo ""
echo "=========================================="
echo "Instance launched successfully!"
echo "=========================================="
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "Private IP: $PRIVATE_IP"
echo "Security Group: $SG_ID"
echo "AMI: $AMI_ID (Build #7)"
echo ""
echo "Waiting for instance to initialize (60 seconds)..."
sleep 60
echo ""
echo "Testing components via AWS SSM..."
echo ""

# Test HashiStack
echo "1. Testing HashiStack binaries..."
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Get-ChildItem C:\HashiCorp\bin\*.exe | ForEach-Object { Write-Host \"Found: $($_.Name)\" }"]' \
  --region "$REGION" \
  --output text \
  --query 'Command.CommandId' > /tmp/cmd1.txt

CMD1=$(cat /tmp/cmd1.txt)
sleep 5
aws ssm get-command-invocation \
  --command-id "$CMD1" \
  --instance-id "$INSTANCE_ID" \
  --region "$REGION" \
  --query 'StandardOutputContent' \
  --output text

echo ""
echo "2. Testing Docker service..."
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Get-Service docker -ErrorAction SilentlyContinue | Format-List Name,Status,StartType"]' \
  --region "$REGION" \
  --output text \
  --query 'Command.CommandId' > /tmp/cmd2.txt

CMD2=$(cat /tmp/cmd2.txt)
sleep 5
aws ssm get-command-invocation \
  --command-id "$CMD2" \
  --instance-id "$INSTANCE_ID" \
  --region "$REGION" \
  --query 'StandardOutputContent' \
  --output text

echo ""
echo "3. Testing Docker command..."
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["docker version 2>&1"]' \
  --region "$REGION" \
  --output text \
  --query 'Command.CommandId' > /tmp/cmd3.txt

CMD3=$(cat /tmp/cmd3.txt)
sleep 5
aws ssm get-command-invocation \
  --command-id "$CMD3" \
  --instance-id "$INSTANCE_ID" \
  --region "$REGION" \
  --query 'StandardOutputContent' \
  --output text

echo ""
echo "4. Testing SSH service..."
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["Get-Service sshd -ErrorAction SilentlyContinue | Format-List Name,Status,StartType"]' \
  --region "$REGION" \
  --output text \
  --query 'Command.CommandId' > /tmp/cmd4.txt

CMD4=$(cat /tmp/cmd4.txt)
sleep 5
aws ssm get-command-invocation \
  --command-id "$CMD4" \
  --instance-id "$INSTANCE_ID" \
  --region "$REGION" \
  --query 'StandardOutputContent' \
  --output text

echo ""
echo "5. Testing Chocolatey..."
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunPowerShellScript" \
  --parameters 'commands=["choco --version 2>&1"]' \
  --region "$REGION" \
  --output text \
  --query 'Command.CommandId' > /tmp/cmd5.txt

CMD5=$(cat /tmp/cmd5.txt)
sleep 5
aws ssm get-command-invocation \
  --command-id "$CMD5" \
  --instance-id "$INSTANCE_ID" \
  --region "$REGION" \
  --query 'StandardOutputContent' \
  --output text

echo ""
echo "=========================================="
echo "Test Results Summary"
echo "=========================================="
echo "Instance will remain running for manual testing"
echo ""
echo "SSH Connection (if keys configured):"
echo "  ssh Administrator@$PUBLIC_IP"
echo ""
echo "RDP Connection:"
echo "  Host: $PUBLIC_IP"
echo "  Username: Administrator"
echo "  Get password: aws ec2 get-password-data --instance-id $INSTANCE_ID --region $REGION --query 'PasswordData' --output text | base64 -d"
echo ""
echo "To terminate instance:"
echo "  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"
echo "  aws ec2 delete-security-group --group-id $SG_ID --region $REGION"
echo "=========================================="

# Made with Bob