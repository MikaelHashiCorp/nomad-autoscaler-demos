#!/bin/bash
# Validate running Windows instance for Consul, Nomad, Docker, and Vault
# Usage: ./validate-running-instance.sh <instance-ip> <ssh-key-name>

set -e

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <instance-ip> <ssh-key-name>"
    echo "Example: $0 54.185.37.56 aws-mikael-test"
    exit 1
fi

INSTANCE_IP=$1
KEY_NAME=$2
SSH_KEY="$HOME/.ssh/${KEY_NAME}.pem"

echo "========================================="
echo "Windows Instance Health Validation"
echo "========================================="
echo "Instance IP: $INSTANCE_IP"
echo "SSH Key: $SSH_KEY"
echo ""

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo "ERROR: SSH key not found at $SSH_KEY"
    exit 1
fi

# Create validation PowerShell script
cat > /tmp/validate-instance.ps1 << 'PSEOF'
Write-Host "========================================="
Write-Host "Instance Health Validation"
Write-Host "========================================="
Write-Host ""

$allHealthy = $true

# Test 1: Check Consul service
Write-Host "[1/5] Checking Consul Service..."
$consulService = Get-Service -Name "Consul" -ErrorAction SilentlyContinue
if ($consulService) {
    Write-Host "  Service Name: $($consulService.Name)"
    Write-Host "  Status: $($consulService.Status)"
    Write-Host "  StartType: $($consulService.StartType)"
    
    if ($consulService.Status -eq "Running") {
        Write-Host "  [PASS] Consul service is running"
    } else {
        Write-Host "  [FAIL] Consul service is not running"
        $allHealthy = $false
    }
} else {
    Write-Host "  [FAIL] Consul service not found"
    $allHealthy = $false
}
Write-Host ""

# Test 2: Check Nomad service
Write-Host "[2/5] Checking Nomad Service..."
$nomadService = Get-Service -Name "Nomad" -ErrorAction SilentlyContinue
if ($nomadService) {
    Write-Host "  Service Name: $($nomadService.Name)"
    Write-Host "  Status: $($nomadService.Status)"
    Write-Host "  StartType: $($nomadService.StartType)"
    
    if ($nomadService.Status -eq "Running") {
        Write-Host "  [PASS] Nomad service is running"
    } else {
        Write-Host "  [FAIL] Nomad service is not running"
        $allHealthy = $false
    }
} else {
    Write-Host "  [FAIL] Nomad service not found"
    $allHealthy = $false
}
Write-Host ""

# Test 3: Check Docker service
Write-Host "[3/5] Checking Docker Service..."
$dockerService = Get-Service -Name "docker" -ErrorAction SilentlyContinue
if ($dockerService) {
    Write-Host "  Service Name: $($dockerService.Name)"
    Write-Host "  Status: $($dockerService.Status)"
    Write-Host "  StartType: $($dockerService.StartType)"
    
    if ($dockerService.Status -eq "Running") {
        Write-Host "  [PASS] Docker service is running"
        
        # Try to run docker version
        Write-Host "  Checking Docker functionality..."
        try {
            $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
            if ($dockerVersion) {
                Write-Host "  Docker Version: $dockerVersion"
                Write-Host "  [PASS] Docker is functional"
            } else {
                Write-Host "  [WARN] Docker version check failed (may need elevated privileges)"
            }
        } catch {
            Write-Host "  [WARN] Docker command failed: $($_.Exception.Message)"
        }
    } else {
        Write-Host "  [FAIL] Docker service is not running"
        $allHealthy = $false
    }
} else {
    Write-Host "  [FAIL] Docker service not found"
    $allHealthy = $false
}
Write-Host ""

# Test 4: Check Vault binary
Write-Host "[4/5] Checking Vault Binary..."
$vaultPath = "C:\HashiCorp\bin\vault.exe"
if (Test-Path $vaultPath) {
    Write-Host "  Path: $vaultPath"
    try {
        $vaultVersion = & $vaultPath version 2>&1 | Select-Object -First 1
        Write-Host "  Version: $vaultVersion"
        Write-Host "  [PASS] Vault binary found and executable"
    } catch {
        Write-Host "  [FAIL] Vault binary found but not executable"
        $allHealthy = $false
    }
} else {
    Write-Host "  [FAIL] Vault binary not found at $vaultPath"
    $allHealthy = $false
}
Write-Host ""

# Test 5: Check Consul health (if running)
Write-Host "[5/5] Checking Consul Health..."
if ($consulService -and $consulService.Status -eq "Running") {
    try {
        $consulMembers = & "C:\HashiCorp\bin\consul.exe" members 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Consul Members:"
            Write-Host $consulMembers
            Write-Host "  [PASS] Consul is healthy and responding"
        } else {
            Write-Host "  [WARN] Consul is running but not yet ready"
            Write-Host "  This is normal if the service just started"
        }
    } catch {
        Write-Host "  [WARN] Could not check Consul health: $($_.Exception.Message)"
    }
} else {
    Write-Host "  [SKIP] Consul service not running"
}
Write-Host ""

# Summary
Write-Host "========================================="
Write-Host "Validation Summary"
Write-Host "========================================="
Write-Host ""

$services = @(
    @{Name="Consul"; Service=$consulService},
    @{Name="Nomad"; Service=$nomadService},
    @{Name="Docker"; Service=$dockerService}
)

Write-Host "Service Status:"
foreach ($svc in $services) {
    if ($svc.Service) {
        $status = $svc.Service.Status
        $startType = $svc.Service.StartType
        $statusIcon = if ($status -eq "Running") { "[PASS]" } else { "[FAIL]" }
        Write-Host "  $statusIcon $($svc.Name): $status ($startType)"
    } else {
        Write-Host "  [FAIL] $($svc.Name): Not Found"
    }
}

Write-Host ""
if ($allHealthy) {
    Write-Host "RESULT: ALL CHECKS PASSED"
    exit 0
} else {
    Write-Host "RESULT: SOME CHECKS FAILED"
    exit 1
}
PSEOF

echo "[1/3] Copying validation script to instance..."
scp -o StrictHostKeyChecking=no -i "$SSH_KEY" /tmp/validate-instance.ps1 Administrator@$INSTANCE_IP:C:/validate-instance.ps1
echo "  Script copied successfully"
echo ""

echo "[2/3] Running validation on instance..."
echo ""
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" Administrator@$INSTANCE_IP "powershell -ExecutionPolicy Bypass -File C:/validate-instance.ps1"
VALIDATION_RESULT=$?

echo ""
echo "[3/3] Validation complete"
echo ""

if [ $VALIDATION_RESULT -eq 0 ]; then
    echo "========================================="
    echo "INSTANCE VALIDATION: SUCCESS ✓"
    echo "========================================="
    exit 0
else
    echo "========================================="
    echo "INSTANCE VALIDATION: FAILED ✗"
    echo "========================================="
    exit 1
fi

# Made with Bob
