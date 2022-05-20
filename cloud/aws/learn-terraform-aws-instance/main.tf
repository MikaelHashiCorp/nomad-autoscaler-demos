terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_instance" "app_server" {
  ami                       = "ami-02bebb047a1163512"
  instance_type             = "t3.medium"
  key_name                  = "support_eng_dev-access-key-mikael"
  vpc_security_group_ids    = [aws_security_group.primary.id]

  tags = {
    Name = "ami-diagnosis-mikael-nomad"
  }
}

root_block_device {
    volume_type           = "gp2"
    volume_size           = 16
    delete_on_termination = "true"
}

resource "aws_security_group" "primary" {
  name   = var.stack_name
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["73.109.72.170/32", "97.113.151.211/32"]
  }

 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}