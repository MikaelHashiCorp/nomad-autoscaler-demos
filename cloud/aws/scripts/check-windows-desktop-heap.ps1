# Check Windows Desktop Heap Settings
# This script checks the Desktop Heap configuration mentioned in KB article 1-KB-Nomad-Allocation-Failure.md

Write-Host "=== Windows Desktop Heap Configuration Check ===" -ForegroundColor Cyan
Write-Host ""

# Registry path for Desktop Heap settings
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems"
$regKey = "Windows"

Write-Host "Checking Registry Path: $regPath" -ForegroundColor Yellow
Write-Host "Registry Key: $regKey" -ForegroundColor Yellow
Write-Host ""

try {
    # Get the Windows SubSystem registry value
    $windowsValue = Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction Stop
    $windowsString = $windowsValue.Windows
    
    Write-Host "Full Registry Value:" -ForegroundColor Green
    Write-Host $windowsString
    Write-Host ""
    
    # Parse the SharedSection parameter
    if ($windowsString -match "SharedSection=(\d+),(\d+),(\d+)") {
        $sharedHeap = $Matches[1]
        $interactiveHeap = $Matches[2]
        $nonInteractiveHeap = $Matches[3]
        
        Write-Host "=== Desktop Heap Values ===" -ForegroundColor Cyan
        Write-Host "SharedSection Parameter: SharedSection=$sharedHeap,$interactiveHeap,$nonInteractiveHeap"
        Write-Host ""
        Write-Host "  1. Shared Heap (Common):               $sharedHeap KB" -ForegroundColor White
        Write-Host "  2. Interactive Heap (Logged-on users): $interactiveHeap KB" -ForegroundColor White
        Write-Host "  3. Non-Interactive Heap (Services):    $nonInteractiveHeap KB" -ForegroundColor $(if ($nonInteractiveHeap -lt 2048) { "Red" } else { "Green" })
        Write-Host ""
        
        # Provide analysis
        Write-Host "=== Analysis ===" -ForegroundColor Cyan
        if ($nonInteractiveHeap -le 768) {
            Write-Host "WARNING: Non-Interactive Heap is at DEFAULT LOW value ($nonInteractiveHeap KB)" -ForegroundColor Red
            Write-Host "This can cause Nomad allocation failures after ~20-25 allocations (Windows Server 2016)." -ForegroundColor Red
            Write-Host "Windows Server 2022 may handle more allocations but fix is still recommended." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Recommended: Increase to 4096 KB or higher" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "To fix, run:" -ForegroundColor Yellow
            Write-Host '  $heapLimits = "%SystemRoot%\system32\csrss.exe ObjectDirectory=\Windows SharedSection=1024,20480,4096 Windows On SubSystemType=Windows ServerDll=basesrv,1 ServerDll=winsrv:UserServerDllInitialization,3 ServerDll=sxssrv,4 ProfileControl=Off MaxRequestThreads=16"' -ForegroundColor White
            Write-Host '  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems" -Name "Windows" -Value $heapLimits' -ForegroundColor White
            Write-Host '  Restart-Computer' -ForegroundColor White
        } elseif ($nonInteractiveHeap -ge 4096) {
            Write-Host "GOOD: Non-Interactive Heap is set to $nonInteractiveHeap KB (recommended 4096+ KB)" -ForegroundColor Green
        } else {
            Write-Host "MODERATE: Non-Interactive Heap is $nonInteractiveHeap KB" -ForegroundColor Yellow
            Write-Host "This is better than default (768 KB) but consider increasing to 4096 KB for best stability." -ForegroundColor Yellow
        }
        
    } else {
        Write-Host "ERROR: Could not parse SharedSection parameter from registry value" -ForegroundColor Red
    }
    
} catch {
    Write-Host "ERROR: Failed to read registry key" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Additional System Information ===" -ForegroundColor Cyan

# Check Nomad service status
Write-Host ""
Write-Host "Nomad Service Status:" -ForegroundColor Yellow
try {
    $nomadService = Get-Service -Name "Nomad" -ErrorAction SilentlyContinue
    if ($nomadService) {
        Write-Host "  Status: $($nomadService.Status)" -ForegroundColor $(if ($nomadService.Status -eq "Running") { "Green" } else { "Red" })
        Write-Host "  StartType: $($nomadService.StartType)"
    } else {
        Write-Host "  Nomad service not found" -ForegroundColor Red
    }
} catch {
    Write-Host "  Could not query Nomad service: $($_.Exception.Message)" -ForegroundColor Red
}

# Check current Nomad allocations
Write-Host ""
Write-Host "Nomad Allocations on this node:" -ForegroundColor Yellow
try {
    # Try to get allocations via nomad node status
    $nodeName = $env:COMPUTERNAME
    $nomadPath = "C:\HashiCorp\bin\nomad.exe"
    
    if (Test-Path $nomadPath) {
        $allocCount = & $nomadPath node status -self -json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty Allocations | Measure-Object | Select-Object -ExpandProperty Count
        if ($allocCount) {
            Write-Host "  Current allocations: $allocCount" -ForegroundColor $(if ($allocCount -gt 20) { "Yellow" } else { "White" })
            if ($allocCount -gt 20) {
                Write-Host "  WARNING: Approaching desktop heap limit (~24 allocations)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  Could not determine allocation count" -ForegroundColor Gray
        }
    } else {
        Write-Host "  Nomad binary not found at $nomadPath" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Could not query Nomad allocations: $($_.Exception.Message)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Check Complete ===" -ForegroundColor Cyan
