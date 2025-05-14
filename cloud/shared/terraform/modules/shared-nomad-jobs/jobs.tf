# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "null_resource" "wait_for_nomad_api" {
  provisioner "local-exec" {
    command = <<EOT
      max_retries=30
      count=0
      while ! nomad server members > /dev/null 2>&1; do
        echo 'waiting for nomad api...'
        sleep 10
        count=$((count+1))
        if [ $count -ge $max_retries ]; then
          echo "Timeout waiting for Nomad API"
          exit 1
        fi
      done
    EOT
    environment = {
      NOMAD_ADDR = var.nomad_addr
    }
  }
}

data "local_file" "grafana_dashboard" {
  filename = "${path.module}/files/grafana_dashboard.json"
}

resource "nomad_job" "traefik" {
  depends_on = [null_resource.wait_for_nomad_api]
  jobspec    = file("${path.module}/files/traefik.nomad")
}

resource "nomad_job" "prometheus" {
  depends_on = [null_resource.wait_for_nomad_api]
  jobspec    = file("${path.module}/files/prometheus.nomad")
}

resource "nomad_job" "grafana" {
  depends_on = [null_resource.wait_for_nomad_api]
  jobspec = templatefile("${path.module}/files/grafana.nomad.tpl", {
    grafana_dashboard = data.local_file.grafana_dashboard.content
  })
}

resource "nomad_job" "webapp" {
  depends_on = [null_resource.wait_for_nomad_api]
  jobspec    = file("${path.module}/files/webapp.nomad")
}

resource "nomad_job" "myapp" {
  depends_on = [null_resource.wait_for_nomad_api]
  jobspec    = file("${path.module}/files/myapp.nomad")
}
