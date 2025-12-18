# Bug Analysis: Nomad Config Path Mismatch

## Issue Summary
Windows Nomad client fails to join cluster due to configuration file path mismatch between service definition and user-data script.

## Root Cause
**Service Configuration** (created during AMI build):
```
BINARY_PATH_NAME: C:\HashiCorp\bin\nomad.exe agent -config=C:\HashiCorp\Nomad\config\nomad.hcl
```

**User-Data Script** (client.ps1 line 127):
```powershell
$NomadConfigFile = "$NOMADCONFIGDIR\nomad.hcl"  # Writes to C:\HashiCorp\Nomad\nomad.hcl
```

**Result**: Service loads `C:\HashiCorp\Nomad\config\nomad.hcl` (base config with Linux paths), but user-data writes to `C:\HashiCorp\Nomad\nomad.hcl` (never loaded).

## Evidence

### 1. Service Configuration
```
SERVICE_NAME: Nomad
BINARY_PATH_NAME: C:\HashiCorp\bin\nomad.exe agent -config=C:\HashiCorp\Nomad\config\nomad.hcl
START_TYPE: AUTO_START
DEPENDENCIES: Consul
```

### 2. Config File in Use (C:\HashiCorp\Nomad\config\nomad.hcl)
```hcl
data_dir  = "/opt/nomad/data"      # WRONG - Linux path
log_file  = "/opt/nomad/logs/"     # WRONG - Linux path
node_class = NODE_CLASS             # WRONG - Not replaced
```

### 3. User-Data Execution
- User-data log shows: "Client configuration completed successfully"
- But config file was written to wrong location
- Service never restarted to pick up new config
- Nomad runs with base AMI config (Linux paths)

### 4. Symptoms
- ✅ Consul service running
- ✅ Nomad service running  
- ❌ No nodes registered in cluster
- ❌ Config has Linux paths instead of Windows paths
- ❌ NODE_CLASS placeholder not replaced

## Impact
- Windows clients cannot join Nomad cluster
- Jobs cannot be scheduled on Windows nodes
- Complete failure of Windows client functionality

## Fix Required

### Option 1: Update client.ps1 to match service path
Change line 127 in `../shared/packer/scripts/client.ps1`:
```powershell
# OLD:
$NomadConfigFile = "$NOMADCONFIGDIR\nomad.hcl"

# NEW:
$NomadConfigFile = "$NOMADCONFIGDIR\config\nomad.hcl"
```

### Option 2: Update service definition during AMI build
Modify `setup-windows.ps1` to create service without `config\` subdirectory:
```powershell
$configPath = "C:\HashiCorp\Nomad\nomad.hcl"
```

### Recommendation
**Use Option 1** - Update client.ps1 to write to `config\nomad.hcl`. This is safer because:
1. Service is already created in AMI
2. Matches existing directory structure
3. Minimal change required
4. No risk of breaking AMI build

## Additional Issues Found

### Issue 2: Service Not Restarted
Even if config path was correct, the service needs to be restarted after config update. Add to client.ps1 after line 128:
```powershell
Write-Host "  Restarting Nomad service to apply configuration..."
Restart-Service -Name "Nomad" -Force
Start-Sleep -Seconds 5
```

### Issue 3: No Validation
Script doesn't verify:
- Config file was written successfully
- Service restarted successfully  
- Node registered with cluster

## Testing Plan
1. Fix config path in client.ps1
2. Add service restart
3. Rebuild Windows AMI
4. Deploy new instance
5. Verify node joins cluster:
   ```bash
   nomad node status
   ```
6. Check node attributes include `hashistack-windows`

## Timeline
- **Bug Introduced**: During initial Windows client implementation
- **Discovered**: 2025-12-16 23:13 UTC
- **Deployment Affected**: All Windows client deployments since initial implementation
- **Severity**: Critical - Complete feature failure

## Related Files
- `../shared/packer/scripts/client.ps1` (lines 127-150)
- `../shared/packer/scripts/setup-windows.ps1` (Nomad service creation)
- `terraform/modules/aws-hashistack/templates/user-data-client-windows.ps1`