#!/bin/bash
set -e

# Source credentials
source ~/.zshrc 2>/dev/null

# Configuration
INSTANCE_ID="i-0363b8ece02ab1221"
REGION="us-west-2"
PUBLIC_IP="54.203.125.163"
MAX_RETRIES=20
RETRY_INTERVAL=30

echo "=========================================="
echo "Waiting for Windows password to be available"
echo "=========================================="
echo "Instance ID: $INSTANCE_ID"
echo "This may take 4-5 minutes..."
echo ""

# Wait for password to be available
for i in $(seq 1 $MAX_RETRIES); do
    echo "Attempt $i/$MAX_RETRIES: Checking for password..."
    
    PASSWORD_DATA=$(logcmd aws ec2 get-password-data \
        --instance-id "$INSTANCE_ID" \
        --region "$REGION" \
        --query 'PasswordData' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$PASSWORD_DATA" ] && [ "$PASSWORD_DATA" != "None" ]; then
        echo "Password data is available!"
        break
    fi
    
    if [ $i -lt $MAX_RETRIES ]; then
        echo "Password not yet available. Waiting $RETRY_INTERVAL seconds..."
        sleep $RETRY_INTERVAL
    else
        echo "ERROR: Password did not become available after $MAX_RETRIES attempts"
        exit 1
    fi
done

echo ""
echo "=========================================="
echo "Password Retrieved Successfully"
echo "=========================================="
echo ""
echo "Note: The actual password decryption requires the private key."
echo "Since we're using AWS-generated keys, we cannot decrypt it here."
echo ""
echo "Instead, we'll use AWS Systems Manager (SSM) to run commands."
echo "Checking if SSM agent is available..."
echo ""

# Check if instance is managed by SSM
echo "Checking SSM agent status..."
SSM_STATUS=$(logcmd aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --region "$REGION" \
    --query 'InstanceInformationList[0].PingStatus' \
    --output text 2>/dev/null || echo "NotAvailable")

if [ "$SSM_STATUS" = "Online" ]; then
    echo "SSM agent is online! We can use SSM to run commands."
    echo ""
    echo "Installing Docker via SSM..."
    
    # Upload the Docker installation script
    SCRIPT_CONTENT=$(cat install-docker-windows.ps1)
    
    # Run the script via SSM
    COMMAND_ID=$(logcmd aws ssm send-command \
        --instance-ids "$INSTANCE_ID" \
        --region "$REGION" \
        --document-name "AWS-RunPowerShellScript" \
        --parameters "commands=[\"$SCRIPT_CONTENT\"]" \
        --query 'Command.CommandId' \
        --output text)
    
    echo "Command ID: $COMMAND_ID"
    echo "Waiting for command to complete..."
    
    # Wait for command to complete
    sleep 10
    
    for i in $(seq 1 30); do
        STATUS=$(logcmd aws ssm get-command-invocation \
            --command-id "$COMMAND_ID" \
            --instance-id "$INSTANCE_ID" \
            --region "$REGION" \
            --query 'Status' \
            --output text 2>/dev/null || echo "Pending")
        
        echo "Status: $STATUS"
        
        if [ "$STATUS" = "Success" ] || [ "$STATUS" = "Failed" ]; then
            break
        fi
        
        sleep 10
    done
    
    # Get command output
    echo ""
    echo "=========================================="
    echo "Command Output"
    echo "=========================================="
    logcmd aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --region "$REGION" \
        --query 'StandardOutputContent' \
        --output text
    
    echo ""
    echo "=========================================="
    echo "Command Errors (if any)"
    echo "=========================================="
    logcmd aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --region "$REGION" \
        --query 'StandardErrorContent' \
        --output text
    
else
    echo "SSM agent is not available yet."
    echo "Alternative: Use WinRM or RDP to connect manually."
    echo ""
    echo "RDP Connection Details:"
    echo "  Host: $PUBLIC_IP"
    echo "  Username: Administrator"
    echo "  Password: (retrieve using AWS Console or CLI with private key)"
    echo ""
    echo "To get password with private key:"
    echo "  aws ec2 get-password-data --instance-id $INSTANCE_ID --region $REGION --priv-launch-key-file /path/to/key.pem"
fi

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo "1. If SSM worked, verify Docker: aws ssm send-command --instance-ids $INSTANCE_ID --document-name AWS-RunPowerShellScript --parameters 'commands=[\"docker version\"]'"
echo "2. If SSM didn't work, connect via RDP and run install-docker-windows.ps1 manually"
echo "3. To terminate instance: aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"
echo ""

# Made with Bob
