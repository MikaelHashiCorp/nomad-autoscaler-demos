job "[[ .my.job_name ]]" {
  [[ template "location" . ]]
  group "group" {
    [[ template "constraints" . ]]

    network {
      mode = "bridge"
      port "port" {
        to = [[ .my.application_port ]]
      }
    }

    service {
      port = "www"
    }

    task "block_for_lock" {
      driver = "docker"

      lifecycle {
        hook = "prestart"
        sidecar = true
      }

      config {
        image = "[[ .my.locker_image ]]"
        command = "/bin/sh"
        args = ["-c", "local/lock.sh"]
      }

      template {
        data = <<EOT
[[ fileContents .my.locker_script_path ]]
EOT
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
        image = "[[ .my.application_image ]]"
        command = "/bin/bash"
        args    = ["-c", "/local/wait.bash"]
        ports   = ["port"]
      }

      [[ template "resources" . ]]

      template {
        data = <<EOT
while :
do
  [ -d ${NOMAD_ALLOC_DIR}/${NOMAD_ALLOC_ID}.lock" ] && break
  sleep 1
done

# the directory exists so we have the lock and can exec into the
# main application
exec [[ .my.application_args ]]

EOT
        destination = "local/wait.bash"
      }

      template {
        data        = "<html>hello from {{ env NOMAD_ALLOC_ID }}</html>"
        destination = "local/index.html"
      }


    }
  }
}
