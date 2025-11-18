# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  cluster_output = <<EOT
AMI Information:
  ID:         ${module.hashistack_image.id}
  OS:         ${module.hashistack_image.os} ${module.hashistack_image.os_version}
  SSH User:   ${module.hashistack_image.ssh_user}

Server IPs:
${module.hashistack_cluster.server_addresses}

To connect, add your private key and SSH into any client or server with
`ssh ${module.hashistack_image.ssh_user}@PUBLIC_IP`. Validate cluster:
  consul members
  nomad server members
  nomad node status

Nomad UI:    ${module.hashistack_cluster.nomad_addr}/ui
Consul UI:   ${module.hashistack_cluster.consul_addr}/ui
Grafana:     http://${module.hashistack_cluster.client_elb_dns}:3000/d/AQphTqmMk/demo?orgId=1&refresh=5s
Traefik:     http://${module.hashistack_cluster.client_elb_dns}:8081
Prometheus:  http://${module.hashistack_cluster.client_elb_dns}:9090
Webapp:      http://${module.hashistack_cluster.client_elb_dns}:80

CLI environment variables:
export NOMAD_CLIENT_DNS=http://${module.hashistack_cluster.client_elb_dns}
export NOMAD_ADDR=${module.hashistack_cluster.nomad_addr}
EOT
}

output "ip_addresses" {
  value = local.cluster_output
}
