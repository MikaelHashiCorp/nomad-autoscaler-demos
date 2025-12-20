# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Check if the specified AMI exists using external data source
data "external" "ami_check" {
  count = var.ami_id != "" ? 1 : 0
  
  program = ["bash", "-c", <<-EOT
    if aws ec2 describe-images --image-ids ${var.ami_id} --region ${var.region} --owners self >/dev/null 2>&1; then
      echo '{"exists": "true"}'
    else
      echo '{"exists": "false"}'
    fi
  EOT
  ]
}

locals {
  # Check if we need to build an image:
  # - If no ami_id is provided (empty string), always build
  # - If ami_id is provided, check if it exists; if not, build
  ami_exists  = var.ami_id != "" && length(data.external.ami_check) > 0 && data.external.ami_check[0].result.exists == "true"
  build_image = var.ami_id == ""  # Simplified: if no AMI ID provided, build it
}

# Try to find existing AMI if ami_id is provided and it exists
data "aws_ami" "existing" {
  count = local.ami_exists ? 1 : 0

  owners      = ["self"]
  most_recent = true

  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
}

locals {
  # Select the appropriate image based on whether we built it or found an existing one
  # Use conditional references to avoid evaluating data sources that don't exist
  image_id    = local.build_image ? (length(data.aws_ami.built) > 0 ? data.aws_ami.built[0].id : "") : (length(data.aws_ami.existing) > 0 ? data.aws_ami.existing[0].id : "")
  
  # Get the snapshot ID for cleanup (only when building)
  built_snapshot_id = local.build_image && length(data.aws_ami.built) > 0 ? [for b in data.aws_ami.built[0].block_device_mappings : lookup(b.ebs, "snapshot_id", "")][0] : ""
  existing_snapshot_id = !local.build_image && length(data.aws_ami.existing) > 0 ? [for b in data.aws_ami.existing[0].block_device_mappings : lookup(b.ebs, "snapshot_id", "")][0] : ""
  snapshot_id = local.build_image ? local.built_snapshot_id : local.existing_snapshot_id
  
  # Get tags for outputs
  image_tags = local.build_image ? (length(data.aws_ami.built) > 0 ? data.aws_ami.built[0].tags : {}) : (length(data.aws_ami.existing) > 0 ? data.aws_ami.existing[0].tags : {})
}

# Step 1: Build the AMI with Packer (blocks until complete), then capture the AMI ID
resource "null_resource" "packer_build" {
  count = local.build_image ? 1 : 0

  provisioner "local-exec" {
    working_dir = "${path.root}/../../packer"
    command = <<EOF
source env-pkr-var.sh && \
  bash ./run-with-timestamps.sh \
    -only='${var.packer_os == "Windows" ? "windows" : "linux"}.amazon-ebs.hashistack' \
    -var 'created_name=${var.owner_name}' \
    -var 'created_email=${var.owner_email}' \
    -var 'region=${var.region}' \
    -var 'name_prefix=${var.stack_name}' \
    -var 'os=${var.packer_os}' \
    -var 'os_version=${var.packer_os_version}' \
    -var 'os_name=${var.packer_os_name}' \
    .
EOF
  }

  # After Packer completes, query for the AMI ID
  provisioner "local-exec" {
    working_dir = "${path.root}"
    command = <<EOF
aws ec2 describe-images \
  --region ${var.region} \
  --owners self \
  --filters "Name=name,Values=${var.stack_name}-*" "Name=tag:OS,Values=${var.packer_os}" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text > .built-ami-id
EOF
  }

  triggers = {
    # Force rebuild if any of these change
    stack_name = var.stack_name
    os = var.packer_os
    os_version = var.packer_os_version
  }
}

# Step 2: Get the AMI that was just built
data "aws_ami" "built" {
  depends_on = [null_resource.packer_build]
  count      = local.build_image ? 1 : 0

  owners      = ["self"]
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.stack_name}-*"]
  }

  filter {
    name   = "tag:OS"
    values = [var.packer_os]
  }
}

# Step 3: Create cleanup file AFTER AMI is found (breaks circular dependency)
resource "local_file" "cleanup" {
  depends_on = [data.aws_ami.built]
  count      = local.build_image && var.cleanup_ami_on_destroy ? 1 : 0

  content         = "${local.image_id},${local.snapshot_id},${var.region}"
  filename        = ".cleanup-${local.image_id}"
  file_permission = "0644"

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
aws ec2 deregister-image --image-id ${split(",", self.content)[0]} --region ${split(",", self.content)[2]} &&
aws ec2 delete-snapshot --snapshot-id ${split(",", self.content)[1]} --region ${split(",", self.content)[2]}
EOF
  }
}