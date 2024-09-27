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
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_block_device_size
    delete_on_termination = true
  }

  user_data            = local.user_data_server
  iam_instance_profile = aws_iam_instance_profile.nomad_server.name

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/${var.key_name}.pem")
    host        = self.public_ip
  }
}

# The locals below are used in the instance_provisioner_rerun
locals {
# priips-svr    = [for instance in aws_instance.nomad_server : instance.private_ip]
  promptids     = [for index in range(var.server_count) : "server-${index + 1}"]
  remote_exec_commands_instance = [
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
    "if ! grep -Fxq 'PS1=\"$PROMPTID)[Int:\"' ~/.bashrc ; then",
    "  echo 'export AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed \"s/.$//\")' >> ~/.bashrc",
    "  echo 'export INSTANCE_NAME=$(curl -s http://169.254.169.254/latest/meta-data/tags/instance/Name)' >> ~/.bashrc",
    "  echo 'export PROMPTID=$(curl -s http://169.254.169.254/latest/meta-data/tags/instance/PromptID)' >> ~/.bashrc",
    "  echo 'export PUBIP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)' >> ~/.bashrc",
    "  echo 'export PRIIP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)' >> ~/.bashrc",
    "  echo 'if [[ \\$TERM_PROGRAM == \"WarpTerminal\" ]]; then\n    PS1=\"\\[\\\\033[0;33m\\](\\$PROMPTID)[Int: \\$PRIIP / Ext: \\$PUBIP] \\[\\\\033[01;32m\\]\\u\\[\\\\033[00m\\]:\\[\\\\033[01;34m\\]\\w\\[\\\\033[00m\\]\\$ \"\nelse\n    PS1=\"\\[\\\\033[0;33m\\](\\$PROMPTID)[Int: \\$PRIIP / Ext: \\$PUBIP]\\[\\\\033[0m\\]\\n\\[\\\\033[01;32m\\]\\u\\[\\\\033[00m\\]:\\[\\\\033[01;34m\\]\\w\\[\\\\033[00m\\]\\$ \"\nfi' >> ~/.bashrc",
    "fi",
    "echo update triggered $(date)"  # Trigger an update."
  ]
  remote_exec_hash_instance = md5(join(",", local.remote_exec_commands_instance))
}

# This instance_provisioner_rerun allows updating the command lines to existing instances without
# destroying and recreating the instances.
resource "null_resource" "instance_provisioner_rerun" {
  triggers = {
    remote_exec_hash = local.remote_exec_hash_instance,
  }

  depends_on = [aws_instance.nomad_server]
  count      = var.server_count

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/${var.key_name}.pem")
    host        = element(aws_instance.nomad_server.*.public_ip, count.index)
  }

  provisioner "file" {
    source      = "${path.module}/templates/autosc-stage-IP.code-workspace"
    destination = "/home/ubuntu/autosc-stage-IP.code-workspace"
  }

  provisioner "remote-exec" {
    inline = concat(
      local.remote_exec_commands_instance,
      [
        "echo 'The value of PRIIP is:   ' ${aws_instance.nomad_server[count.index].private_ip}",
        "echo 'The value of PROMPTID is:' ${local.promptids[count.index]}",
        "sed -e \"s/{{HOST-IP}}/${aws_instance.nomad_server[count.index].private_ip}/g\" -e \"s/{{PROMPT-ID}}/${local.promptids[count.index]}/g\" /home/ubuntu/autosc-stage-IP.code-workspace > /home/ubuntu/autosc-stage-remote.code-workspace"
      ]
    )
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/licenses",
      "sudo mkdir -p /opt/acl",
      "sudo chmod 777 /opt/licenses",
      "sudo chmod 777 /opt/acl"
    ]
  }

  provisioner "file" {
    source      = "${path.module}/templates/licenses/"
    destination = "/opt/licenses"
  }

    provisioner "file" {
    source      = "${path.module}/templates/acl/"
    destination = "/opt/acl"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chown -R root:ubuntu /opt/licenses",
      "sudo chmod -R 775 /opt/licenses",
      "sudo chown -R root:ubuntu /opt/acl",
      "sudo chmod -R 775 /opt/acl",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "[ -f /opt/licenses/consul-hclic.hcl ] && sudo mv -f /opt/licenses/consul-hclic.hcl /etc/consul.d/consul-hclic.hcl || echo 'Consul file does not exist, skipping move'",
      "[ -f /opt/licenses/nomad-hclic.hcl ] && sudo mv -f /opt/licenses/nomad-hclic.hcl /etc/nomad.d/nomad-hclic.hcl || echo 'Nomad file does not exist, skipping move'",
      "# [ -f /opt/acl/consul-acl.hcl ] && sudo mv -f /opt/acl/consul-acl.hcl /home/ubuntu/consul-acl.hcl || echo 'Consul ACL file does not exist, skipping move'",
      "# [ -f /opt/acl/nomad-acl.hcl ] && sudo mv -f /opt/acl/nomad-acl.hcl /home/ubuntu/nomad-acl.hcl || echo 'Nomad ACL file does not exist, skipping move'",    
    ]
  }
}
