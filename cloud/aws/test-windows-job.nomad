# Test Windows Job - Validates Windows node can run workloads

job "windows-test" {
  datacenters = ["dc1"]
  type        = "service"

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
        args    = ["-Command", "while($true) { Write-Host 'Windows task running on node'; Start-Sleep -Seconds 10 }"]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}