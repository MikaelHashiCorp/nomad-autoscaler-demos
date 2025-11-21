# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Check if the specified AMI exists using external data source
data "external" "ami_check" {
  count = var.ami_id != "" && !var.public_ami ? 1 : 0

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
  # Determine if AMI exists:
  # public_ami true => assume exists (public image lookup handled separately)
  ami_exists  = var.ami_id != "" && (var.public_ami || (length(data.external.ami_check) > 0 && data.external.ami_check[0].result.exists == "true"))
  build_image = var.ami_id == "" || !local.ami_exists
}

# Try to find existing AMI if ami_id is provided and it exists
data "aws_ami" "existing" {
  count      = local.ami_exists && !var.public_ami ? 1 : 0
  owners     = ["self"]
  most_recent = true
  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
}

data "aws_ami" "existing_public" {
  count       = local.ami_exists && var.public_ami ? 1 : 0
  most_recent = true
  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
}

locals {
  # Select the appropriate image based on whether we built it or found an existing one
  image       = local.build_image ? data.aws_ami.built[0] : (var.public_ami ? data.aws_ami.existing_public[0] : data.aws_ami.existing[0])
  image_id    = local.image.id
  snapshot_id = [for b in local.image.block_device_mappings : lookup(b.ebs, "snapshot_id", "")][0]
}

# Step 1: Build the AMI with Packer (blocks until complete)
resource "null_resource" "packer_build" {
  count = local.build_image ? 1 : 0

  provisioner "local-exec" {
    working_dir = "${path.root}/../../packer"
    command = <<EOF
source env-pkr-var.sh && \
  packer build -force \
    ${var.packer_os == "Windows" ? "-only=amazon-ebs.win2022" : "-only=amazon-ebs.hashistack"} \
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
}

# Step 2: Find the AMI that was just built (depends on Packer completing)
data "aws_ami" "built" {
  depends_on = [null_resource.packer_build]
  count      = local.build_image ? 1 : 0

  owners      = ["self"]
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.stack_name}-*"]
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