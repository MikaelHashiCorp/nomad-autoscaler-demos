# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "server_tag_name" {
  value = aws_instance.nomad_server.*.tags.Name
}

output "server_public_ips" {
  value = aws_instance.nomad_server.*.public_ip
}

output "server_private_ips" {
  value = aws_instance.nomad_server.*.private_ip
}

output "server_addresses" {
  value = join("\n", formatlist(" * instance %v - Public: %v, Private: %v", aws_instance.nomad_server.*.tags.Name, aws_instance.nomad_server.*.public_ip, aws_instance.nomad_server.*.private_ip))
}

output "server_elb_dns" {
  value = aws_elb.nomad_server.dns_name
}

output "server_elb_dns_zone_id" {
  value = aws_elb.nomad_server.zone_id
}

output "client_elb_dns" {
  value = aws_elb.nomad_client.dns_name
}

output "client_elb_dns_zone_id" {
  value = aws_elb.nomad_client.zone_id
}

output "nomad_addr" {
  value = "http://${aws_elb.nomad_server.dns_name}:4646"
}

output "consul_addr" {
  value = "http://${aws_elb.nomad_server.dns_name}:8500"
}

output "vault_addr" {
  value = "http://${aws_elb.nomad_server.dns_name}:8200"
}

output "hosts_file" {
  value = join("\n", concat(
    formatlist(" %-16s  %v.hs", aws_instance.nomad_server.*.public_ip, aws_instance.nomad_server.*.tags.Name)
  ))
}

output "client_asg_arn" {
  value = aws_autoscaling_group.nomad_client.arn
}

output "client_asg_name" {
  value = aws_autoscaling_group.nomad_client.name
}

output "ssh_file" {
  value = join("\n", concat(
    formatlist("Host %v.hs\n  User ubuntu\n  HostName %v\n", aws_instance.nomad_server.*.tags.Name, aws_instance.nomad_server.*.public_dns)
  ))
}

locals {
  ebs_volume_value = length(aws_ebs_volume.mysql) > 0 ? format(
    "# volume registration\n    type        = \"csi\"\n    id          = \"mysql\"\n    name        = \"mysql\"\n    external_id = \"%s\"\n    plugin_id   = \"aws-ebs0\"\n\n    capability {\n      access_mode     = \"single-node-writer\"\n      attachment_mode = \"file-system\"\n    }\n",
    aws_ebs_volume.mysql[0].id
  ) : ""
}

output "ebs_volume" {
  value = local.ebs_volume_value
}
