# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  rendered_template = templatefile(
    "${path.module}/templates/aws_autoscaler.nomad.tpl", {
      nomad_autoscaler_image = var.nomad_autoscaler_image
      client_asg_name        = aws_autoscaling_group.nomad_client.name
    })
}

resource "null_resource" "nomad_autoscaler_jobspec" {
  provisioner "local-exec" {
    command = "echo '${local.rendered_template}' > aws_autoscaler.nomad"
  }
}

  # Windows user data (only used for optional test instance outside cluster)
  data "template_file" "windows_user_data" {
    template = file("${path.module}/templates/user-data-windows.ps1")
  }
