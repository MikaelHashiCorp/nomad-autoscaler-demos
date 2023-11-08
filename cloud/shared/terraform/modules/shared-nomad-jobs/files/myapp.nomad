# http://3.90.33.105:8080/myapp
# http://52.207.195.75:8080/myapp
job "myapp" {
  datacenters = ["dc1"]
  type        = "service"  # Default = service

  # Force the Update Block to be considered.
  meta {
    run_uuid = "${uuidv4()}"
  }

  group "group-http" {
    count = 1

    update {
      max_parallel     = 1         # Default = 1
      canary           = 1         # Default = 0
      auto_promote     = true      # Default = false
      min_healthy_time = "5s"      # Default = 10s
      health_check     = "checks"  # Default = checks
      healthy_deadline = "5m"      # Default = 5m
      auto_revert      = false     # Default = false
    }

    network {
      port  "http"{
        to = -1
      }
    }

    service {
      name = "myapp-traefik-http"
      port = "http"

      check {
        type     = "http"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
        path     = "/"
      }

      # Beware of traefik.consulcatalog.connect=true, don't make that line in.
      # It breaks ConsulCatelog
      # https://doc.traefik.io/traefik/routing/providers/consul-catalog/#traefikconsulcatalogconnect
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.http.rule=Path(`/myapp`)",
        "traefik.http.routers.http.priority=100",
        # "traefik.consulcatalog.connect=true",  ## seems to be a culpret for 404
        # "traefik.consulcatalog.connect=false",
      ]
    }

    task "task-http-echo" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo:latest"
        ports = ["http"]
        args  = [
          "-listen", ":${NOMAD_PORT_http}",
          "-text", <<-EOF
          <html><head><style>
            table, th, td { border: 1px solid black; border-collapse: collapse; }
          </style></head>
          <body>
            <h1> Welcome to the http-echo Service. </h1>
            <hr><b> You are on ${NOMAD_IP_http}:${NOMAD_PORT_http} </b>
            <p></p>
            <code><table>
              <tr><td> attr.unique.hostname  </td><td> ${attr.unique.hostname}  </td></tr>
              <tr><td> attr.cpu.totalcompute </td><td> ${attr.cpu.totalcompute} </td></tr>
              <tr><td> nomad_memory_limit    </td><td> ${NOMAD_MEMORY_LIMIT}    </td></tr>
              <tr><td> nomad_cpu_limit       </td><td> ${NOMAD_CPU_LIMIT}       </td></tr>
              <tr><td> NOMAD_ALLOC_ID        </td><td> ${NOMAD_ALLOC_ID}        </td></tr> 
              <tr><td> NOMAD_TASK_NAME       </td><td> ${NOMAD_TASK_NAME}       </td></tr>     
            </table></code>
          </body></html>
          EOF
        ]
      }

      resources {
        memory = 64
        cpu = 50
      }
    }
  }
}
