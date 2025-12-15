# Build #12 - AWS Authentication Failure

## Date
2025-12-15 12:26:21 PST

## Error Summary
```
error validating regions: RequestExpired: Request has expired.
status code: 400, request id: 84c48027-ca81-44d9-a1e3-870f3a25ae01
```

## Log File
`cloud/aws/packer/logs/mikael-CCWRLY72J2_packer_20251215-202621.301Z.out`

## Root Cause
AWS credentials have expired. The build failed during the initial AWS region validation phase, before any EC2 resources were created.

## What Worked
✅ Packer configuration is valid
✅ Variables loaded correctly
✅ All plugins initialized successfully
✅ Build target specified correctly with `-only` flag
✅ run-with-timestamps.sh executed properly

## What Failed
❌ AWS authentication - credentials expired after 42 seconds

## Resolution Required
User needs to refresh AWS credentials before retrying the build.

### Options to Refresh AWS Credentials

#### Option 1: AWS SSO (if using SSO)
```bash
aws sso login --profile <profile-name>
```

#### Option 2: AWS CLI Configure
```bash
aws configure
# Enter new credentials
```

#### Option 3: Environment Variables
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_SESSION_TOKEN="your-session-token"  # if using temporary credentials
```

#### Option 4: AWS Vault (if installed)
```bash
aws-vault exec <profile-name> -- <command>
```

## Verification
After refreshing credentials, verify they work:
```bash
aws sts get-caller-identity
aws ec2 describe-regions --region us-west-2
```

## Next Steps
1. Refresh AWS credentials using one of the methods above
2. Verify credentials with `aws sts get-caller-identity`
3. Re-run the build:
   ```bash
   cd cloud/aws/packer
   ./run-with-timestamps.sh -only='windows.amazon-ebs.hashistack' -var-file=windows-2022.pkrvars.hcl .
   ```

## Build Configuration Status
All Packer configuration changes from Build #12 are ready:
- ✅ Consul standalone configuration
- ✅ Nomad standalone configuration  
- ✅ Explicit build target with `-only` flag
- ✅ Proper use of run-with-timestamps.sh

The build will proceed successfully once AWS credentials are refreshed.

## Technical Notes
- Build failed at 42 seconds during AWS API validation
- No EC2 resources were created
- No cleanup required
- Configuration is ready for immediate retry after credential refresh