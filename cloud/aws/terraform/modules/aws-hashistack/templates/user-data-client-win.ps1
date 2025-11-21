<powershell>
# Minimal test user-data for Windows CLIENT
New-Item -ItemType File -Force -Path 'C:\ProgramData\ud-test-client.txt' -Value ((Get-Date).ToString('u')) | Out-Null
</powershell>