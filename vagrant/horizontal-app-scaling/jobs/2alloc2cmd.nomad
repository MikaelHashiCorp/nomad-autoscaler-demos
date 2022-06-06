job "2alloc2cmd" {
  datacenters = ["dc1"]
  type = "service"

  group "sleep" {
    task "sleep" {
      driver = "docker"
      config {
        image = "alpine"
        command = "/bin/sh"
        args = ["-c","while true; do sleep 10; done"]
      }
      resources {
        cpu    = 128
        memory = 64
      }
    }
  }

  group "apk" {
    task "apk" {
      driver = "docker"
      config {
        image = "alpine"
        command = "/bin/sh"
        args = ["-c","apk add bash curl jq; while true; do sleep 10; done"]
      }
      resources {
        cpu    = 128
        memory = 64
      }
    }
  }

}
