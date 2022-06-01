job "left" {

  namespace   = "default"
  region      = "global"
  datacenters = ["dc1"]

  group "group" {

    constraint {
      attribute = "${attr.kernel.name}"
      value     = "linux"
      operator  = ""
    }

    volume "consul_lock" {
      type      = host
      read_only = false
      source    = "consul_lock"
    }
    
    network {
      mode = "bridge"

      port "port" {
        to = 8001
      }
    }

    service {
      port = "port"
    }

    task "block_for_lock" {
      driver = "docker"

      volume_mount {
        volume      = "consul_lock"
        destination = "/tmp"
        read_only   = false
      }

      lifecycle {
        hook = "prestart"
        sidecar = true
      }

      env {
        CONSUL_ADDR = "${attr.unique.network.ip-address}:8500"
        LEADER_KEY = "alpine:latest"
      }

      config {
        image = "alpine:latest"
        command = "/bin/sh"
        args = ["-c", "apk add bash curl jq; bash local/lock.bash"]
      }

      # artifact {
      #   source      = "/tmp/script.sh"
      #   # destination = "local/script.sh"
      #   destination = "local/lock.bash"
      # }
      
      template {
        # source      = "${NOMAD_TASK_DIR}/templates/script.sh"
        source      = "/tmp/script.sh"
        destination = "local/lock.bash"
      }

      resources {
        cpu    = 128
        memory = 64
      }
    }

    task "main" {
      driver = "docker"
      config {
        image = "busybox:1"
        command = "/bin/sh"
        args    = ["local/wait.sh"]
        ports   = ["port"]
      }

      resources {
        cpu    = 500
        memory = 256
      }

      template {
        data = <<EOT
while :
do
  [ -d "${NOMAD_ALLOC_DIR}/${NOMAD_ALLOC_ID}.lock" ] && break
  sleep 1
done

# the directory exists so we have the lock and can exec into the
# main application
exec httpd -v -f -p 8001 -h /local

EOT
        destination = "local/wait.sh"
      }

      template {
        data        = "<html>hello from {{ env \"NOMAD_ALLOC_ID\" }}</html>"
        destination = "local/index.html"
      }


    }
  }
}
