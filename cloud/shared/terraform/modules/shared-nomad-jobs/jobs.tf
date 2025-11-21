# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "null_resource" "wait_for_nomad_api" {
  provisioner "local-exec" {
    command = <<EOT
bash -c '
START=$(date +%s)
TIMEOUT=300
if [ "$SKIP_NOMAD_WAIT" = "true" ]; then
  echo "[wait-for-nomad] Skip enabled (bootstrap debugging)."; exit 0;
fi
echo "[wait-for-nomad] Waiting up to $TIMEOUT seconds for Nomad API..."
while ! nomad server members > /dev/null 2>&1; do
  NOW=$(date +%s)
  ELAPSED=$((NOW-START))
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "[wait-for-nomad] Timeout after $ELAPSED seconds. Diagnostics:";
    echo " - Attempting curl to $NOMAD_ADDR/v1/status/leader";
    curl -s -m 2 $NOMAD_ADDR/v1/status/leader || echo "curl failed";
    echo " - Checking process list for nomad:";
    ps -eo pid,comm | grep -i nomad || echo "nomad process not found";
    echo " - Open port 4646 (expected Nomad HTTP):";
    (netstat -an 2>/dev/null | grep 4646) || echo "port 4646 not listening";
    echo "Likely causes: Nomad not started yet, provisioning script failure, or OS mismatch (e.g. Windows AMI with Linux user_data).";
    exit 1
  fi
  echo "[wait-for-nomad] Still waiting ($ELAPSED s)..."
  sleep 10
done
READY_AFTER=$(( $(date +%s)-START ))
echo "[wait-for-nomad] Nomad API ready after $READY_AFTER seconds."
'
EOT
    environment = {
      NOMAD_ADDR = var.nomad_addr
      SKIP_NOMAD_WAIT = var.skip_nomad_wait
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
