<powershell>
# Configure WinRM for Packer
Write-Host "Configuring WinRM for Packer..."

# Set up WinRM with self-signed certificate
$cert = New-SelfSignedCertificate -DnsName "packer" -CertStoreLocation "cert:\LocalMachine\My"
$thumbprint = $cert.Thumbprint

# Create HTTPS listener
winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"packer`"; CertificateThumbprint=`"$thumbprint`"}"

# Configure WinRM service
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="false"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'

# Open firewall for WinRM
netsh advfirewall firewall add rule name="WinRM HTTPS" dir=in action=allow protocol=TCP localport=5986

# Restart WinRM service
Restart-Service -Name WinRM

Write-Host "WinRM configuration completed."
</powershell>
