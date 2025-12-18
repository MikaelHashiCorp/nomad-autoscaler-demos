# Test script to validate the EC2Launch v2 configuration PowerShell syntax
Write-Host "Testing EC2Launch v2 configuration syntax..."

# Simulate the executeScript variable creation
$executeScript = "      - task: executeScript`n        inputs:`n          - frequency: always`n            type: powershell`n            runAs: admin"

Write-Host "executeScript variable created successfully:"
Write-Host $executeScript

# Test the regex replacement
$testConfig = @"
version: 1.0
tasks:
  - stage: boot
    tasks:
      - task: setHostName
  - stage: postReady
    tasks:
      - task: setWallpaper
"@

Write-Host "`nOriginal config:"
Write-Host $testConfig

if ($testConfig -notmatch 'executeScript') {
  $testConfig = $testConfig -replace '(- stage: postReady\s+tasks:)', "`$1`n$executeScript"
  Write-Host "`nModified config:"
  Write-Host $testConfig
} else {
  Write-Host "`nexecuteScript task already exists"
}

Write-Host "`nSyntax validation complete!"

# Made with Bob
