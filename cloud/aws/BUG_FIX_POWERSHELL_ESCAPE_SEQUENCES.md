# Bug Fix: PowerShell Escape Sequence in String Literals

## Date
2025-12-17 00:29 UTC

## Bug Description
PowerShell parser error in `client.ps1` caused by backslash escape sequences in double-quoted strings.

## Error Message
```
At C:\ops\scripts\client.ps1:181 char:53
+ Write-Host "  Nomad:         C:\HashiCorp\Nomad\logs"
+                                                     ~
The string is missing the terminator: ".
```

## Root Cause
In PowerShell double-quoted strings, backslashes before certain characters are interpreted as escape sequences:
- `\l` in `\logs` was interpreted as an escape sequence
- `\N` in `\Nomad` was interpreted as an escape sequence
- This caused the closing quote to be escaped, resulting in unterminated string

## Lines Affected
- Line 180: `Write-Host "  Consul:        C:\HashiCorp\Consul\logs"`
- Line 181: `Write-Host "  Nomad:         C:\HashiCorp\Nomad\logs"`

## Fix Applied
Changed double quotes to single quotes to prevent escape sequence interpretation:
```powershell
# Before (BROKEN):
Write-Host "  Consul:        C:\HashiCorp\Consul\logs"
Write-Host "  Nomad:         C:\HashiCorp\Nomad\logs"

# After (FIXED):
Write-Host '  Consul:        C:\HashiCorp\Consul\logs'
Write-Host '  Nomad:         C:\HashiCorp\Nomad\logs'
```

## Why Single Quotes Work
- Single quotes in PowerShell are literal strings - no variable expansion or escape sequences
- Double quotes interpret escape sequences and expand variables
- For static paths with backslashes, single quotes are safer

## Alternative Solutions
1. Escape backslashes: `"C:\\HashiCorp\\Nomad\\logs"`
2. Use verbatim strings: `@"C:\HashiCorp\Nomad\logs"@`
3. Use single quotes (chosen solution - simplest)

## Impact
- User-data script failed to execute on Windows instances
- Windows clients could not join Nomad cluster
- Required AMI rebuild and redeployment

## Files Modified
- `../shared/packer/scripts/client.ps1` (lines 180-181)

## Next Steps
1. Rebuild Windows AMI with fixed script
2. Redeploy infrastructure
3. Verify Windows client joins cluster