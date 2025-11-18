<powershell>
# Verbose Windows user-data: install Chocolatey+OpenSSH, force sshd service, inject key, optional RDP.
# Template vars from Terraform: ${key_name} ${owner_name} ${owner_email}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$VerbosePreference = 'Continue'
$DebugPreference = 'Continue'

$logFile = 'C:\ProgramData\user-data.log'
if (!(Test-Path (Split-Path $logFile))) { New-Item -ItemType Directory -Force -Path (Split-Path $logFile) | Out-Null }
Start-Transcript -Path $logFile -Append -Force | Out-Null
function Log { param($m) Write-Host $m; Add-Content -Path $logFile -Value "$(Get-Date -Format o) $m" }

Log "[init] Starting Windows initialization for stack=${owner_name} key=${key_name}"
Start-Sleep -Seconds 15

# Acquire IMDSv2 token
$token = ''
try { $token = Invoke-RestMethod -Method PUT -Uri 'http://169.254.169.254/latest/api/token' -Headers @{ 'X-aws-ec2-metadata-token-ttl-seconds' = '300' } ; Log '[imds] Token acquired' } catch { Log "[imds][warn] Token failure: $($_.Exception.Message)" }

# Install Chocolatey (for reliable OpenSSH install) if choco missing
if (-not (Get-Command choco.exe -ErrorAction SilentlyContinue)) {
  try {
    Log '[choco] Installing chocolatey'
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  } catch { Log "[choco][error] Install failed: $($_.Exception.Message)" }
} else { Log '[choco] Already present' }

# Install OpenSSH via Chocolatey to ensure service + config
$sshInstalled = Get-Service -Name sshd -ErrorAction SilentlyContinue
if (-not $sshInstalled) {
  try {
    Log '[openssh] Installing via choco'
    choco install openssh -y --no-progress | Out-Null
  } catch { Log "[openssh][error] choco install failed: $($_.Exception.Message)" }
}

# Fallback: capability install if service still absent
if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
  try {
    Log '[openssh][fallback] Capability install attempt'
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Continue | Out-Null
  } catch { Log "[openssh][fallback][warn] Capability install failed: $($_.Exception.Message)" }
}

# Ensure host keys exist
try { & 'C:\Windows\System32\OpenSSH\ssh-keygen.exe' -A | Out-Null; Log '[openssh] Host keys ensured' } catch { Log "[openssh][warn] Host key gen failed: $($_.Exception.Message)" }

# Write full or fallback sshd_config
$sshdConfig = 'C:\ProgramData\ssh\sshd_config'
if (!(Test-Path (Split-Path $sshdConfig))) { New-Item -ItemType Directory -Force -Path (Split-Path $sshdConfig) | Out-Null }
try {
  if ('${windows_sshd_config}' -and '${windows_sshd_config}' -ne '') {
    Log '[openssh] Applying provided sshd_config content'
    $cfg = @"
${windows_sshd_config}
"@
    $cfg | Out-File -FilePath $sshdConfig -Encoding ascii -Force
  } elseif (!(Test-Path $sshdConfig)) {
    Log '[openssh] Applying fallback minimal sshd_config'
    @"\nPort 22\nSubsystem sftp sftp-server.exe\nAuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys\nHostKey __PROGRAMDATA__/ssh/ssh_host_rsa_key\nHostKey __PROGRAMDATA__/ssh/ssh_host_ecdsa_key\nHostKey __PROGRAMDATA__/ssh/ssh_host_ed25519_key\nPasswordAuthentication no\nPubkeyAuthentication yes\nLogLevel VERBOSE\n"@ | Out-File -FilePath $sshdConfig -Encoding ascii -Force
  } else {
    Log '[openssh] Existing sshd_config present; leaving unchanged'
  }
} catch { Log "[openssh][error] sshd_config write failed: $($_.Exception.Message)" }

# Register service manually if still missing
if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
  try {
    Log '[openssh] Registering sshd service manually'
    sc.exe create sshd binPath= "C:\Windows\System32\OpenSSH\sshd.exe -D" start= auto | Out-Null
  } catch { Log "[openssh][error] sc create failed: $($_.Exception.Message)" }
}

# Start service
try {
  Set-Service sshd -StartupType Automatic -ErrorAction SilentlyContinue
  Start-Service sshd -ErrorAction SilentlyContinue
  Log "[openssh] Service state: $((Get-Service sshd -ErrorAction SilentlyContinue).Status)"
} catch { Log "[openssh][error] start failed: $($_.Exception.Message)" }

# Firewall rules (SSH + optional RDP)
try { New-NetFirewallRule -Name 'OpenSSH' -DisplayName 'OpenSSH' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue | Out-Null; Log '[firewall] SSH rule applied' } catch {}
try { New-NetFirewallRule -Name 'RDP' -DisplayName 'RDP' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 3389 -ErrorAction SilentlyContinue | Out-Null; Log '[firewall] RDP rule applied' } catch {}

# Fetch public key from metadata
$pubKey = ''
if ($token) {
  try { $pubKey = Invoke-RestMethod -Method GET -Uri 'http://169.254.169.254/latest/meta-data/public-keys/0/openssh' -Headers @{ 'X-aws-ec2-metadata-token' = $token }; Log '[imds] Retrieved public key' } catch { Log "[imds][warn] No public key: $($_.Exception.Message)" }
} else { Log '[imds][warn] No token for key fetch' }

# Inject key
if ($pubKey) {
  $authKeysPath = 'C:\ProgramData\ssh\administrators_authorized_keys'
  if (!(Test-Path $authKeysPath)) { New-Item -ItemType Directory -Force -Path (Split-Path $authKeysPath) | Out-Null; New-Item -ItemType File -Force -Path $authKeysPath | Out-Null }
  if ((Get-Content -Path $authKeysPath -ErrorAction SilentlyContinue) -notcontains $pubKey) { Add-Content -Path $authKeysPath -Value $pubKey; Log '[openssh] Injected admin public key' } else { Log '[openssh] Key already present' }
  icacls $authKeysPath /inheritance:r | Out-Null; icacls $authKeysPath /grant 'SYSTEM:(F)' 'Administrators:(F)' | Out-Null
} else { Log '[openssh][warn] Skipping key injection (no key)' }

# Wait for port 22 to listen (up to 90s)
$listened = $false
for ($i=0; $i -lt 18 -and -not $listened; $i++) {
  try {
    $res = Test-NetConnection -ComputerName localhost -Port 22 -WarningAction SilentlyContinue
    if ($res.TcpTestSucceeded) { $listened = $true; Log '[openssh] Port 22 is listening'; break }
  } catch {}
  Start-Sleep -Seconds 5
}
if (-not $listened) { Log '[openssh][warn] Port 22 not listening after timeout' }

# Ensure SSM agent
if (Get-Service AmazonSSMAgent -ErrorAction SilentlyContinue) {
  Set-Service AmazonSSMAgent -StartupType Automatic
  Start-Service AmazonSSMAgent -ErrorAction SilentlyContinue
  Log "[ssm] Agent state: $((Get-Service AmazonSSMAgent).Status)"
} else { Log '[ssm][warn] AmazonSSMAgent missing' }

Log '[complete] Windows initialization finished'
Stop-Transcript | Out-Null
</powershell>