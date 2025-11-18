# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  # Ensure Windows root volume is large enough for the AMI snapshot (>=30GB)
  effective_root_volume_size = (var.packer_os == "Windows" && var.root_block_device_size < 30) ? 30 : var.root_block_device_size
  server_user_data = var.packer_os == "Windows" ? templatefile(
    "${path.module}/templates/user-data-server-win.ps1",
    {
      server_count  = var.server_count
      retry_join    = var.retry_join
      consul_binary = var.consul_binary
      nomad_binary  = var.nomad_binary
      region        = var.region
    }
  ) : templatefile(
    "${path.module}/templates/user-data-server.sh",
    {
      server_count  = var.server_count
      region        = var.region
      retry_join    = var.retry_join
      consul_binary = var.consul_binary
      nomad_binary  = var.nomad_binary
    }
  )
}

resource "aws_instance" "nomad_server" {
  ami                    = var.ami
  instance_type          = var.server_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.primary.id]
  count                  = var.server_count
  # Ensure instance is replaced so Windows user-data executes on first boot
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name           = "${var.stack_name}-server-${count.index + 1}"
    ConsulAutoJoin = "auto-join"
    OwnerName      = var.owner_name
    OwnerEmail     = var.owner_email
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = local.effective_root_volume_size
    delete_on_termination = "true"
  }

  user_data = local.server_user_data

  iam_instance_profile = aws_iam_instance_profile.nomad_server.name
}

