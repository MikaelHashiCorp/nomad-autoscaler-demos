# Bug Fix: Nomad Config Path Mismatch

## Issue
Windows Nomad clients failed to join cluster because user-data script wrote config to wrong location.

## Root Cause
- **Service expected**: `C:\HashiCorp\Nomad\config\nomad.hcl`
- **Script wrote to**: `C:\HashiCorp\Nomad\nomad.hcl`
- **Result**: Service loaded base AMI config with Linux paths instead of Windows-specific config

## Fix Applied
Modified `../shared/packer/scripts/client.ps1`:

### Change 1: Config File Path (Line 127)
```powershell
# OLD:
$NomadConfigFile = "$NOMADCONFIGDIR\nomad.hcl"

# NEW:
$NomadConfigFile = "$NOMADCONFIGDIR\config\nomad.hcl"
```

### Change 2: Service Dependency (Line 150)
```powershell
# OLD:
& sc.exe create "Nomad" binPath= "`"$NomadBinary`" $NomadArgs" start= auto

# NEW:
& sc.exe create "Nomad" binPath= "`"$NomadBinary`" $NomadArgs" start= auto depend= Consul
```

## Impact
- Config now written to correct location matching service definition
- Nomad service properly depends on Consul service
- Windows clients will now join cluster with correct configuration

## Testing Required
1. Destroy current deployment
2. Rebuild Windows AMI with fixed client.ps1
3. Deploy new Windows client instance
4. Verify node joins cluster: `nomad node status`
5. Verify node class is `hashistack-windows`

## Files Modified
- `../shared/packer/scripts/client.ps1` (lines 127, 150)

## Related Documents
- `BUG_ANALYSIS_NOMAD_CONFIG_PATH_MISMATCH.md` - Detailed analysis
- `TASK_REQUIREMENTS.md` - Project requirements
- `TESTING_PLAN.md` - Testing procedures