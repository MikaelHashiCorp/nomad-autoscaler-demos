variable "create_csi_resources" {
  description = "Flag to control whether CSI resources in this module should be created"
}

resource "aws_iam_role_policy" "mount_ebs_volumes" {
  count  = var.create_csi_resources ? 1 : 0
  name   = "mount-ebs-volumes"
  role   = aws_iam_role.nomad_client.id
  policy = data.aws_iam_policy_document.mount_ebs_volumes[count.index].json
}

data "aws_iam_policy_document" "mount_ebs_volumes" {
  count  = var.create_csi_resources ? 1 : 0
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:DescribeVolumes",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
    ]
    resources = ["*"]
  }
}

resource "aws_ebs_volume" "mysql" {
  count              = var.create_csi_resources ? 1 : 0
  availability_zone  = var.availability_zones[0]
  size               = 40

  tags = {
    Name           = "${var.stack_name}-mysql"
    OwnerName      = var.owner_name
    OwnerEmail     = var.owner_email
  }
}
