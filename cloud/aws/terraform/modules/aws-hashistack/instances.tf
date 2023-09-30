resource "aws_instance" "nomad_server" {
  ami                    = var.ami
  instance_type          = var.server_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.primary.id]
  count                  = var.server_count

  tags = {
    Name           = "${var.stack_name}-server-${count.index + 1}"
    PromptID       = "server-${count.index + 1}"
    ConsulAutoJoin = "auto-join"
    OwnerName      = var.owner_name
    OwnerEmail     = var.owner_email
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size
    delete_on_termination = "true"
  }

  user_data            = data.template_file.user_data_server.rendered
  iam_instance_profile = aws_iam_instance_profile.nomad_server.name

    connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/${var.key_name}.pem")
    host        = "${aws_instance.nomad_server.0.public_ip}"
  }
}

# This instance_provisioner_rerun allows updating the command lines to existing instances without
# destroying and recreating the instances.
resource "null_resource" "instance_provisioner_rerun" {
  # The triggers will cause the provisioner to run every time you apply.
  triggers = {
    always_run = "${timestamp()}"
  }

  # Using count to iterate over each aws_instance.nomad_server resource
  count = var.server_count

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/${var.key_name}.pem")
    host        = aws_instance.nomad_server[count.index].public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "while pgrep -u root 'apt|dpkg' >/dev/null; do sleep 10; done",
      "sudo apt-get update",
      "sudo apt-get install -y ec2-instance-connect awscli",
      "sudo find /opt -type d -exec chmod g+s {} \\;",
      "sudo chown -R root:ubuntu /opt",
      "sudo chmod -R g+rX /opt"
    ]
  }
}
