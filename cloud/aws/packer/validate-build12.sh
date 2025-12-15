#!/bin/bash
# Validation script for Build #12
# This script launches an instance and validates all services are running

set -e

# Configuration
AMI_ID="ami-0196ee4a6c6596efe"
INSTANCE_TYPE="t3a.xlarge"
KEY_NAME="${AWS_KEYPAIR_NAME:-aws-mikael-test}"
SECURITY_GROUP="sg-0dc160eb2b95bba7d"
INSTANCE_NAME="test-build12-validation-$(date +%s)"
REGION="${AWS_REGION:-us-west-2}"

echo "========================================="
echo "Build #12 AMI Validation"
echo "========================================="
echo "AMI ID: $AMI_ID"
echo "Instance Type: $INSTANCE_TYPE"
echo "Key Name: $KEY_NAME"
echo "Security Group: $SECURITY_GROUP"
echo "Region: $REGION"
echo ""

# Launch instance
echo "[1/5] Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Purpose,Value=Build12-Validation}]" \
    --region $REGION \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "  Instance launched: $INSTANCE_ID"

# Wait for instance to be running
echo ""
echo "[2/5] Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION
echo "  Instance is running"

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "  Public IP: $PUBLIC_IP"

# Wait for SSH to be available
echo ""
echo "[3/5] Waiting for SSH to be available (this may take 2-3 minutes)..."
MAX_ATTEMPTS=60
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i ~/.ssh/${KEY_NAME}.pem Administrator@$PUBLIC_IP "exit" 2>/dev/null; then
        echo "  SSH is available!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "  Attempt $ATTEMPT/$MAX_ATTEMPTS - waiting..."
    sleep 5
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "  ERROR: SSH did not become available within the timeout period"
    echo "  Instance ID: $INSTANCE_ID"
    echo "  Public IP: $PUBLIC_IP"
    exit 1
fi

# Run validation
echo ""
echo "[4/5] Running service validation..."
echo ""

./validate-running-instance.sh $PUBLIC_IP $KEY_NAME
VALIDATION_RESULT=$?

echo ""
echo "[5/5] Validation complete"
echo ""

# Provide cleanup instructions
echo "========================================="
echo "Cleanup Instructions"
echo "========================================="
echo "Instance ID: $INSTANCE_ID"
echo "Security Group: $SECURITY_GROUP"
echo "Public IP: $PUBLIC_IP"
echo ""
echo "To terminate the instance:"
echo "  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"
echo ""
echo "To delete the security group (after instance is terminated):"
echo "  aws ec2 delete-security-group --group-id $SECURITY_GROUP --region $REGION"
echo ""

if [ $VALIDATION_RESULT -eq 0 ]; then
    echo "========================================="
    echo "BUILD #12 VALIDATION: SUCCESS ✓"
    echo "========================================="
    exit 0
else
    echo "========================================="
    echo "BUILD #12 VALIDATION: FAILED ✗"
    echo "========================================="
    exit 1
fi

# Made with Bob
