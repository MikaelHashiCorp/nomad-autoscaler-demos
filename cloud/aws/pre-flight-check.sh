#!/bin/bash
# Pre-flight Check for Multi-OS Testing
# Run this before executing quick-test.sh

set -euo pipefail

echo "=== Pre-flight Checks for Multi-OS Testing ==="
echo ""

# Check 1: AWS Credentials
echo "1. Checking AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
  echo "   ✅ AWS credentials are valid"
  aws sts get-caller-identity --output table
else
  echo "   ❌ AWS credentials are NOT configured or expired"
  echo ""
  echo "   To configure AWS credentials, run:"
  echo "   eval \$(doormat aws export --account aws_mikael.sikora_test)"
  echo ""
  exit 1
fi

# Check 2: Required tools
echo ""
echo "2. Checking required tools..."

MISSING_TOOLS=()

if ! command -v packer &> /dev/null; then
  MISSING_TOOLS+=("packer")
  echo "   ❌ packer not found"
else
  echo "   ✅ packer installed: $(packer version)"
fi

if ! command -v terraform &> /dev/null; then
  MISSING_TOOLS+=("terraform")
  echo "   ❌ terraform not found"
else
  echo "   ✅ terraform installed: $(terraform version | head -1)"
fi

if ! command -v jq &> /dev/null; then
  MISSING_TOOLS+=("jq")
  echo "   ❌ jq not found"
else
  echo "   ✅ jq installed"
fi

if ! command -v curl &> /dev/null; then
  MISSING_TOOLS+=("curl")
  echo "   ❌ curl not found"
else
  echo "   ✅ curl installed"
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
  echo ""
  echo "   Missing tools: ${MISSING_TOOLS[*]}"
  exit 1
fi

# Check 3: Terraform configuration
echo ""
echo "3. Checking Terraform configuration..."
TF_DIR="/Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/terraform/control"
if [ -f "$TF_DIR/terraform.tfvars" ]; then
  echo "   ✅ terraform.tfvars exists"
  
  # Check key_name
  if grep -q "^key_name" "$TF_DIR/terraform.tfvars"; then
    KEY_NAME=$(grep "^key_name" "$TF_DIR/terraform.tfvars" | cut -d'"' -f2)
    echo "   ✅ SSH key configured: $KEY_NAME"
  else
    echo "   ❌ key_name not set in terraform.tfvars"
    exit 1
  fi
else
  echo "   ❌ terraform.tfvars not found"
  echo "      Expected location: $TF_DIR/terraform.tfvars"
  exit 1
fi

# Check 4: Packer files
echo ""
echo "4. Checking Packer configuration..."
PACKER_DIR="/Users/mikael/2-git/repro/nomad-autoscaler-demos/1-add-redhat/cloud/aws/packer"
if [ -f "$PACKER_DIR/aws-packer.pkr.hcl" ]; then
  echo "   ✅ Packer configuration exists"
else
  echo "   ❌ aws-packer.pkr.hcl not found"
  exit 1
fi

if [ -f "$PACKER_DIR/env-pkr-var.sh" ]; then
  echo "   ✅ env-pkr-var.sh exists"
else
  echo "   ❌ env-pkr-var.sh not found"
  exit 1
fi

# Check 5: AWS Region access
echo ""
echo "5. Checking AWS region access..."
REGION="us-west-2"
if aws ec2 describe-regions --region-names $REGION &> /dev/null; then
  echo "   ✅ Can access region: $REGION"
else
  echo "   ❌ Cannot access region: $REGION"
  exit 1
fi

# Check 6: Disk space
echo ""
echo "6. Checking available disk space..."
AVAILABLE_GB=$(df -h . | awk 'NR==2 {print $4}' | sed 's/Gi//')
if [ "${AVAILABLE_GB%%.*}" -gt 10 ]; then
  echo "   ✅ Sufficient disk space available: ${AVAILABLE_GB}GB"
else
  echo "   ⚠️  Low disk space: ${AVAILABLE_GB}GB"
fi

# All checks passed
echo ""
echo "============================================"
echo "  ✅ All pre-flight checks passed!"
echo "============================================"
echo ""
echo "You can now run the test:"
echo "  ./quick-test.sh ubuntu"
echo "  or"
echo "  ./quick-test.sh redhat"
echo ""
