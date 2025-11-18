<powershell>
# Unified Windows Nomad/Consul CLIENT user-data
# - Installs Consul & Nomad (fallback if vars == "none")
# - Creates Windows services, opens firewall ports
# - Writes minimal client configs & waits for node registration
# - Logs to C:\ProgramData\user-data.log

$ErrorActionPreference = 'Stop'
$logFile = 'C:\ProgramData\user-data.log'
New-Item -ItemType Directory -Force -Path (Split-Path $logFile) | Out-Null
function Log { param([string]$M) $ts=(Get-Date).ToString('u'); "[$ts] CLIENT $M" | Tee-Object -FilePath $logFile -Append }
Log 'User-data (client) starting'

$retryJoinRaw = '${retry_join}'
$nodeClass    = '${node_class}'
$region       = '${region}'
$consulSource = '${consul_binary}'
$nomadSource  = '${nomad_binary}'

$fallbackConsul = '1.22.0'
$fallbackNomad  = '1.11.0'

New-Item -ItemType Directory -Force -Path 'C:\HashiCorp' | Out-Null

function Get-DownloadInfo {
  param([string]$Name,[string]$Source,[string]$FallbackVersion)
  if ([string]::IsNullOrWhiteSpace($Source) -or $Source -eq 'none') {
    $ver = $FallbackVersion
    return @{ Version=$ver; Url=('https://releases.hashicorp.com/{0}/{1}/{0}_{1}_windows_amd64.zip' -f $Name,$ver) }
  }
  if ($Source -match '^https?://') {
    $ver = ($Source -split '/') | Where-Object { $_ -match '^[0-9]' } | Select-Object -First 1
    if (-not $ver) { $ver = $FallbackVersion }
    return @{ Version=$ver; Url=$Source }
  }
  $ver = $Source
  return @{ Version=$ver; Url=('https://releases.hashicorp.com/{0}/{1}/{0}_{1}_windows_amd64.zip' -f $Name,$ver) }
}

function Install-ZipTool {
  param([string]$Name,[string]$Source,[string]$FallbackVersion)
  $exe = "C:\HashiCorp\$Name.exe"
  if (Test-Path $exe) { Log "$Name already present"; return }
  $info = Get-DownloadInfo -Name $Name -Source $Source -FallbackVersion $FallbackVersion
  $tmp = "$env:TEMP\$Name.zip"
  Log "Downloading $Name $($info.Version) from $($info.Url)"
  try {
    Invoke-WebRequest -Uri $info.Url -OutFile $tmp -UseBasicParsing -TimeoutSec 30
  } catch {
    Log "Download failed for $Name: $($_.Exception.Message)"; return
  }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tmp,'C:\HashiCorp',$true)
    Log "$Name extracted"
  } catch {
    Log "Extraction failed for $Name: $($_.Exception.Message)"
  }
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}

Install-ZipTool -Name consul -Source $consulSource -FallbackVersion $fallbackConsul
Install-ZipTool -Name nomad  -Source $nomadSource  -FallbackVersion $fallbackNomad

New-NetFirewallRule -DisplayName 'HashiStack-Client-Ports' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8500,8600,4646,4647,4648 -ErrorAction SilentlyContinue | Out-Null

# Config directories
New-Item -ItemType Directory -Force -Path 'C:\ProgramData\consul' | Out-Null
New-Item -ItemType Directory -Force -Path 'C:\ProgramData\nomad'  | Out-Null

# Consul client config
$consulConfig = @"
datacenter  = "dc1"
server      = false
data_dir    = "C:/ProgramData/consul"
client_addr = "0.0.0.0"
bind_addr   = "0.0.0.0"
retry_join  = ["$retryJoinRaw"]
"@
$consulConfig | Out-File -FilePath 'C:\ProgramData\consul\client.hcl' -Encoding UTF8 -Force
Log 'Consul client config written'

# Nomad client config
$nomadConfig = @"
datacenter = "dc1"
region     = "$region"
bind_addr  = "0.0.0.0"
data_dir   = "C:/ProgramData/nomad"
client {
  enabled    = true
  node_class = "$nodeClass"
}
consul {
  address = "127.0.0.1:8500"
}
"@
$nomadConfig | Out-File -FilePath 'C:\ProgramData\nomad\client.hcl' -Encoding UTF8 -Force
Log 'Nomad client config written'

# Create services
try { New-Service -Name Consul -BinaryPathName '"C:\HashiCorp\consul.exe" agent -config-file="C:\ProgramData\consul\client.hcl"' -StartupType Automatic -ErrorAction Stop | Out-Null; Log 'Consul service created' } catch { Log "Consul service create skipped: $($_.Exception.Message)" }
try { New-Service -Name Nomad  -BinaryPathName '"C:\HashiCorp\nomad.exe" agent -config="C:\ProgramData\nomad\client.hcl"' -StartupType Automatic -ErrorAction Stop | Out-Null; Log 'Nomad service created' } catch { Log "Nomad service create skipped: $($_.Exception.Message)" }

Start-Service Consul -ErrorAction Continue; Start-Sleep -Seconds 5; Start-Service Nomad -ErrorAction Continue
Log 'Service start attempts issued'
Get-Service Consul | ForEach-Object { Log "Consul state: $($_.Status)" }
Get-Service Nomad  | ForEach-Object { Log "Nomad state:  $($_.Status)" }

# Wait for nodes endpoint showing >0 content length
$timeout = 200
$begin   = Get-Date
Log "Waiting up to $timeout seconds for Nomad client registration"
while ((Get-Date) - $begin -lt (New-TimeSpan -Seconds $timeout)) {
  try {
    $r = Invoke-WebRequest -Uri 'http://127.0.0.1:4646/v1/nodes' -UseBasicParsing -TimeoutSec 3
    if ($r.StatusCode -eq 200 -and $r.Content.Length -gt 10) { Log 'Nomad nodes endpoint populated'; break }
  } catch {
    Get-Service Nomad | ForEach-Object { Log "Nomad poll state: $($_.Status)" }
  }
  Start-Sleep -Seconds 6
}
if ((Get-Date) - $begin -ge (New-TimeSpan -Seconds $timeout)) { Log 'Nomad client registration NOT detected'; Get-Service Nomad | ForEach-Object { Log "Final state: $($_.Status)" } }

Log 'User-data (client) complete'
</powershell>