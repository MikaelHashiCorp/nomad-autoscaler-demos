resource "aws_launch_template" "nomad_client" {
  count                  = var.client_count
  name_prefix            = "nomad-client"
  image_id               = var.ami
  instance_type          = var.client_instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.primary.id]
  user_data              = base64encode(data.template_file.user_data_client.rendered)

  iam_instance_profile {
    name = aws_iam_instance_profile.nomad_client.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name           = "${var.stack_name}-client-${local.client_numbers[count.index]}"
      ConsulAutoJoin = "auto-join"
      PromptID       = "client-${local.client_numbers[count.index]}"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  dynamic "block_device_mappings" {
    for_each = var.create_ebs_resources ? [1] : []
    content {
      device_name = "/dev/xvdd"
      ebs {
        volume_type           = "gp2"
        volume_size           = "50"
        delete_on_termination = "true"
      }
    }
  }
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_type           = "gp2"
      volume_size           = "16"
      delete_on_termination = "true"
    }
  }


  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/${var.key_name}.pem")
    host        = "${aws_instance.nomad_client.0.public_ip}"
  }
}

data "aws_instances" "all_instances" {
  depends_on = [aws_autoscaling_group.nomad_client]
  instance_tags = {
    "aws:autoscaling:groupName" = "${var.stack_name}-nomad_client"
  }
}


# The locals below are used in the asg_provisioner_rerun
locals {
  max_size             = 20
  client_numbers       = range(1, local.max_size + 1)
  remote_exec_commands = [
    "set -e",
    "while pgrep -u root 'apt|dpkg' >/dev/null; do sleep 10; done",
    "sudo apt-get update",
    "sudo apt-get install -y ec2-instance-connect awscli net-tools",
    "sudo find /opt -type d -exec chmod g+s {} \\;",
    "sudo chown -R root:ubuntu /opt",
    "sudo chmod -R g+rX /opt",
    "cat <<EOL >> ~/.bashrc",
      "alias env=\"env -0 | sort -z | tr '\\0' '\\n'\"",
    "EOL",
    "if ! grep -Fxq 'PS1=\"($PROMPTID)[Int:\"' ~/.bashrc ; then",
    "  echo 'export AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed \"s/.$//\")' >> ~/.bashrc",
    "  echo 'export INSTANCE_NAME=$(curl -s http://169.254.169.254/latest/meta-data/tags/instance/Name)' >> ~/.bashrc",
    "  echo 'export PROMPTID=$(curl -s http://169.254.169.254/latest/meta-data/tags/instance/PromptID)' >> ~/.bashrc",
    "  echo 'export PUBIP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)' >> ~/.bashrc",
    "  echo 'export PRIIP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)' >> ~/.bashrc",
    "  echo 'PS1=\"\\[\\\\033[0;33m\\](\\$PROMPTID)[Int: \\$PRIIP / Ext: \\$PUBIP]\\[\\\\033[0m\\]\\\\n$PS1\"' >> ~/.bashrc",
    "fi"
  ]

  remote_exec_hash = md5(join(",", local.remote_exec_commands))
}

# This asg_provisioner_rerun allows updating the command lines to existing instances without
# destroying and recreating the instances.
resource "null_resource" "asg_provisioner_rerun" {
  count = var.client_count

  triggers = {
    remote_exec_hash = local.remote_exec_hash
    promptid         = "client-${local.client_numbers[count.index]}"
  }

connection {
  type        = "ssh"
  user        = "ubuntu"
  private_key = file("~/.ssh/${var.key_name}.pem")
  host        = element(data.aws_instances.all_instances.public_ips, count.index)
}

  provisioner "file" {
    source      = "${path.module}/templates/autosc-stage-IP.code-workspace"
    destination = "/home/ubuntu/autosc-stage-IP.code-workspace"
  }
  provisioner "remote-exec" {
    inline = concat(
    local.remote_exec_commands,
    [
      "echo 'The value of PRIIP is:   ' ${element(data.aws_instances.all_instances.private_ips, count.index)}",
      "echo 'The value of PROMPTID is:' ${self.triggers["promptid"]}",
      "sed -e \"s/{{HOST-IP}}/${element(data.aws_instances.all_instances.private_ips, count.index)}/g\" -e \"s/{{PROMPT-ID}}/${self.triggers["promptid"]}/g\" /home/ubuntu/autosc-stage-IP.code-workspace > /home/ubuntu/autosc-stage-remote.code-workspace"
      ]
    )
  }
}

resource "aws_autoscaling_group" "nomad_client" {
  count              = var.client_count > 0 ? 1 : 0 # Ensure that this evaluates to 1
  name               = "${var.stack_name}-nomad_client"
  availability_zones = var.availability_zones
  desired_capacity   = var.client_count
  min_size           = 1             # Ensure that this is at least 1
  max_size           = local.max_size
  depends_on         = [aws_instance.nomad_server]
  load_balancers     = [aws_elb.nomad_client.name]

  launch_template {
    id      = aws_launch_template.nomad_client[0].id
    version = "$Latest"
  }

  tag {
    key                 = "OwnerName"
    value               = var.owner_name
    propagate_at_launch = true
  }
  tag {
    key                 = "OwnerEmail"
    value               = var.owner_email
    propagate_at_launch = true
  }
  tag {
    key                 = "PromptID"
    value               = "client-${count.index + 1}"
    propagate_at_launch = true
  }
}