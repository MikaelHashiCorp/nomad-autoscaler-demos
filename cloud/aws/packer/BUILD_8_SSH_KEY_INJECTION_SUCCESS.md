# Build #8: Automatic SSH Key Injection - SUCCESS ✅

**AMI ID**: `ami-0a7ba5fe6ab153cd6`  
**Build Date**: 2025-12-14  
**Build Time**: 20 minutes 51 seconds  
**Region**: us-west-2

## Overview

Build #8 successfully implements automatic SSH key injection from EC2 instance metadata. Instances launched from this AMI automatically configure SSH access using the EC2 key pair specified at launch time, eliminating the need for manual key configuration.

## Build Configuration

### Changes from Build #7
- Added automatic SSH key injection setup (lines 389-445 in setup-windows.ps1)
- Created startup script: `C:\ProgramData\ssh\inject-ec2-key.ps1`
- Created scheduled task: `InjectEC2SSHKey` (runs on boot)
- Script fetches public key from EC2 metadata (IMDSv2)
- Writes key to `C:\ProgramData\ssh\administrators_authorized_keys`
- Sets proper permissions (SYSTEM and Administrators only)

### Installation Order
1. HashiStack (Consul 1.22.1, Nomad 1.11.1, Vault 1.21.1)
2. Chocolatey v2.6.0
3. OpenSSH Server (via Chocolatey)
4. **SSH Key Injection Setup** (NEW)
5. Docker 24.0.7 (manual installation)

## Test Results

### Test Instance
- **Instance ID**: i-0c855747b8523bcdc
- **Public IP**: 35.94.31.72
- **Key Pair**: aws-mikael-test
- **Launch Time**: 2025-12-14 16:53:31 PST

### Component Verification

#### 1. Scheduled Task Status ✅
```
TaskName : InjectEC2SSHKey
State    : Ready
Triggers : Boot trigger configured
```

#### 2. SSH Service Status ✅
```
Name      : sshd
Status    : Running
StartType : Automatic
```

#### 3. Authorized Keys File ✅
```
File exists: YES
Key fingerprint: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDcQkNenqRWZp...
Source: EC2 Instance Metadata (IMDSv2)
```

#### 4. HashiStack Components ✅
```
- consul.exe (v1.22.1)
- nomad.exe (v1.11.1)
- vault.exe (v1.21.1)
```

#### 5. Docker Status ✅
```
Name      : docker
Status    : Running
StartType : Automatic
Version   : 24.0.7
```

## How It Works

### EC2 Metadata Key Injection

The scheduled task runs on every boot and performs these steps:

1. **Fetch Token** (IMDSv2):
   ```powershell
   $token = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "21600"} `
       -Method PUT -Uri http://169.254.169.254/latest/api/token
   ```

2. **Get Public Key**:
   ```powershell
   $pubKey = Invoke-RestMethod -Headers @{"X-aws-ec2-metadata-token" = $token} `
       -Uri http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key
   ```

3. **Write to Authorized Keys**:
   ```powershell
   Set-Content -Path C:\ProgramData\ssh\administrators_authorized_keys -Value $pubKey -Force
   ```

4. **Set Permissions**:
   ```powershell
   icacls $authKeysFile /inheritance:r
   icacls $authKeysFile /grant "SYSTEM:(F)"
   icacls $authKeysFile /grant "Administrators:(F)"
   ```

### Usage

Launch an instance with any EC2 key pair:
```bash
aws ec2 run-instances \
    --image-id ami-0a7ba5fe6ab153cd6 \
    --instance-type t3a.xlarge \
    --key-name YOUR-KEY-NAME \
    --security-group-ids sg-xxxxx \
    --region us-west-2
```

SSH access is automatically configured:
```bash
ssh -i ~/.ssh/YOUR-KEY-NAME.pem Administrator@<instance-ip>
```

## Key Features

### ✅ Automatic Configuration
- No manual key setup required
- Works with any EC2 key pair
- Runs on every boot (handles key rotation)

### ✅ Security
- Uses IMDSv2 (token-based metadata access)
- Proper file permissions (SYSTEM and Administrators only)
- No hardcoded credentials

### ✅ Reliability
- Scheduled task ensures key is always current
- Handles instance stop/start cycles
- Logs available in Task Scheduler

## Comparison with Previous Builds

| Feature | Build #7 | Build #8 |
|---------|----------|----------|
| HashiStack | ✅ | ✅ |
| Chocolatey | ✅ | ✅ |
| SSH Server | ✅ | ✅ |
| Docker | ✅ | ✅ |
| **Auto SSH Key** | ❌ Manual | ✅ **Automatic** |
| Build Time | 19m 20s | 20m 51s |

## Known Limitations

### Default Shell
- SSH sessions default to `cmd.exe` instead of PowerShell
- Workaround: Use `ssh user@host 'powershell -Command "..."'`
- Future improvement: Configure PowerShell as default shell

### Key Rotation
- Scheduled task runs on boot only
- Key changes require instance restart
- Could be enhanced with periodic checks

## Next Steps

### STEP 3: Switch Docker to Chocolatey
- Replace manual Docker installation with `choco install docker-engine`
- Expected benefits: Better maintainability, consistent with SSH approach
- Risk: Might affect Docker persistence (needs testing)

### STEP 4: Refactor Installation Order
- Move SSH installation before HashiStack
- Rationale: SSH should be available immediately for connectivity
- New order: SSH → Chocolatey → HashiStack → Docker

## Conclusion

Build #8 successfully implements automatic SSH key injection, making the Windows AMI much more user-friendly. Instances can now be launched with any EC2 key pair and SSH access is automatically configured without manual intervention.

**Status**: ✅ **PRODUCTION READY** (with automatic SSH key injection)

All components verified working:
- ✅ HashiStack binaries persist
- ✅ Docker persists and runs
- ✅ SSH Server installed and running
- ✅ Chocolatey package manager available
- ✅ **SSH keys automatically injected from EC2 metadata**

---

**Build Log**: `./logs/mikael-CCWRLY72J2_packer_20251215-002741.783Z.out`  
**Test Script**: `test-ami-build8.sh`  
**Documentation**: `SSH_KEY_INJECTION.md`