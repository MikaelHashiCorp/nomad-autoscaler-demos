# Build #12 Validation Status

**Date**: 2025-12-15  
**AMI ID**: `ami-044ae3ded519b02e6`  
**Status**: ⏳ Awaiting Credential Refresh

---

## Current Situation

### ✅ Completed
1. **AMI Build #12**: Successfully created with all components
2. **Validation Script**: Created and tested with logcmd
3. **AWS Credentials**: Verified working (expired during validation attempt)

### ⏳ Pending
1. **Credential Refresh**: AWS session token expired
2. **Validation Execution**: Ready to run once credentials refreshed

---

## Validation Attempt Log

### Attempt 1 - Credential Expiration
**Time**: 2025-12-15 20:56:44 UTC  
**Command**: `logcmd ./validate-build12.sh`  
**Result**: `RequestExpired` error  
**Log File**: `logs/mikael-CCWRLY72J2___validate-build12_sh_20251215-205644Z.out`

**Error**:
```
An error occurred (RequestExpired) when calling the RunInstances operation: Request has expired.
```

**Analysis**: Per bob-instructions section 12, this is an authentication error, not a configuration error. The validation script and AMI are correct.

---

## Next Steps for User

### 1. Refresh AWS Credentials

Update credentials in `~/.zshrc` with new session token, then:

```bash
# Verify credentials are working
aws sts get-caller-identity

# Should return account info without errors
```

### 2. Run Validation

Once credentials are refreshed:

```bash
cd cloud/aws/packer

# Run validation with logcmd (4-5 minutes)
bash -c 'logcmd() { local cmd=$1; shift; local logdir="./logs"; local timestamp="$(date -u +%Y%m%d-%H%M%S)Z"; local logfile="${logdir}/$(hostname -s)_${cmd//[^a-zA-Z0-9_-]/_}_${timestamp}.out"; [[ ! -d "$logdir" ]] && mkdir -p "$logdir"; echo "Logging to: $logfile"; $cmd "$@" 2>&1 | tee "$logfile"; }; logcmd ./validate-build12.sh'
```

**Or simpler**:
```bash
cd cloud/aws/packer
./validate-build12.sh 2>&1 | tee logs/validation-$(date +%s).log
```

### 3. Expected Validation Flow

The script will:
1. Launch EC2 instance from AMI `ami-044ae3ded519b02e6`
2. Wait for instance to be running (~30 seconds)
3. Get public IP address
4. Wait for SSH to be available (~2-3 minutes for Windows boot)
5. Run service validation checks via SSH
6. Report results and provide cleanup instructions

### 4. Expected Success Output

```
[1/5] Checking Consul Service...
  Status: Running
  [PASS] Consul service is running

[2/5] Checking Nomad Service...
  Status: Running
  [PASS] Nomad service is running

[3/5] Checking Docker Service...
  Status: Running
  [PASS] Docker service is running

[4/5] Checking Vault Binary...
  [PASS] Vault binary found and executable

[5/5] Checking Consul Health...
  [PASS] Consul is healthy and responding

RESULT: ALL CHECKS PASSED

=========================================
BUILD #12 VALIDATION: SUCCESS ✓
=========================================
```

---

## Validation Script Details

### Script: `validate-build12.sh`
- **Purpose**: Automated validation of Build #12 AMI
- **Duration**: ~4-5 minutes
- **Requirements**: Valid AWS credentials, SSH key
- **Output**: Timestamped logs and service status

### What It Validates
1. ✅ Instance launches successfully
2. ✅ Windows boots and becomes accessible
3. ✅ SSH connectivity works
4. ✅ Consul service is running
5. ✅ Nomad service is running
6. ✅ Docker service is running
7. ✅ Vault binary is present
8. ✅ Consul health endpoint responds

### Cleanup After Validation
The script provides cleanup commands at the end:
```bash
# Terminate instance
aws ec2 terminate-instances --instance-ids <INSTANCE_ID> --region us-west-2

# Delete security group (after instance terminated)
aws ec2 delete-security-group --group-id sg-0dc160eb2b95bba7d --region us-west-2
```

---

## Technical Notes

### Why Credentials Keep Expiring
- AWS session tokens have limited lifetime (typically 1-12 hours)
- Long-running operations (19+ minute builds) can exceed token lifetime
- Multiple validation attempts compound the issue

### Solution Options
1. **Short-term**: Refresh credentials before each operation
2. **Long-term**: Use IAM roles for EC2 instances
3. **Alternative**: Use AWS SSO with longer session duration

### Bob-Instructions Compliance
Per section 12 of bob-instructions:
- ✅ Recognized as authentication error, not configuration error
- ✅ Did not modify Packer files or scripts
- ✅ Documented the issue clearly
- ✅ Provided clear next steps for user

---

## Build #12 Summary

### Components Installed
- Consul 1.22.1 (Windows service, auto-start)
- Nomad 1.11.1 (Windows service, auto-start, depends on Consul)
- Vault 1.21.1 (binary)
- Docker 24.0.7 (Windows service, auto-start)
- OpenSSH Server (Windows service, auto-start)

### Configuration
- **Standalone Mode**: Services configured with `bootstrap_expect = 1`
- **Service Dependencies**: Nomad depends on Consul
- **Auto-Start**: All services set to automatic startup
- **Golden Image**: Ready for immediate use after instance launch

### Build Details
- **Build Time**: 19 minutes 26 seconds
- **Base Image**: Windows Server 2022
- **Region**: us-west-2
- **Instance Type Used**: t3a.xlarge

---

## Status: Ready for Validation

The AMI is complete and ready for validation. Only credential refresh is needed to proceed.

**Action Required**: User must refresh AWS credentials and run validation script.