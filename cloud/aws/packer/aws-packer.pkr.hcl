variable "created_email" { default = "mikael.sikora@hashicorp.com" }
variable "created_name"  { default = "mikael_sikora"}
variable "region"        { default = "us-east-1" }

source "amazon-ebs" "hashistack" {
  temporary_key_pair_type = "ed25519"
  ami_name      = "autosc-mws {{timestamp}}"
  region        = var.region
  instance_type = "t3a.medium"

  source_ami_filter {
    filters = {
      virtualization-type = "hvm"
      name                = "ubuntu/images/*ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
    }
    owners      = ["099720109477"] # Canonical's owner ID
    most_recent = true
  }

  communicator = "ssh"
  ssh_username = "ubuntu"

  tags = {
    OS_Version    = "Ubuntu"
    Release       = "20.04"
    Architecture  = "amd64"
    Created_Email = var.created_email
    Created_Name  = var.created_name
  }
}

build {
  sources = [
    "source.amazon-ebs.hashistack"
  ]

  provisioner "shell" {
    valid_exit_codes = [  ## Redefine exit codes.  https://stackoverflow.com/questions/70719041/packer-errors-on-attempt-to-run-a-script
      "0",
      "1",
      "2"
    ]
    inline = [
      "echo set debconf to Noninteractive", 
      "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections" ]
  }

  provisioner "shell" {
    valid_exit_codes = [  ## Redefine exit codes.  https://stackoverflow.com/questions/70719041/packer-errors-on-attempt-to-run-a-script
      "0",
      "1",
      "2"
    ]
    inline = [
      "sudo fuser -v -k /var/cache/debconf/config.dat"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /ops",
      "sudo chmod 777 /ops"
    ]
  }

  provisioner "file" {
    source      = "../../shared/packer/"
    destination = "/ops"
  }

  provisioner "shell" {
    script = "../../shared/packer/scripts/setup.sh"
  }
}
