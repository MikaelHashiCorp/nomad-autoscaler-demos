job "2alloc" {
  datacenters = ["dc1"]

  group "alpine1" {
    task "alpine1" {
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
  }

  group "alpine2" {
    task "alpine2" {
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
  }

}
