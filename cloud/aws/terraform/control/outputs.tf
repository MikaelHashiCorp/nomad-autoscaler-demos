# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "ip_addresses" {
  value = <<CONFIGURATION

Server IPs:
${module.hashistack_cluster.server_addresses}


To connect, add your private key and SSH into any client or server with
`ssh ubuntu@PUBLIC_IP`. You can test the integrity of the cluster by running:

  $ consul members
  $ nomad server members
  $ nomad node status

The Nomad UI can be accessed at ${module.hashistack_cluster.nomad_addr}/ui
The Consul UI can be accessed at ${module.hashistack_cluster.consul_addr}/ui
The Vault UI can be accessed at ${module.hashistack_cluster.vault_addr}/ui
Grafana dashboard can be accessed at http://${module.hashistack_cluster.client_elb_dns}:3000/d/AQphTqmMk/demo?orgId=1&refresh=5s
Traefik can be accessed at http://${module.hashistack_cluster.client_elb_dns}:8081
Prometheus can be accessed at http://${module.hashistack_cluster.client_elb_dns}:9090
Webapp can be accessed at http://${module.hashistack_cluster.client_elb_dns}:80
Myapp can be accessed at http://${module.hashistack_cluster.client_elb_dns}:8080/myapp

CLI environment variables:
export NOMAD_CLIENT_DNS=http://${module.hashistack_cluster.client_elb_dns}
export CONSUL_HTTP_ADDR=${module.hashistack_cluster.consul_addr}
export NOMAD_ADDR=${module.hashistack_cluster.nomad_addr}
export VAULT_ADDR=${module.hashistack_cluster.vault_addr}

EBS Volume Info
- - - - - - - - 
${module.hashistack_cluster.ebs_volume}

CONFIGURATION
}
