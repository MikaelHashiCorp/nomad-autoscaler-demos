# Test Windows Batch Job - Simple validation without health checks

job "windows-test-batch" {
  datacenters = ["dc1"]
  type        = "batch"

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "windows"
  }

  group "test" {
    count = 1

    task "powershell" {
      driver = "raw_exec"

      config {
        command = "powershell.exe"
        args    = ["-Command", "Write-Host 'Windows task executed successfully on node'; Get-Date; Start-Sleep -Seconds 30"]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}