#!/bin/bash

# Script to install Docker on Windows instance via WinRM
# This uses the winrm-cli tool or curl to send commands

source ~/.zshrc 2>/dev/null

INSTANCE_ID="i-0363b8ece02ab1221"
REGION="us-west-2"
PUBLIC_IP="54.203.125.163"
WINRM_PORT="5985"

echo "=========================================="
echo "Docker Installation via WinRM"
echo "=========================================="
echo ""
echo "Instance: $INSTANCE_ID"
echo "IP: $PUBLIC_IP"
echo "WinRM Port: $WINRM_PORT"
echo ""

# Check if password is available
echo "Checking for Windows password..."
PASSWORD_DATA=$(logcmd aws ec2 get-password-data \
    --instance-id "$INSTANCE_ID" \
    --region "$REGION" \
    --query 'PasswordData' \
    --output text 2>/dev/null || echo "")

if [ -z "$PASSWORD_DATA" ] || [ "$PASSWORD_DATA" = "None" ]; then
    echo "Password is not yet available. Please wait 4-5 minutes after instance launch."
    echo ""
    echo "To check password status, run:"
    echo "  source ~/.zshrc && logcmd aws ec2 get-password-data --instance-id $INSTANCE_ID --region $REGION"
    echo ""
    echo "Once password is available, you can:"
    echo "1. Connect via RDP to $PUBLIC_IP"
    echo "2. Run the PowerShell script: install-docker-windows.ps1"
    echo ""
    exit 1
fi

echo "Password data is available!"
echo ""
echo "=========================================="
echo "WinRM Connection Method"
echo "=========================================="
echo ""
echo "Since we don't have the private key to decrypt the password,"
echo "and WinRM requires authentication, here are your options:"
echo ""
echo "Option 1: Use AWS Systems Manager Session Manager (if SSM agent is installed)"
echo "  - This doesn't require a password"
echo "  - Run: aws ssm start-session --target $INSTANCE_ID --region $REGION"
echo ""
echo "Option 2: Connect via RDP and run the script manually"
echo "  - Get password using AWS Console (it can decrypt with the key pair)"
echo "  - Connect to: $PUBLIC_IP"
echo "  - Username: Administrator"
echo "  - Run PowerShell as Administrator"
echo "  - Execute: C:\ops\scripts\setup-windows.ps1 (if copied) or paste install-docker-windows.ps1"
echo ""
echo "Option 3: Use curl to send WinRM commands (requires password)"
echo "  - This is complex and requires proper authentication setup"
echo ""
echo "=========================================="
echo "Recommended: Manual RDP Connection"
echo "=========================================="
echo ""
echo "Steps:"
echo "1. Go to AWS Console -> EC2 -> Instances"
echo "2. Select instance $INSTANCE_ID"
echo "3. Click 'Connect' -> 'RDP client' -> 'Get Password'"
echo "4. Upload your key pair file to decrypt the password"
echo "5. Download the RDP file and connect"
echo "6. Once connected, open PowerShell as Administrator"
echo "7. Run the following command:"
echo ""
echo "   Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/your-repo/install-docker-windows.ps1' -OutFile C:\install-docker.ps1"
echo "   Or copy the contents of install-docker-windows.ps1 and paste into PowerShell"
echo ""
echo "8. Execute: C:\install-docker.ps1"
echo ""
echo "=========================================="
echo "Instance Information"
echo "=========================================="
echo "Instance ID: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "Region: $REGION"
echo "RDP Port: 3389"
echo "WinRM HTTP Port: 5985"
echo "WinRM HTTPS Port: 5986"
echo ""
echo "To terminate instance when done:"
echo "  source ~/.zshrc && logcmd aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION"
echo ""

# Made with Bob
