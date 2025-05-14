# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  user_data_server = templatefile("${path.module}/templates/user-data-server.sh", {
    server_count  = var.server_count
    region        = var.region
    retry_join    = var.retry_join
    consul_binary = var.consul_binary
    nomad_binary  = var.nomad_binary
  })

  user_data_client = templatefile("${path.module}/templates/user-data-client.sh", {
    region        = var.region
    retry_join    = var.retry_join
    consul_binary = var.consul_binary
    nomad_binary  = var.nomad_binary
    node_class    = "hashistack"
  })

  nomad_autoscaler_jobspec = templatefile("${path.module}/templates/aws_autoscaler.nomad.tpl", {
    nomad_autoscaler_image = var.nomad_autoscaler_image
    client_asg_name        = aws_autoscaling_group.nomad_client.name
  })
}

resource "null_resource" "nomad_autoscaler_jobspec" {
  provisioner "local-exec" {
    command = "echo '${local.nomad_autoscaler_jobspec}' > aws_autoscaler.nomad"
  }
}
