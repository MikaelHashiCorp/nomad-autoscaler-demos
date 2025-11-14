# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "null_resource" "wait_for_nomad_api" {
  provisioner "local-exec" {
    command = <<-EOT
      bash -c '
        START=$(date +%s)
        TIMEOUT=$WAIT_TIMEOUT
        ATTEMPT=0
        echo "[wait_for_nomad_api] NOMAD_ADDR=$NOMAD_ADDR timeout=$WAIT_TIMEOUT"
        while true; do
          ATTEMPT=$((ATTEMPT+1))
          if nomad server members > /dev/null 2>&1; then
            ELAPSED=$(( $(date +%s) - START ))
            echo "[wait_for_nomad_API] Nomad API ready after $${ELAPSED}s (attempt $${ATTEMPT})"
            exit 0
          fi
          ELAPSED=$(( $(date +%s) - START ))
          if [ $ELAPSED -ge $TIMEOUT ]; then
            echo "[wait_for_nomad_api] ERROR: Timeout after $${ELAPSED}s waiting for Nomad API at $NOMAD_ADDR (limit $WAIT_TIMEOUT)"
            echo "[wait_for_nomad_api] Diagnostics: curl status/leader endpoint:";
            curl -s -m 5 $NOMAD_ADDR/v1/status/leader || echo "[wait_for_nomad_api] curl failed"
            echo "[wait_for_nomad_api] Diagnostics: attempting raw TCP connect:";
            HOST="$NOMAD_ADDR"
            HOST=$(echo "$HOST" | sed -E "s#^[a-zA-Z]+://##")
            HOST=$(echo "$HOST" | cut -d':' -f1)
            HOST=$(echo "$HOST" | cut -d'/' -f1)
            if (echo > /dev/tcp/$HOST/4646) >/dev/null 2>&1; then
              echo "[wait_for_nomad_api] TCP 4646 open"
            else
              echo "[wait_for_nomad_api] TCP 4646 closed"
            fi
            exit 1
          fi
          TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
          echo "[wait_for_nomad_api] $${TS} attempt=$${ATTEMPT} elapsed=$${ELAPSED}s waiting..."
          sleep 10
        done'
    EOT
    environment = {
      NOMAD_ADDR    = var.nomad_addr
      WAIT_TIMEOUT  = var.wait_timeout_seconds
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
