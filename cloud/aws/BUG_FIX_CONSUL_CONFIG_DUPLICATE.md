# Bug Fix: Duplicate retry_join in Consul Client Config

## Date
2025-12-17

## Bug Description
The Consul client configuration template (`../shared/packer/config/consul_client.hcl`) contained duplicate `retry_join` entries, causing Consul service startup failures on Windows clients.

## Root Cause
The template file had two `retry_join` declarations:
1. **Line 8**: Hardcoded value `retry_join = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]`
2. **Line 15**: Template variable `retry_join = ["RETRY_JOIN"]`

When the PowerShell script performed string replacement:
```powershell
$ConsulConfig = $ConsulConfig -replace 'RETRY_JOIN', $RetryJoin
```

The result was:
```hcl
retry_join = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]  # Line 8
...
retry_join = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]  # Line 15 after replacement
```

HCL doesn't allow duplicate keys, causing the configuration to become corrupted and Consul to fail to start.

## Symptoms
1. Windows client user-data script executed successfully
2. Consul service was created but failed to start
3. Error: `Start-Service : Failed to start service 'Consul (Consul)'`
4. Generated config file had malformed syntax:
   ```
   provider=aws tag_key=ConsulAutoJoin tag_value=auto-join = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
   ```

## Investigation Process
1. Verified user-data executed (EC2Launch v2 logs showed completion)
2. Checked user-data error output - found Consul service start failure
3. Examined Consul service status - service stopped
4. Reviewed generated Consul config - found syntax errors
5. Checked template file - discovered duplicate `retry_join` entries

## Solution
Removed the hardcoded `retry_join` entry from line 8 of `../shared/packer/config/consul_client.hcl`.

**Before:**
```hcl
data_dir       = "/opt/consul/data"
retry_join     = ["provider=aws tag_key=ConsulAutoJoin tag_value=auto-join"]
ui             = true
enable_syslog  = true
log_level      = "TRACE"
log_file       = "/opt/consul/logs/"
log_rotate_duration  = "1h"
log_rotate_max_files = 3
retry_join = ["RETRY_JOIN"]
```

**After:**
```hcl
data_dir       = "/opt/consul/data"
ui             = true
enable_syslog  = true
log_level      = "TRACE"
log_file       = "/opt/consul/logs/"
log_rotate_duration  = "1h"
log_rotate_max_files = 3
retry_join = ["RETRY_JOIN"]
```

## Files Modified
- `../shared/packer/config/consul_client.hcl` - Removed duplicate retry_join on line 8

## Testing
After fix:
1. Rebuild Windows AMI with corrected template
2. Deploy infrastructure
3. Verify Consul service starts successfully
4. Verify Windows client joins Nomad cluster

## Related Issues
- UTF-8 checkmark characters in client.ps1 (fixed separately)
- EC2Launch v2 state management (fixed separately)

## Lessons Learned
1. Template files should not contain hardcoded values that are meant to be replaced
2. Always validate generated configuration files for syntax errors
3. HCL duplicate key errors can manifest as cryptic syntax errors
4. Service startup failures require checking both service status AND configuration validity

## Impact
- **Severity**: Critical - Prevented Windows clients from joining cluster
- **Scope**: All Windows client deployments
- **Detection**: Manual testing revealed service startup failure