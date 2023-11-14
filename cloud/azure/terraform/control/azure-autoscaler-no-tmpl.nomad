job "azure-autoscaler-no-policy" {
  datacenters = ["dc2"]

  group "autoscaler" {
    count = 1

    network {
      port "http" {}
    }

    task "autoscaler-agent" {
      driver = "docker"

      config {
        image   = "hashicorp/nomad-autoscaler:0.3.7"
        command = "nomad-autoscaler"

        args = [
          "agent",
          "-config",
          "${NOMAD_TASK_DIR}/autoscaler-plugin.hcl",
          "-http-bind-address",
          "0.0.0.0",
          "-http-bind-port",
          "${NOMAD_PORT_http}",
          "-policy-dir",
          "${NOMAD_TASK_DIR}/policies/",
          "-log-level",
          "TRACE",
          "-enable-debug",
        ]

        ports = ["http"]
      }

      resources {
        cpu    = 50
        memory = 128
      }

      service {
        name = "autoscaler"
        port = "http"

        check {
          type     = "http"
          path     = "/v1/health"
          interval = "5s"
          timeout  = "2s"
        }
      }
    }
  }
}

