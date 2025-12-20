# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "id" {
  description = "The ID of the AMI to use for instances."
  value       = local.image_id
  # Explicit dependency ensures AMI is built before anything uses this output
  depends_on  = [
    data.aws_ami.built,
    data.aws_ami.existing,
    null_resource.packer_build
  ]
}

output "snapshot_id" {
  description = "The ID of the EBS snapshot associated with the AMI."
  value       = local.snapshot_id
  depends_on  = [
    data.aws_ami.built,
    data.aws_ami.existing,
    null_resource.packer_build
  ]
}

output "os" {
  description = "Operating system type from AMI tags."
  value       = lookup(local.image_tags, "OS", "Unknown")
}

output "os_version" {
  description = "Operating system version from AMI tags."
  value       = lookup(local.image_tags, "OS_Version", "Unknown")
}

output "ssh_user" {
  description = "SSH username based on OS type from AMI tags."
  value       = lookup(local.image_tags, "OS", "Unknown") == "Ubuntu" ? "ubuntu" : "ec2-user"
}