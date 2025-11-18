resource "aws_ssm_document" "port22_check" {
  name          = "${var.stack_name}-port22-check"
  document_type = "Command"
  target_type   = "/AWS::EC2::Instance"

  content = <<DOC
{
  "schemaVersion": "2.2",
  "description": "Validate sshd service and port 22 availability on Windows test instance",
  "parameters": {},
  "mainSteps": [
    {
      "action": "aws:runPowerShellScript",
      "name": "checkPort22",
      "inputs": {
        "runCommand": [
          "Start-Transcript -Path C:\\ProgramData\\Port22Check.log -Append",
          "Write-Host '[Port22Check] Checking sshd service status'",
          "Get-Service sshd -ErrorAction SilentlyContinue | Format-List",
          "Write-Host '[Port22Check] Listing listeners on port 22'",
          "netstat -an | findstr ':22'",
          "Write-Host '[Port22Check] Test-NetConnection localhost:22'",
          "Test-NetConnection -ComputerName localhost -Port 22",
          "Write-Host '[Port22Check] Capturing process details if listening'",
          "$p = Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue; if ($p) { Get-Process -Id $p.OwningProcess | Format-List }",
          "Stop-Transcript"
        ]
      }
    }
  ]
}
DOC
}

# Association targets any instance tagged Role=windows (only the test instance in this demo)
resource "aws_ssm_association" "port22_check" {
  name = aws_ssm_document.port22_check.name

  targets {
    key    = "Tag:Role"
    values = ["windows"]
  }

  # Run once shortly after boot then every 30 minutes (minimum allowed for rate expressions)
  schedule_expression   = "rate(30 minutes)"
  compliance_severity   = "LOW"
  max_concurrency       = "1"
  max_errors            = "1"
  apply_only_at_cron_interval = false
}
