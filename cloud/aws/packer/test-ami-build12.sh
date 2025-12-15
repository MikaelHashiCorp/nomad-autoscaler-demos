#!/bin/bash
# Test script for Build #12 Windows AMI with auto-starting Consul and Nomad services
# This build fixes the service configurations to use standalone mode

set -e

# Source environment
source ~/.zshrc

# Configuration
BUILD_NUMBER="12"
BUILD_NAME="build${BUILD_NUMBER}"
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S.%3NZ")
LOG_DIR="cloud/aws/packer/logs"
LOG_FILE="${LOG_DIR}/$(hostname)_packer_${TIMESTAMP}.out"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

echo "========================================="
echo "Build #${BUILD_NUMBER} - Windows AMI with Auto-Starting Services"
echo "========================================="
echo "Timestamp: $TIMESTAMP"
echo "Log file: $LOG_FILE"
echo ""
echo "Changes in this build:"
echo "  - Fixed Consul configuration for standalone server mode"
echo "  - Fixed Nomad configuration for standalone server+client mode"
echo "  - Services should now start automatically and remain running"
echo ""

# Change to packer directory
cd cloud/aws/packer

# Run Packer build with timestamps and logging
echo "Starting Packer build..."
echo ""

# Use explicit file specification to avoid auto-loading conflicts
logcmd "packer build -only='windows.amazon-ebs.hashistack' -var-file=windows-2022.pkrvars.hcl aws-packer.pkr.hcl" "$LOG_FILE"

BUILD_RESULT=$?

echo ""
echo "========================================="
if [ $BUILD_RESULT -eq 0 ]; then
    echo "Build #${BUILD_NUMBER} completed successfully!"
    echo "========================================="
    echo ""
    echo "Next steps:"
    echo "1. Extract AMI ID from log file: $LOG_FILE"
    echo "2. Launch test instance from new AMI"
    echo "3. Validate services are running with validate-running-instance.sh"
    echo ""
    echo "To extract AMI ID:"
    echo "  grep 'ami-' $LOG_FILE | tail -1"
    exit 0
else
    echo "Build #${BUILD_NUMBER} FAILED!"
    echo "========================================="
    echo ""
    echo "Check log file for details: $LOG_FILE"
    exit 1
fi

# Made with Bob
