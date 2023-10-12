resource "aws_launch_template" "nomad_client" {
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
      Name           = "${var.stack_name}-client"
      ConsulAutoJoin = "auto-join"
      PromptID       = "client"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvdd"
    ebs {
      volume_type           = "gp2"
      volume_size           = "50"
      delete_on_termination = "true"
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
    host        = "${aws_instance.nomad_server.0.public_ip}"
  }
}

data "aws_instances" "all_instances" {
  instance_tags = {
    "aws:autoscaling:groupName" = "${var.stack_name}-nomad_client"
  }
}

# The locals below are used in the asg_provisioner_rerun
locals {
  remote_exec_commands = [
    "sudo apt-get update && sudo apt-get install -y ec2-instance-connect awscli",
    "sudo find /opt -type d -exec chmod g+s {} \\;",
    "sudo chown -R root:ubuntu /opt",
    "sudo chmod -R g+rX /opt"
  ]

  remote_exec_hash = md5(join(",", local.remote_exec_commands))
}

# This asg_provisioner_rerun allows updating the command lines to existing instances without
# destroying and recreating the instances.
resource "null_resource" "asg_provisioner_rerun" {
  triggers = {
    remote_exec_hash = local.remote_exec_hash
  }

  count = length(data.aws_instances.all_instances.ids)

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/${var.key_name}.pem")
    host        = element(data.aws_instances.all_instances.public_ips, count.index)
  }

  provisioner "remote-exec" {
    inline = local.remote_exec_commands
  }
}


resource "aws_autoscaling_group" "nomad_client" {
  name               = "${var.stack_name}-nomad_client"
  availability_zones = var.availability_zones
  desired_capacity   = var.client_count
  min_size           = 0
  max_size           = 20
  depends_on         = [aws_instance.nomad_server]
  load_balancers     = [aws_elb.nomad_client.name]

  launch_template {
    id      = aws_launch_template.nomad_client.id
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
    value               = "client"
    propagate_at_launch = true
  }
}