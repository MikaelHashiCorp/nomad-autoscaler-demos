job "alpine" {
  datacenters = ["dc1"]

  group "os" {
    network {
      port "db" {
        to = 6379
      }
    }

    task "redis" {
      driver = "docker"
      config {
        image = "redis"
        ports = ["db"]
      }
      resources {
        cpu    = 128
        memory = 64
      }
    }

    task "alpine" {
      driver = "docker"
      config {
        image = "alpine"
        command = "sh"
        args = ["-c","while true; do sleep 10; done"]
      }
      resources {
        cpu    = 128
        memory = 64
      }
    }

    task "busybox" {
      driver = "docker"
      config {
        image = "busybox"
        command = "sh"
        args = ["-c","while true; do sleep 10; done"]
      }
      resources {
        cpu    = 128
        memory = 64
      }
    }
  }
}
