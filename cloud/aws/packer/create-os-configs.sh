#!/bin/bash
# Quick OS Switch Configuration Examples
# Place this in aws/packer/ directory

# Ubuntu 24.04 (Noble) - Default
cat > ubuntu-24.04.pkrvars.hcl << 'EOF'
os         = "Ubuntu"
os_version = "24.04"
os_name    = "noble"
EOF

# Ubuntu 22.04 (Jammy)
cat > ubuntu-22.04.pkrvars.hcl << 'EOF'
os         = "Ubuntu"
os_version = "22.04"
os_name    = "jammy"
EOF

# RedHat 9.6
cat > rhel-9.6.pkrvars.hcl << 'EOF'
os         = "RedHat"
os_version = "9.6.0"
os_name    = ""
EOF

# RedHat 9.5
cat > rhel-9.5.pkrvars.hcl << 'EOF'
os         = "RedHat"
os_version = "9.5.0"
os_name    = ""
EOF

# RedHat 8.10
cat > rhel-8.10.pkrvars.hcl << 'EOF'
os         = "RedHat"
os_version = "8.10.0"
os_name    = ""
EOF

# Windows Server 2022
cat > windows-2022.pkrvars.hcl << 'EOF'
os         = "Windows"
os_version = "2022"
os_name    = ""
EOF

echo "Created OS configuration files:"
echo "  - ubuntu-24.04.pkrvars.hcl"
echo "  - ubuntu-22.04.pkrvars.hcl"
echo "  - rhel-9.6.pkrvars.hcl"
echo "  - rhel-9.5.pkrvars.hcl"
echo "  - rhel-8.10.pkrvars.hcl"
echo "  - windows-2022.pkrvars.hcl"
echo ""
echo "Usage examples:"
echo "  packer build -var-file=ubuntu-24.04.pkrvars.hcl ."
echo "  packer build -var-file=rhel-9.6.pkrvars.hcl ."
echo "  packer build -var-file=windows-2022.pkrvars.hcl ."
