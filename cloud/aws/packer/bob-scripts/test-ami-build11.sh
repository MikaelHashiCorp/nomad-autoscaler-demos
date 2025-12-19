#!/bin/bash
# Test script for Build #11 Windows AMI with Consul and Nomad services
# This script launches an instance, waits for it to be ready, then validates via SSH

set -e

# Configuration
AMI_ID="ami-0d4f68180eaf66dac"
INSTANCE_TYPE="t3.medium"
KEY_NAME="${AWS_KEYPAIR_NAME:-nomad-autoscaler}"
SECURITY_GROUP="test-windows-build11-sg"
INSTANCE_NAME="test-windows-build11-$(date +%s)"
REGION="${AWS_REGION:-us-west-2}"

echo "========================================="
echo "Build #11 AMI Validation Test"
echo "========================================="
echo "AMI ID: $AMI_ID"
echo "Instance Type: $INSTANCE_TYPE"
echo "Key Name: $KEY_NAME"
echo "Region: $REGION"
echo ""

# Create security group if it doesn't exist
echo "[1/7] Creating/verifying security group..."
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SECURITY_GROUP" \
    --query 'SecurityGroups[0].GroupId' \
    --output text \
    --region $REGION 2>/dev/null || echo "None")

if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
    echo "  Creating new security group: $SECURITY_GROUP"
    SG_ID=$(aws ec2 create-security-group \
        --group-name $SECURITY_GROUP \
        --description "Test security group for Windows Build #11 validation" \
        --region $REGION \
        --query 'GroupId' \
        --output text)
    
    # Allow SSH (port 22)
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region $REGION
    
    # Allow RDP (port 3389) for troubleshooting
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 3389 \
        --cidr 0.0.0.0/0 \
        --region $REGION
    
    echo "  Security group created: $SG_ID"
else
    echo "  Using existing security group: $SG_ID"
fi

# Launch instance
echo ""
echo "[2/7] Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Purpose,Value=Build11-Validation}]" \
    --region $REGION \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "  Instance launched: $INSTANCE_ID"

# Wait for instance to be running
echo ""
echo "[3/7] Waiting for instance to be running..."
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
echo "[4/7] Waiting for SSH to be available (this may take 2-3 minutes)..."
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

# Run validation tests via SSH
echo ""
echo "[5/7] Running validation tests..."
echo ""

# Create validation script
cat > /tmp/validate-build11.ps1 << 'EOF'
Write-Host "========================================="
Write-Host "Build #11 Validation Tests"
Write-Host "========================================="
Write-Host ""

$allPassed = $true

# Test 1: Check Consul service
Write-Host "[Test 1/6] Checking Consul service..."
$consulService = Get-Service -Name "Consul" -ErrorAction SilentlyContinue
if ($consulService) {
    Write-Host "  Status: $($consulService.Status)"
    Write-Host "  StartType: $($consulService.StartType)"
    if ($consulService.Status -eq "Running" -and $consulService.StartType -eq "Automatic") {
        Write-Host "  [PASS] Consul service is running and set to automatic"
    } else {
        Write-Host "  [FAIL] Consul service status or startup type incorrect"
        $allPassed = $false
    }
} else {
    Write-Host "  [FAIL] Consul service not found"
    $allPassed = $false
}
Write-Host ""

# Test 2: Check Nomad service
Write-Host "[Test 2/6] Checking Nomad service..."
$nomadService = Get-Service -Name "Nomad" -ErrorAction SilentlyContinue
if ($nomadService) {
    Write-Host "  Status: $($nomadService.Status)"
    Write-Host "  StartType: $($nomadService.StartType)"
    if ($nomadService.Status -eq "Running" -and $nomadService.StartType -eq "Automatic") {
        Write-Host "  [PASS] Nomad service is running and set to automatic"
    } else {
        Write-Host "  [FAIL] Nomad service status or startup type incorrect"
        $allPassed = $false
    }
} else {
    Write-Host "  [FAIL] Nomad service not found"
    $allPassed = $false
}
Write-Host ""

