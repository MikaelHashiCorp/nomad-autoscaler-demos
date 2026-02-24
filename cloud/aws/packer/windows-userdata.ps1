<powershell>
# Configure WinRM for Packer (HTTP on port 5985)
Write-Host "Configuring WinRM for Packer..."

# Enable WinRM
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Configure WinRM for HTTP
winrm quickconfig -quiet -force
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true -Force
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Ensure HTTP listener is enabled
winrm create winrm/config/Listener?Address=*+Transport=HTTP 2>$null
winrm set winrm/config/Service '@{AllowUnencrypted="true"}'
winrm set winrm/config/Service/Auth '@{Basic="true"}'

# Configure firewall for WinRM HTTP
New-NetFirewallRule -DisplayName "WinRM HTTP" -Direction Inbound -LocalPort 5985 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

# Restart WinRM
Restart-Service WinRM

Write-Host "WinRM HTTP configuration complete"
</powershell>

# Made with Bob
