#!/bin/bash
set -e

# AWS credentials should be set in your environment before running this script
# Example:
#   export AWS_ACCESS_KEY_ID=your_access_key
#   export AWS_SECRET_ACCESS_KEY=your_secret_key
#   export AWS_SESSION_TOKEN=your_session_token  # if using temporary credentials

# Configuration
REGION="us-west-2"
AMI_ID="ami-0ffb5e08f1d975964"
INSTANCE_TYPE="t3a.xlarge"
VPC_ID="vpc-0f17d0e52823a5128"
SUBNET_ID="subnet-0813a2057d98f32c3"
SG_NAME="windows-docker-test-$(date +%s)"

echo "Creating security group: $SG_NAME"
SG_ID=$(aws ec2 create-security-group \
  --group-name "$SG_NAME" \
  --description "Security group for Windows Docker testing" \
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

# Allow all outbound (default, but being explicit)
echo "Security group configured successfully"

echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --region "$REGION" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=windows-docker-test},{Key=Purpose,Value=docker-testing}]" \
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
echo ""
echo "Getting Windows password (this may take a few minutes)..."
echo "Run this command after ~4 minutes:"
echo "aws ec2 get-password-data --instance-id $INSTANCE_ID --region $REGION --query 'PasswordData' --output text | base64 -d"
echo ""
echo "RDP Connection:"
echo "  Host: $PUBLIC_IP"
echo "  Username: Administrator"
echo ""
echo "To terminate instance later:"
echo "  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"
echo "  aws ec2 delete-security-group --group-id $SG_ID --region $REGION"
echo "=========================================="

# Made with Bob