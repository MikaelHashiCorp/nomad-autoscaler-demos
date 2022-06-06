job "custom" {

  namespace   = "default"
  region      = "global"
  datacenters = ["dc1"]

  group "group" {

    constraint {
      attribute = "${attr.kernel.name}"
      value     = "linux"
      operator  = ""
    }

    task "base64Decode" {
      driver = "docker"

      config {
        image = "alpine:latest"
        command = "/bin/sh"
        # args = ["-c", "apk add bash curl jq; bash local/lock.bash"]
        # args = ["-c","apk add bash curl jq; while true; do sleep 10; done"]
        args    = [
          "-c",
          "cat local/file.out; while true; do sleep 30; done",
        ]
      }

      template {
        source      = "./script1.sh"
        destination = "local/lock.bash"
      }

      resources {
        cpu    = 128
        memory = 64
      }
    }
  }
}
