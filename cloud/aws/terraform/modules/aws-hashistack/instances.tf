# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "aws_instance" "nomad_server" {
  ami                    = var.ami
  instance_type          = var.server_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.primary.id]
  count                  = var.server_count

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
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }

  user_data = templatefile(
    "${path.module}/templates/user-data-server.sh", {
      server_count  = var.server_count
      region        = var.region
      retry_join    = var.retry_join
      consul_binary = var.consul_binary
      nomad_binary  = var.nomad_binary
    })

  iam_instance_profile = aws_iam_instance_profile.nomad_server.name
}

# Optional Windows Server 2022 test instance (not part of Nomad cluster)
data "aws_ami" "windows_public" {
  count       = var.enable_windows_test && var.windows_ami_override == "" ? 1 : 0
  owners      = ["801119661308"]
  most_recent = true
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_instance" "windows" {
  count         = var.enable_windows_test ? 1 : 0
  ami           = var.windows_ami_override != "" ? var.windows_ami_override : (var.packer_os == "Windows" ? var.ami : data.aws_ami.windows_public[0].id)
  instance_type = var.windows_instance_type
  key_name      = var.key_name
  subnet_id     = element(aws_subnet.public.*.id, 0)
  vpc_security_group_ids = [aws_security_group.default.id]
  iam_instance_profile   = aws_iam_instance_profile.nomad_client.name

  user_data = data.template_file.windows_user_data.rendered

  tags = {
    Name        = "${var.stack_name}-win"
    Stack       = var.stack_name
    Role        = "windows"
    OwnerName   = var.owner_name
    OwnerEmail  = var.owner_email
  }
}
