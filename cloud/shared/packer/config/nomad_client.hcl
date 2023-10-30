data_dir  = "/opt/nomad/data"
bind_addr = "0.0.0.0"
log_level = "TRACE"
log_file  = "/opt/nomad/logs/"
log_rotate_duration  = "24h"
log_rotate_max_files = 3

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}

client {
  enabled    = true
  node_class = "hashistack"

  options {
    "driver.raw_exec.enable"    = "1"
    "docker.privileged.enabled" = "true"
  }
}

vault {
  enabled = false
  address = "http://active.vault.service.consul:8200"
}
