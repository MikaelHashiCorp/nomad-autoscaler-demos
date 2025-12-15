#!/bin/bash
# Validate SSH Key Pair for Windows AMI
# Checks that the specified key pair exists in AWS and locally

set -e

# Configuration
KEY_NAME="${1:-aws-mikael-test}"
REGION="${2:-us-west-2}"
SSH_DIR="$HOME/.ssh"

echo "=========================================="
echo "SSH Key Pair Validation"
echo "=========================================="
echo "Key Name: $KEY_NAME"
echo "Region: $REGION"
echo "SSH Directory: $SSH_DIR"
echo ""

# Check AWS authentication
echo "[1/5] Checking AWS authentication..."
if ! aws sts get-caller-identity --region "$REGION" &>/dev/null; then
    echo "  ❌ ERROR: Not authenticated to AWS"
    echo "  Please run: eval \$(doormat aws export --account <account>)"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --region "$REGION" --query 'Account' --output text)
echo "  ✅ Authenticated to AWS Account: $ACCOUNT_ID"
echo ""

# Check if key pair exists in AWS
echo "[2/5] Checking if key pair exists in AWS..."
if ! aws ec2 describe-key-pairs --region "$REGION" --key-names "$KEY_NAME" &>/dev/null; then
    echo "  ❌ ERROR: Key pair '$KEY_NAME' not found in region $REGION"
    echo ""
    echo "Available key pairs in $REGION:"
    aws ec2 describe-key-pairs --region "$REGION" --query 'KeyPairs[*].[KeyName,KeyType]' --output table
    exit 1
fi

KEY_TYPE=$(aws ec2 describe-key-pairs --region "$REGION" --key-names "$KEY_NAME" --query 'KeyPairs[0].KeyType' --output text)
echo "  ✅ Key pair '$KEY_NAME' exists in AWS (Type: $KEY_TYPE)"
echo ""

# Check if private key exists locally
echo "[3/5] Checking for local private key..."
PRIVATE_KEY_PATH="$SSH_DIR/${KEY_NAME}.pem"

if [ ! -f "$PRIVATE_KEY_PATH" ]; then
    echo "  ❌ ERROR: Private key not found at $PRIVATE_KEY_PATH"
    echo ""
    echo "Available .pem files in $SSH_DIR:"
    ls -1 "$SSH_DIR"/*.pem 2>/dev/null || echo "  No .pem files found"
    exit 1
fi

echo "  ✅ Private key found: $PRIVATE_KEY_PATH"
echo ""

# Check private key permissions
echo "[4/5] Checking private key permissions..."
PERMS=$(stat -f "%Lp" "$PRIVATE_KEY_PATH" 2>/dev/null || stat -c "%a" "$PRIVATE_KEY_PATH" 2>/dev/null)

if [ "$PERMS" != "400" ] && [ "$PERMS" != "600" ]; then
    echo "  ⚠️  WARNING: Private key has permissions $PERMS (should be 400 or 600)"
    echo "  Fix with: chmod 400 $PRIVATE_KEY_PATH"
else
    echo "  ✅ Private key permissions: $PERMS"
fi
echo ""

# Check if public key exists locally
echo "[5/5] Checking for local public key..."
PUBLIC_KEY_PATH="$SSH_DIR/${KEY_NAME}.pub"

if [ -f "$PUBLIC_KEY_PATH" ]; then
    echo "  ✅ Public key found: $PUBLIC_KEY_PATH"
    
    # Show key fingerprint
    if command -v ssh-keygen &>/dev/null; then
        # Get both SHA256 and MD5 fingerprints
        LOCAL_SHA256=$(ssh-keygen -lf "$PUBLIC_KEY_PATH" 2>/dev/null | awk '{print $2}')
        LOCAL_MD5=$(ssh-keygen -E md5 -lf "$PUBLIC_KEY_PATH" 2>/dev/null | awk '{print $2}' | sed 's/MD5://')
        AWS_FINGERPRINT=$(aws ec2 describe-key-pairs --region "$REGION" --key-names "$KEY_NAME" --query 'KeyPairs[0].KeyFingerprint' --output text)
        
        echo "  Local SHA256:  $LOCAL_SHA256"
        echo "  Local MD5:     $LOCAL_MD5"
        echo "  AWS MD5:       $AWS_FINGERPRINT"
        
        if [ "$LOCAL_MD5" != "$AWS_FINGERPRINT" ]; then
            echo "  ⚠️  WARNING: MD5 fingerprints don't match - keys may be different!"
        else
            echo "  ✅ Fingerprints match"
        fi
    fi
else
    echo "  ⚠️  Public key not found at $PUBLIC_KEY_PATH"
    echo "  This is optional but recommended for verification"
fi
echo ""

echo "=========================================="
echo "✅ Validation Complete"
echo "=========================================="
echo "You can use this key pair to launch instances:"
echo ""
echo "  aws ec2 run-instances \\"
echo "    --image-id <ami-id> \\"
echo "    --key-name $KEY_NAME \\"
echo "    --region $REGION \\"
echo "    ..."
echo ""
echo "SSH connection will work automatically:"
echo ""
echo "  ssh -i $PRIVATE_KEY_PATH Administrator@<instance-ip>"
echo ""

# Made with Bob