# Test 3: Check Consul binary and version
Write-Host "[Test 3/6] Checking Consul binary..."
if (Test-Path "C:\HashiCorp\bin\consul.exe") {
    $consulVersion = & "C:\HashiCorp\bin\consul.exe" version 2>&1 | Select-Object -First 1
    Write-Host "  Version: $consulVersion"
    Write-Host "  [PASS] Consul binary found and executable"
} else {
    Write-Host "  [FAIL] Consul binary not found"
    $allPassed = $false
}
Write-Host ""

# Test 4: Check Nomad binary and version
Write-Host "[Test 4/6] Checking Nomad binary..."
if (Test-Path "C:\HashiCorp\bin\nomad.exe") {
    $nomadVersion = & "C:\HashiCorp\bin\nomad.exe" version 2>&1 | Select-Object -First 1
    Write-Host "  Version: $nomadVersion"
    Write-Host "  [PASS] Nomad binary found and executable"
} else {
    Write-Host "  [FAIL] Nomad binary not found"
    $allPassed = $false
}
Write-Host ""

# Test 5: Check Docker service
Write-Host "[Test 5/6] Checking Docker service..."
$dockerService = Get-Service -Name "docker" -ErrorAction SilentlyContinue
if ($dockerService) {
    Write-Host "  Status: $($dockerService.Status)"
    Write-Host "  StartType: $($dockerService.StartType)"
    if ($dockerService.StartType -eq "Automatic") {
        Write-Host "  [PASS] Docker service configured for automatic startup"
    } else {
        Write-Host "  [WARN] Docker service not set to automatic"
    }
} else {
    Write-Host "  [FAIL] Docker service not found"
    $allPassed = $false
}
Write-Host ""

# Test 6: Check SSH service
Write-Host "[Test 6/6] Checking SSH service..."
$sshService = Get-Service -Name "sshd" -ErrorAction SilentlyContinue
if ($sshService) {
    Write-Host "  Status: $($sshService.Status)"
    Write-Host "  StartType: $($sshService.StartType)"
    if ($sshService.Status -eq "Running" -and $sshService.StartType -eq "Automatic") {
        Write-Host "  [PASS] SSH service is running and set to automatic"
    } else {
        Write-Host "  [WARN] SSH service status or startup type not optimal"
    }
} else {
    Write-Host "  [FAIL] SSH service not found"
    $allPassed = $false
}
Write-Host ""

# Summary
Write-Host "========================================="
if ($allPassed) {
    Write-Host "VALIDATION RESULT: ALL TESTS PASSED"
    Write-Host "========================================="
    exit 0
} else {
    Write-Host "VALIDATION RESULT: SOME TESTS FAILED"
    Write-Host "========================================="
    exit 1
}
EOF

# Copy validation script to instance and run it
scp -o StrictHostKeyChecking=no -i ~/.ssh/${KEY_NAME}.pem /tmp/validate-build11.ps1 Administrator@$PUBLIC_IP:C:/validate-build11.ps1

ssh -o StrictHostKeyChecking=no -i ~/.ssh/${KEY_NAME}.pem Administrator@$PUBLIC_IP "powershell -ExecutionPolicy Bypass -File C:/validate-build11.ps1"
VALIDATION_RESULT=$?

echo ""
echo "[6/7] Validation complete"
echo ""

# Cleanup
echo "[7/7] Cleanup options:"
echo "  Instance ID: $INSTANCE_ID"
echo "  Security Group: $SG_ID"
echo "  Public IP: $PUBLIC_IP"
echo ""
echo "To terminate the instance:"
echo "  aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"
echo ""
echo "To delete the security group (after instance is terminated):"
echo "  aws ec2 delete-security-group --group-id $SG_ID --region $REGION"
echo ""

if [ $VALIDATION_RESULT -eq 0 ]; then
    echo "========================================="
    echo "BUILD #11 VALIDATION: SUCCESS"
    echo "========================================="
    exit 0
else
    echo "========================================="
    echo "BUILD #11 VALIDATION: FAILED"
    echo "========================================="
    exit 1
fi

# Made with Bob
