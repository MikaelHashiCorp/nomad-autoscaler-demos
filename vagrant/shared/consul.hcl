# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

datacenter       = "dc1"
advertise_addr   = "127.0.0.1"
client_addr      = "0.0.0.0"
data_dir         = "/opt/consul"
server           = true
bootstrap_expect = 1
ui               = true

ports {
  grpc = 8502
}

connect {
  enabled = true
}

telemetry {
  prometheus_retention_time = "30s"
}
