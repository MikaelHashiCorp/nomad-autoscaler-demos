#!/bin/bash
# Build #13 - Fixed HCL path escaping bug
# Changes: Fixed Consul and Nomad data_dir path escaping in setup-windows.ps1

set -e

echo "========================================="
echo "Build #13 - Windows AMI with Fixed Config"
echo "========================================="
echo "Date: $(date)"
echo "Fix: HCL path escaping in setup-windows.ps1"
echo ""

# Change to packer directory
cd "$(dirname "$0")"

# Run Packer build with timestamps
echo "Starting Packer build..."
./run-with-timestamps.sh \
  -only='windows.amazon-ebs.hashistack' \
  -var-file=windows-2022.pkrvars.hcl \
  .

echo ""
echo "========================================="
echo "Build #13 Complete"
echo "========================================="
echo "Check logs for AMI ID"

# Made with Bob
