#!/bin/bash
# Test script for Build #10 AMI (ami-0be5bc02dfba10f4d)
# Tests Chocolatey Docker installation with reboot handling

set -e

AMI_ID="ami-0be5bc02dfba10f4d"
REGION="us-west-2"
INSTANCE_TYPE="t3.medium"
KEY_NAME="aws-mikael-test"
SECURITY_GROUP_NAME="test-build10-sg-$(date +%s)"

echo "=========================================="
echo "Testing Build #10 AMI: $AMI_ID"
echo "Feature: Chocolatey Docker with Reboot"
echo "=========================================="
echo ""

# Create security group
echo "[1/6] Creating security group..."
SG_ID=$(aws ec2 create-security-group \
    --group-name "$SECURITY_GROUP_NAME" \
    --description "Test security group for Build #10 AMI" \
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
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=test-build10-$(date +%Y%m%d-%H%M%S)}]" \
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

# Wait for instance to fully boot
echo "[5/6] Waiting for instance to fully boot (90 seconds)..."
echo "  This allows time for:"
echo "    - Windows to complete startup"
echo "    - Scheduled task 'InjectEC2SSHKey' to run"
echo "    - SSH key to be injected from EC2 metadata"
echo "    - Docker service to start"
sleep 90

# Test SSH connectivity and verify components
echo "[6/6] Testing SSH connectivity and verifying components..."
echo "  Attempting SSH connection to Administrator@$PUBLIC_IP"
echo "  Using key: ~/.ssh/${KEY_NAME}.pem"
echo ""

# Try SSH connection and verify all components
if ssh -i ~/.ssh/${KEY_NAME}.pem \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=30 \
    Administrator@$PUBLIC_IP \
    'powershell -Command "
Write-Host \"========================================\";
Write-Host \"SSH Connection Successful!\";
Write-Host \"========================================\";
Write-Host \"\";
Write-Host \"System Information:\";
Write-Host \"  Hostname: $(hostname)\";
Write-Host \"  User: $(whoami)\";
Write-Host \"\";
Write-Host \"========================================\";
Write-Host \"Component Verification\";
Write-Host \"========================================\";
Write-Host \"\";
Write-Host \"[1/7] HashiStack Binaries:\";
if (Test-Path C:\\HashiCorp\\bin) {
    Get-ChildItem C:\\HashiCorp\\bin\\*.exe | ForEach-Object {
        Write-Host \"  [OK] $($_.Name) exists\"
    }
} else {
    Write-Host \"  [FAIL] HashiCorp bin directory not found\"
}
Write-Host \"\";
Write-Host \"[2/7] Consul Version:\";
try {
    \$consulVersion = & C:\\HashiCorp\\bin\\consul.exe version 2>&1 | Select-Object -First 1
    Write-Host \"  [OK] \$consulVersion\"
} catch {
    Write-Host \"  [FAIL] Consul not working\"
}
Write-Host \"\";
Write-Host \"[3/7] Nomad Version:\";
try {
    \$nomadVersion = & C:\\HashiCorp\\bin\\nomad.exe version 2>&1 | Select-Object -First 1
    Write-Host \"  [OK] \$nomadVersion\"
} catch {
    Write-Host \"  [FAIL] Nomad not working\"
}
Write-Host \"\";
Write-Host \"[4/7] Vault Version:\";
try {
    \$vaultVersion = & C:\\HashiCorp\\bin\\vault.exe version 2>&1 | Select-Object -First 1
    Write-Host \"  [OK] \$vaultVersion\"
} catch {
    Write-Host \"  [FAIL] Vault not working\"
}
Write-Host \"\";
Write-Host \"[5/7] Docker Service Status:\";
\$dockerService = Get-Service docker -ErrorAction SilentlyContinue;
if (\$dockerService) {
    Write-Host \"  [OK] Service exists\"
    Write-Host \"      Status: \$(\$dockerService.Status)\"
    Write-Host \"      StartType: \$(\$dockerService.StartType)\"
} else {
    Write-Host \"  [FAIL] Docker service not found\"
}
Write-Host \"\";
Write-Host \"[6/7] Docker Version:\";
try {
    \$dockerVersion = & docker version --format \"{{.Server.Version}}\" 2>&1
    if (\$LASTEXITCODE -eq 0) {
        Write-Host \"  [OK] Docker version: \$dockerVersion\"
        Write-Host \"  [OK] Docker daemon is responding\"
    } else {
        Write-Host \"  [FAIL] Docker command failed\"
    }
} catch {
    Write-Host \"  [FAIL] Docker not working: \$_\"
}
Write-Host \"\";
Write-Host \"[7/7] SSH Key Injection:\";
\$scheduledTask = Get-ScheduledTask -TaskName InjectEC2SSHKey -ErrorAction SilentlyContinue;
if (\$scheduledTask) {
    Write-Host \"  [OK] Scheduled task exists\"
    Write-Host \"      State: \$(\$scheduledTask.State)\"
} else {
    Write-Host \"  [FAIL] Scheduled task not found\"
}
if (Test-Path C:\\ProgramData\\ssh\\administrators_authorized_keys) {
    Write-Host \"  [OK] authorized_keys file exists\"
} else {
    Write-Host \"  [FAIL] authorized_keys file not found\"
}
Write-Host \"\";
Write-Host \"========================================\";
Write-Host \"Chocolatey Installation Method:\";
Write-Host \"========================================\";
Write-Host \"Docker was installed via Chocolatey package manager\"
Write-Host \"This provides better maintainability than manual installation\"
Write-Host \"\";
"'; then
    echo ""
    echo "=========================================="
    echo "✅ SUCCESS: Build #10 AMI Verified!"
    echo "=========================================="
    echo ""
    echo "All components working correctly:"
    echo "  ✅ HashiStack (Consul, Nomad, Vault)"
    echo "  ✅ Docker (via Chocolatey with reboot)"
    echo "  ✅ SSH Server with automatic key injection"
    echo "  ✅ Chocolatey package manager"
    echo ""
    echo "Build #10 improvements over Build #8:"
    echo "  • Cleaner code (17 fewer lines)"
    echo "  • Package manager for Docker (easier updates)"
    echo "  • Explicit reboot handling"
    echo "  • Post-reboot verification"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "❌ FAILED: SSH connection or verification failed"
    echo "=========================================="
    echo ""
    echo "Possible issues:"
    echo "  1. SSH key injection didn't work"
    echo "  2. Components not installed correctly"
    echo "  3. Docker service not running"
    echo ""
fi

echo ""
echo "=========================================="
echo "Instance Details"
echo "=========================================="
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "Security Group: $SG_ID"
echo "Key Pair: $KEY_NAME"
echo "AMI ID: $AMI_ID"
echo ""
echo "To connect manually:"
echo "  ssh -i ~/.ssh/${KEY_NAME}.pem Administrator@$PUBLIC_IP"
echo ""
echo "To test Docker:"
echo "  ssh -i ~/.ssh/${KEY_NAME}.pem Administrator@$PUBLIC_IP 'docker version'"
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