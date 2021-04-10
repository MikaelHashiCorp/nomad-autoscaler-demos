locals {
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "agents" {
  name_prefix = "${var.stack_name}-agents"
  vpc_id      = local.vpc_id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  # Nomad
  ingress {
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
    security_groups = [
      aws_security_group.servers_lb.id,
    ]
  }

  # Consul
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
    security_groups = [
      aws_security_group.servers_lb.id,
    ]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    OwnerName  = var.owner_name
    OwnerEmail = var.owner_email
  }
}

resource "aws_security_group" "services" {
  count = length(var.services)

  name_prefix = "${var.stack_name}-services-${count.index + 1}"
  vpc_id      = local.vpc_id

  dynamic "ingress" {
    for_each = var.services[count.index]
    content {
      protocol    = ingress.value["protocol"]
      from_port   = ingress.value["port"]
      to_port     = ingress.value["port"]
      cidr_blocks = var.allowed_ips
      security_groups = [
        aws_security_group.services_lb[count.index].id,
      ]
    }
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    OwnerName  = var.owner_name
    OwnerEmail = var.owner_email
  }
}

resource "aws_security_group" "servers_lb" {
  name_prefix = "${var.stack_name}-servers-lb"
  vpc_id      = local.vpc_id

  # Nomad
  ingress {
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  # Consul
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = var.allowed_ips
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    OwnerName  = var.owner_name
    OwnerEmail = var.owner_email
  }
}

resource "aws_security_group" "services_lb" {
  count = length(var.services)

  name_prefix = "${var.stack_name}-services-${count.index + 1}"
  vpc_id      = local.vpc_id

  dynamic "ingress" {
    for_each = var.services[count.index]
    content {
      protocol    = ingress.value["protocol"]
      from_port   = ingress.value["port"]
      to_port     = ingress.value["port"]
      cidr_blocks = var.allowed_ips
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    OwnerName  = var.owner_name
    OwnerEmail = var.owner_email
  }
}
