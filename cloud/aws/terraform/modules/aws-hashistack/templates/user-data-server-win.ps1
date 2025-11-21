<powershell>
# Focused Windows SERVER user-data: enable OpenSSH key auth & basic logging
$ErrorActionPreference = 'Stop'
$tsFile = 'C:\ProgramData\ud-ssh-server.txt'
New-Item -ItemType File -Force -Path $tsFile -Value ((Get-Date).ToString('u')) | Out-Null
$logFile = 'C:\ProgramData\ssh-setup.log'
New-Item -ItemType Directory -Force -Path (Split-Path $logFile) | Out-Null
function Log { param([string]$M) "[$((Get-Date).ToString('u'))] $M" | Tee-Object -FilePath $logFile -Append }
Log 'User-data starting (OpenSSH setup)'

$pubKey = '${ssh_pub_key}'
if ([string]::IsNullOrWhiteSpace($pubKey)) {
	Log 'No ssh_pub_key provided; skipping key provisioning.'
} else {
	Log 'Public key provided; proceeding with OpenSSH configuration.'
}

# Ensure OpenSSH Server capability present
try {
	$cap = Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
	if ($cap.State -ne 'Installed') {
		Log 'Installing OpenSSH.Server capability'
		Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
	} else { Log 'OpenSSH.Server already installed' }
} catch { Log "OpenSSH capability check/install failed: $($_.Exception.Message)" }

# Start and configure sshd service
try {
	Set-Service -Name sshd -StartupType Automatic
	Start-Service sshd
	Log 'sshd service started'
} catch { Log "Failed starting sshd: $($_.Exception.Message)" }

# Harden sshd_config (disable password auth)
$cfgPath = 'C:\ProgramData\ssh\sshd_config'
if (Test-Path $cfgPath) {
	try {
		$cfg = Get-Content $cfgPath
		if ($cfg -notmatch 'PasswordAuthentication') { Add-Content -Path $cfgPath -Value 'PasswordAuthentication no' }
		if ($cfg -notmatch 'PubkeyAuthentication')   { Add-Content -Path $cfgPath -Value 'PubkeyAuthentication yes' }
		if ($cfg -notmatch 'PermitRootLogin')        { Add-Content -Path $cfgPath -Value 'PermitRootLogin prohibit-password' }
		Log 'sshd_config hardened'
		Restart-Service sshd -ErrorAction Continue
	} catch { Log "Failed updating sshd_config: $($_.Exception.Message)" }
} else { Log 'sshd_config not found yet (service may create later)' }

# Authorized keys setup
if (-not [string]::IsNullOrWhiteSpace($pubKey)) {
	try {
		$authDir = 'C:\ProgramData\ssh'
		New-Item -ItemType Directory -Force -Path $authDir | Out-Null
		$authFile = Join-Path $authDir 'administrators_authorized_keys'
		Set-Content -Path $authFile -Value $pubKey -Encoding UTF8
		# Fix permissions (required or sshd ignores file)
		icacls $authFile /inheritance:r | Out-Null
		icacls $authFile /grant SYSTEM:F /grant BUILTIN\Administrators:F | Out-Null
		Log 'Authorized key file written and permissions set'
		Restart-Service sshd -ErrorAction Continue
	} catch { Log "Failed setting authorized key: $($_.Exception.Message)" }
}

# Firewall rule for SSH
try {
	New-NetFirewallRule -DisplayName 'Allow-SSH-22' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22 -ErrorAction SilentlyContinue | Out-Null
	Log 'Firewall rule for port 22 ensured'
} catch { Log "Firewall rule creation failed: $($_.Exception.Message)" }

# Log listening status if available
try {
	$listening = netstat -an | Select-String ':22'
	if ($listening) { Log 'Port 22 appears in netstat output' } else { Log 'Port 22 not yet listening' }
} catch { Log 'netstat check failed' }

Log 'User-data complete'
</powershell>