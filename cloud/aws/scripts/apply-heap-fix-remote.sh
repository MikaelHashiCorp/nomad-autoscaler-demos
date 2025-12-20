#!/bin/bash
# Script to apply Windows Desktop Heap fix remotely via SSH
# Usage: ./apply-heap-fix-remote.sh [windows-ip] [ssh-key-path]

set -euo pipefail

# Configuration
WINDOWS_IP="${1:-34.222.139.178}"
SSH_KEY="${2:-$HOME/.ssh/mhc-aws-mws-west-2.pem}"
SSH_USER="Administrator"
SCRIPT_NAME="apply-heap-fix.ps1"
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$SCRIPT_NAME"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Applying Windows Desktop Heap Fix ===${NC}"
echo ""
echo -e "${YELLOW}Target: ${WINDOWS_IP}${NC}"
echo -e "${YELLOW}SSH Key: ${SSH_KEY}${NC}"
echo -e "${YELLOW}SSH User: ${SSH_USER}${NC}"
echo ""

# Verify SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}ERROR: SSH key not found at $SSH_KEY${NC}"
    exit 1
fi

# Verify script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo -e "${RED}ERROR: PowerShell script not found at $SCRIPT_PATH${NC}"
    exit 1
fi

echo -e "${CYAN}Copying fix script to Windows instance...${NC}"
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "$SCRIPT_PATH" "${SSH_USER}@${WINDOWS_IP}:C:\\Users\\Administrator\\apply-fix.ps1"

echo ""
echo -e "${CYAN}Executing fix script on Windows instance...${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    "${SSH_USER}@${WINDOWS_IP}" \
    "powershell.exe -ExecutionPolicy Bypass -File C:\\Users\\Administrator\\apply-fix.ps1"

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${GREEN}Fix script executed!${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: The Windows instance must be rebooted for changes to take effect!${NC}"
echo ""
echo -e "${CYAN}To reboot the instance:${NC}"
echo -e "  ssh -i $SSH_KEY ${SSH_USER}@${WINDOWS_IP} \"shutdown /r /t 60 /c 'Applying desktop heap fix'\""
echo ""
echo -e "${CYAN}Or reboot immediately:${NC}"
echo -e "  ssh -i $SSH_KEY ${SSH_USER}@${WINDOWS_IP} \"shutdown /r /t 0 /f\""
echo ""
