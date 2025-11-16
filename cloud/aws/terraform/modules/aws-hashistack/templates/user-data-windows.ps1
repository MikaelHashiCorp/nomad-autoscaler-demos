<powershell>
# Windows user-data: install OpenSSH if missing, inject key, ensure SSM

$ErrorActionPreference = 'Stop'
Write-Host '[user-data] Starting Windows initialization'

# Short delay to allow networking / Windows capability servicing stack
Start-Sleep -Seconds 20

# Acquire IMDSv2 token
try {
  $token = Invoke-RestMethod -Method PUT -Uri 'http://169.254.169.254/latest/api/token' -Headers @{ 'X-aws-ec2-metadata-token-ttl-seconds' = '300' }
} catch {
  Write-Warning "Failed to get IMDSv2 token: $($_.Exception.Message)"
  $token = ''
}

# Install OpenSSH Server (retry if initial servicing busy)
if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
  Write-Host 'OpenSSH Server not found; attempting installation.'
  $attempts = 0
  while ($attempts -lt 4 -and -not (Get-Service sshd -ErrorAction SilentlyContinue)) {
    try {
      Write-Host "Attempt $attempts: Add-WindowsCapability OpenSSH.Server"
      Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    } catch {
      Write-Warning "OpenSSH install attempt $attempts failed: $($_.Exception.Message)"
      Start-Sleep -Seconds 15
    }
    $attempts++
  }
  if (Get-Service sshd -ErrorAction SilentlyContinue) {
    Write-Host 'OpenSSH Server installed.'
  } else {
    Write-Warning 'OpenSSH Server not installed; continuing without SSH.'
  }
}

if (Get-Service sshd -ErrorAction SilentlyContinue) {
  Set-Service -Name sshd -StartupType Automatic
  if ((Get-Service sshd).Status -ne 'Running') { Start-Service sshd }
  New-NetFirewallRule -Name 'OpenSSH' -DisplayName 'OpenSSH' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue | Out-Null
  Write-Host 'sshd service verified'
} else {
  Write-Host 'sshd not available; skip key injection'
}

# Fetch first public key (index 0) if present
$pubKey = ''
if ($token -ne '') {
  try {
    $pubKey = Invoke-RestMethod -Method GET -Uri 'http://169.254.169.254/latest/meta-data/public-keys/0/openssh' -Headers @{ 'X-aws-ec2-metadata-token' = $token }
  } catch {
    Write-Warning "No public key found via instance metadata: $($_.Exception.Message)"
  }
}

if (Get-Service sshd -ErrorAction SilentlyContinue) {
  $authKeysPath = 'C:\ProgramData\ssh\administrators_authorized_keys'
  if (!(Test-Path $authKeysPath)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $authKeysPath) | Out-Null
    New-Item -ItemType File -Force -Path $authKeysPath | Out-Null
  }
  if ($pubKey -ne '') {
    $existing = Get-Content -Path $authKeysPath -ErrorAction SilentlyContinue
    if ($existing -notcontains $pubKey) {
      Add-Content -Path $authKeysPath -Value $pubKey
      Write-Host 'Injected SSH public key into administrators_authorized_keys'
    } else {
      Write-Host 'Public key already present'
    }
  } else {
    Write-Host 'No public key to inject'
  }
  icacls $authKeysPath /inheritance:r | Out-Null
  icacls $authKeysPath /grant 'SYSTEM:(F)' 'Administrators:(F)' | Out-Null
}

# Ensure SSM agent running
if (Get-Service -Name AmazonSSMAgent -ErrorAction SilentlyContinue) {
  Set-Service -Name AmazonSSMAgent -StartupType Automatic
  if ((Get-Service AmazonSSMAgent).Status -ne 'Running') { Start-Service AmazonSSMAgent }
  Write-Host 'AmazonSSMAgent verified'
} else {
  Write-Warning 'AmazonSSMAgent not found'
}

Write-Host '[user-data] Windows initialization complete'
</powershell>