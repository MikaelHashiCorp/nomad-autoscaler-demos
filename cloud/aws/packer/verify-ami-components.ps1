# Verification script for Windows AMI components
# This script checks for HashiStack binaries, Docker, and other installed components

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows AMI Component Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check HashiStack binaries
Write-Host "Checking HashiStack binaries in C:\HashiCorp\bin..." -ForegroundColor Yellow
$hashiBinPath = "C:\HashiCorp\bin"
if (Test-Path $hashiBinPath) {
    Write-Host "  [OK] Directory exists" -ForegroundColor Green
    
    $binaries = @("consul.exe", "nomad.exe", "vault.exe")
    foreach ($binary in $binaries) {
        $fullPath = Join-Path $hashiBinPath $binary
        if (Test-Path $fullPath) {
            Write-Host "  [OK] Found: $binary" -ForegroundColor Green
            # Get version
            $version = & $fullPath version 2>&1 | Select-Object -First 1
            Write-Host "       Version: $version" -ForegroundColor Gray
        } else {
            Write-Host "  [FAIL] Missing: $binary" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  [FAIL] Directory not found: $hashiBinPath" -ForegroundColor Red
}

Write-Host ""

# Check Docker
Write-Host "Checking Docker installation..." -ForegroundColor Yellow
$dockerPath = "C:\Program Files\Docker\docker.exe"
if (Test-Path $dockerPath) {
    Write-Host "  [OK] Docker binary found" -ForegroundColor Green
    
    # Check Docker service
    $dockerService = Get-Service -Name docker -ErrorAction SilentlyContinue
    if ($dockerService) {
        Write-Host "  [OK] Docker service exists" -ForegroundColor Green
        Write-Host "       Status: $($dockerService.Status)" -ForegroundColor Gray
        Write-Host "       StartType: $($dockerService.StartType)" -ForegroundColor Gray
        
        # Try to get Docker version
        try {
            $dockerVersion = & docker version --format '{{.Server.Version}}' 2>&1
            Write-Host "       Version: $dockerVersion" -ForegroundColor Gray
        } catch {
            Write-Host "       Could not get version (service may need to start)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [FAIL] Docker service not found" -ForegroundColor Red
    }
} else {
    Write-Host "  [FAIL] Docker binary not found" -ForegroundColor Red
}

Write-Host ""

# Check Windows Containers feature
Write-Host "Checking Windows Containers feature..." -ForegroundColor Yellow
$containersFeature = Get-WindowsFeature -Name Containers -ErrorAction SilentlyContinue
if ($containersFeature) {
    if ($containersFeature.Installed) {
        Write-Host "  [OK] Windows Containers feature is installed" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Windows Containers feature is not installed" -ForegroundColor Red
    }
} else {
    Write-Host "  [WARN] Could not check Windows Containers feature" -ForegroundColor Yellow
}

Write-Host ""

# Check PATH environment variable
Write-Host "Checking PATH environment variable..." -ForegroundColor Yellow
$systemPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($systemPath -like "*C:\HashiCorp\bin*") {
    Write-Host "  [OK] C:\HashiCorp\bin is in system PATH" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] C:\HashiCorp\bin is NOT in system PATH" -ForegroundColor Red
}

if ($systemPath -like "*C:\Program Files\Docker*") {
    Write-Host "  [OK] Docker is in system PATH" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Docker is NOT in system PATH" -ForegroundColor Red
}

Write-Host ""

# Check firewall rules
Write-Host "Checking firewall rules..." -ForegroundColor Yellow
$firewallRules = @(
    "Consul HTTP",
    "Nomad HTTP",
    "Vault API",
    "Nomad Dynamic Ports"
)

foreach ($ruleName in $firewallRules) {
    $rule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($rule) {
        Write-Host "  [OK] Found rule: $ruleName (Enabled: $($rule.Enabled))" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Rule not found: $ruleName" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Made with Bob
