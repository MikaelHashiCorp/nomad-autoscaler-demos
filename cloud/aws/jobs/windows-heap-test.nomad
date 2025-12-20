// Nomad Job to Replicate Desktop Heap Exhaustion on Windows
// Based on KB: 1-KB-Nomad-Allocation-Failure.md
//
// This job spawns multiple allocations to exhaust the desktop heap
// on Windows systems with default settings (768KB non-interactive heap).
// Expected behavior: After ~20-25 allocations, new allocations will fail
// with "Reattachment process not found" and "Insufficient system resources" errors.

job "windows-heap-test" {
  datacenters = ["dc1"]
  type        = "service"

  // Target Windows clients only
  constraint {
    attribute = "${attr.kernel.name}"
    value     = "windows"
  }

  // Alternative constraint using node class
  constraint {
    attribute = "${node.class}"
    value     = "hashistack-windows"
  }

  // Start with many allocations to stress the desktop heap
  group "heap-stress" {
    // Increased to 80 allocations to stress test desktop heap on Windows 2022
    count = 80

    // Disable rescheduling to see the failure pattern clearly
    reschedule {
      attempts  = 0
      unlimited = false
    }

    // Allow failures for testing
    update {
      max_parallel     = 5
      health_check     = "task_states"
      min_healthy_time = "10s"
      healthy_deadline = "2m"
    }

    task "stress-task" {
      driver = "raw_exec"

      config {
        // Simple PowerShell command that runs continuously
        command = "powershell.exe"
        args = [
          "-NoProfile",
          "-NonInteractive",
          "-Command",
          "while ($true) { Write-Host 'Running allocation ${NOMAD_ALLOC_INDEX}'; Start-Sleep -Seconds 30 }"
        ]
      }

      resources {
        cpu    = 100  // Low CPU to allow many allocations
        memory = 128  // Low memory to allow many allocations
      }

      // Log configuration
      logs {
        max_files     = 2
        max_file_size = 10
      }
    }
  }
}
