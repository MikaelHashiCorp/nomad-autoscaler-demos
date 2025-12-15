# SSH Key Injection for Windows AMI

## Overview

The Windows AMI is configured to automatically inject EC2 key pair public keys into SSH authorized_keys on instance startup. This enables SSH access using any EC2 key pair specified at instance launch.

## Validation Script

Before launching instances, validate your SSH key pair setup:

```bash
./packer/validate-ssh-key.sh [key-name] [region]

# Examples:
./packer/validate-ssh-key.sh aws-mikael-test us-west-2
./packer/validate-ssh-key.sh                          # Uses defaults
```

The script checks:
1. AWS authentication status
2. Key pair exists in AWS (correct account/region)
3. Private key exists locally (~/.ssh/)
4. Private key has correct permissions (400 or 600)
5. Public key exists locally (optional)
6. Fingerprint comparison (MD5)

**Note**: The fingerprint check compares the local public key with AWS. If they don't match but SSH works, the private key is correct and the local .pub file may be outdated.

## How It Works

### Components

1. **Startup Script**: `C:\ProgramData\ssh\inject-ec2-key.ps1`
   - Fetches public key from EC2 instance metadata (IMDSv2)
   - Writes to `C:\ProgramData\ssh\administrators_authorized_keys`
   - Sets proper permissions (SYSTEM and Administrators only)

2. **Scheduled Task**: `InjectEC2SSHKey`
   - Runs on every instance boot
   - Executes as SYSTEM with highest privileges
   - Ensures SSH key is always current

### Metadata Endpoint

The script uses EC2 Instance Metadata Service v2 (IMDSv2):
```
Token URL: http://169.254.169.254/latest/api/token
Public Key URL: http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key
```

## Usage

### Launching an Instance with SSH Access

```bash
# Launch instance with your EC2 key pair
aws ec2 run-instances \
  --image-id ami-0d98b7855341abf8a \
  --instance-type t3a.xlarge \
  --key-name aws-mikael-test \
  --region us-west-2

# SSH will automatically work
ssh -i ~/.ssh/aws-mikael-test.pem Administrator@<instance-ip>
```

### Supported Key Types

The SSH server is configured to accept RSA keys:
- `PubkeyAuthentication yes`
- `PubkeyAcceptedKeyTypes +ssh-rsa`

### Key Pairs in AWS

Available RSA key pairs in us-west-2:
- `aws-mikael-test` (RSA) - ✅ Tested and working
- `aws-enos-mws-4` (RSA)
- `mhc-aws-mws-west-2` (RSA)

## Implementation Details

### Installation (in setup-windows.ps1)

```powershell
# [6/6] Creating SSH key injection startup script...
# Creates C:\ProgramData\ssh\inject-ec2-key.ps1
# Registers scheduled task "InjectEC2SSHKey"
```

### Startup Script Logic

1. Request IMDSv2 token (21600 second TTL)
2. Fetch public key from metadata
3. Create SSH directory if needed
4. Write public key to authorized_keys
5. Set permissions using icacls

### Permissions

```
C:\ProgramData\ssh\administrators_authorized_keys
- SYSTEM: Full Control
- Administrators: Full Control
- Inheritance: Disabled
```

## Testing

### Verify Scheduled Task

```powershell
Get-ScheduledTask -TaskName "InjectEC2SSHKey"
```

### Verify Startup Script

```powershell
Get-Content C:\ProgramData\ssh\inject-ec2-key.ps1
```

### Verify Authorized Keys

```powershell
Get-Content C:\ProgramData\ssh\administrators_authorized_keys
```

### Test SSH Connection

```bash
ssh -i ~/.ssh/aws-mikael-test.pem Administrator@<instance-ip>
```

## Troubleshooting

### SSH Connection Refused

1. Check SSH service is running:
   ```powershell
   Get-Service sshd
   ```

2. Check firewall rule:
   ```powershell
   Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP"
   ```

3. Check security group allows port 22

### Key Not Injected

1. Check scheduled task ran:
   ```powershell
   Get-ScheduledTask -TaskName "InjectEC2SSHKey" | Get-ScheduledTaskInfo
   ```

2. Manually run the injection script:
   ```powershell
   PowerShell.exe -ExecutionPolicy Bypass -File "C:\ProgramData\ssh\inject-ec2-key.ps1"
   ```

3. Check instance metadata is accessible:
   ```powershell
   $token = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "21600"} -Method PUT -Uri "http://169.254.169.254/latest/api/token"
   Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token" = $token} -Uri "http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key"
   ```

### Wrong Key in Authorized Keys

The script overwrites authorized_keys on every boot to ensure it matches the instance's key pair. If you need to add additional keys, modify the script to append instead of overwrite.

## Security Considerations

1. **IMDSv2 Only**: Script uses token-based metadata access (more secure than IMDSv1)
2. **Proper Permissions**: Only SYSTEM and Administrators can read authorized_keys
3. **Automatic Updates**: Key is refreshed on every boot to match current key pair
4. **No Hardcoded Keys**: Keys come from EC2 metadata, not baked into AMI

## Future Enhancements

1. Support for multiple keys (append instead of overwrite)
2. Key rotation detection and logging
3. Integration with AWS Systems Manager Parameter Store for additional keys
4. Support for ED25519 keys (currently RSA only)