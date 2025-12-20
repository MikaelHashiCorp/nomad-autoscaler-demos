# Apply Windows Desktop Heap Fix
# This script implements the fix from KB article 1-KB-Nomad-Allocation-Failure.md
# Increases Non-Interactive Desktop Heap from 768 KB to 4096 KB

Write-Host "=== Applying Windows Desktop Heap Fix ===" -ForegroundColor Cyan
Write-Host ""

# Registry path for Desktop Heap settings
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems"
$regKey = "Windows"

# Get current value
Write-Host "Current Registry Value:" -ForegroundColor Yellow
try {
    $currentValue = Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction Stop
    Write-Host $currentValue.Windows
    Write-Host ""
    
    # Parse current SharedSection
    if ($currentValue.Windows -match "SharedSection=(\d+),(\d+),(\d+)") {
        $currentNonInteractive = $Matches[3]
        Write-Host "Current Non-Interactive Heap: $currentNonInteractive KB" -ForegroundColor $(if ($currentNonInteractive -le 768) { "Red" } else { "Green" })
        Write-Host ""
    }
} catch {
    Write-Host "ERROR: Could not read current registry value" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# New value with increased heap (768 KB -> 4096 KB)
Write-Host "Applying Fix:" -ForegroundColor Yellow
Write-Host "  Changing Non-Interactive Heap: 768 KB -> 4096 KB" -ForegroundColor White
Write-Host ""

$heapLimits = "%SystemRoot%\system32\csrss.exe ObjectDirectory=\Windows SharedSection=1024,20480,4096 Windows=On SubSystemType=Windows ServerDll=basesrv,1 ServerDll=winsrv:UserServerDllInitialization,3 ServerDll=sxssrv,4 ProfileControl=Off MaxRequestThreads=16"

try {
    # Apply the fix
    Set-ItemProperty -Path $regPath -Name $regKey -Value $heapLimits -ErrorAction Stop
    Write-Host "Success: Registry value updated successfully" -ForegroundColor Green
    Write-Host ""
    
    # Verify the change
    $newValue = Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction Stop
    Write-Host "New Registry Value:" -ForegroundColor Yellow
    Write-Host $newValue.Windows
    Write-Host ""
    
    # Parse new SharedSection
    if ($newValue.Windows -match "SharedSection=(\d+),(\d+),(\d+)") {
        $newNonInteractive = $Matches[3]
        Write-Host "New Non-Interactive Heap: $newNonInteractive KB" -ForegroundColor Green
        Write-Host ""
        
        if ($newNonInteractive -eq 4096) {
            Write-Host "Success: Fix applied successfully!" -ForegroundColor Green
        } else {
            Write-Host "WARNING: Verification failed. Expected 4096 KB, got $newNonInteractive KB" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "ERROR: Failed to apply registry change" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host "=== Fix Application Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT: A system reboot is REQUIRED for this change to take effect!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Reboot the system" -ForegroundColor White
Write-Host "  2. Wait for system to come back online (~3-5 minutes)" -ForegroundColor White
Write-Host "  3. Verify Nomad service is running" -ForegroundColor White
Write-Host "  4. Re-run the heap stress test to validate the fix" -ForegroundColor White
