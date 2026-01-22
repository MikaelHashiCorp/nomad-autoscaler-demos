#!/bin/bash
# Quick OS Switch Configuration Examples
# Place this in aws/packer/ directory
# Note: Uses latest available versions; Packer will select most recent AMI

# Ubuntu 24.04 (Noble) - Latest
cat > ubuntu-24.04.pkrvars.hcl << 'EOF'
os         = "Ubuntu"
os_version = "24.04"
os_name    = "noble"
EOF

# Ubuntu 22.04 (Jammy) - Latest
cat > ubuntu-22.04.pkrvars.hcl << 'EOF'
os         = "Ubuntu"
os_version = "22.04"
os_name    = "jammy"
EOF

# RedHat 9 - Latest
cat > rhel-9.pkrvars.hcl << 'EOF'
os         = "RedHat"
os_version = "9*"
os_name    = ""
EOF

# RedHat 8 - Latest
cat > rhel-8.pkrvars.hcl << 'EOF'
os         = "RedHat"
os_version = "8*"
os_name    = ""
EOF

echo "Created OS configuration files:"
echo "  - ubuntu-24.04.pkrvars.hcl"
echo "  - ubuntu-22.04.pkrvars.hcl"
echo "  - rhel-9.pkrvars.hcl"
echo "  - rhel-8.pkrvars.hcl"
echo ""
echo "Usage examples:"
echo "  packer build -var-file=ubuntu-24.04.pkrvars.hcl ."
echo "  packer build -var-file=rhel-9.pkrvars.hcl ."
echo ""
echo "Note: The build process will:"
echo "  1. Select the latest available AMI for the OS version"
echo "  2. Run 'apt-get upgrade' (Ubuntu) or 'yum update' (RedHat)"
echo "  3. Apply all available security patches"
