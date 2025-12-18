# Bug Fix: PowerShell Variable Expansion with Backslashes

## Date
2025-12-17 01:05 UTC

## Bug Description
**Third PowerShell escape sequence bug** discovered during Windows client deployment testing.

### Root Cause
Line 179 in `../shared/packer/scripts/client.ps1` used direct variable expansion in a double-quoted string:
```powershell
Write-Host "  Client Config: $LogFile"
```

Where `$LogFile = "C:\ProgramData\client-config.log"` (line 22).

When PowerShell expands `$LogFile` inside the double-quoted string, the backslash in `\client-config.log` is interpreted as an escape sequence `\c`, causing the closing quote to be escaped and resulting in a parser error.

### Error Message
```
At C:\ops\scripts\client.ps1:179 char:38
+ Write-Host "  Client Config: $LogFile"
+                                      ~
The string is missing the terminator: ".
```

### Impact
- User-data script failed to execute on Windows instances
- Windows clients could not join Nomad cluster
- EC2Launch v2 logged: "Script produced error output"

## Fix Applied

### File: `../shared/packer/scripts/client.ps1`

**Line 179 - Use subexpression syntax to safely expand variables:**
```powershell
# Before (BROKEN):
Write-Host "  Client Config: $LogFile"

# After (FIXED):
Write-Host "  Client Config: $($LogFile)"
```

### Why This Fix Works
Using `$($LogFile)` (subexpression syntax) ensures the variable is expanded first, then the result is inserted into the string. This prevents the backslashes in the path from being interpreted as escape sequences during string parsing.

## Related Bugs
This is the **third** PowerShell escape sequence bug in this file:
1. **Bug 1** (lines 180-181): Fixed by changing double quotes to single quotes for literal paths
2. **Bug 2** (line 179): Fixed by using subexpression syntax for variable expansion

## Testing Required
1. Rebuild Windows AMI with this fix
2. Deploy infrastructure with new AMI
3. Verify Windows client joins Nomad cluster
4. Check EC2Launch v2 logs show no errors

## Lessons Learned
**PowerShell String Handling Best Practices:**
1. Use **single quotes** for literal strings with backslashes (no variable expansion needed)
2. Use **subexpression syntax** `$($variable)` when expanding variables containing paths in double-quoted strings
3. Avoid direct variable expansion like `"text $variable"` when the variable contains backslashes
4. Always test PowerShell scripts with paths containing backslashes

## Next Steps
1. Rebuild Windows AMI (ami-09c2b4ea5901677b3 is broken)
2. Deploy new infrastructure
3. Verify Windows client registration