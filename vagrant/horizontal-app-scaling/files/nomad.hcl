datacenter = "dc1"

data_dir = "/opt/nomad"

server {
  enabled          = true
  bootstrap_expect = 1
}

client {
  enabled = true

  host_volume "grafana" {
    path = "/opt/nomad-volumes/grafana"
  }

  host_volume "consul_lock" {
    path      = "/home/vagrant/nomad-autoscaler/jobs"
    read_only = false
  }
}

plugin "docker" {
  config {
    volumes {
      enabled = true
    }
  }
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}
