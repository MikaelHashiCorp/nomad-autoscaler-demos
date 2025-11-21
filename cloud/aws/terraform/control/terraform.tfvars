region                 = "us-west-2"
availability_zones     = ["us-west-2a", "us-west-2b", "us-west-2c"]
ami                    = "ami-06c51948c651b8e45"  # Latest public Windows Server 2022 English Full Base (for bootstrap test)
cleanup_ami_on_destroy = true
key_name               = "mhc-aws-mws-west-2"
owner_name             = "Mikael Sikora"
owner_email            = "mikael.sikora@hashicorp.com"
# Base name prefix; OS suffix (ubuntu|rhel|win) appended automatically.
stack_name             = "scale-mws"

# HashiStack sizing (Windows requires larger instance class)
server_instance_type   = "t3a.xlarge"  # Windows: t3a.xlarge; adjust to t3a.small for Ubuntu/RedHat minimal demo
server_count           = 1
client_instance_type   = "t3a.xlarge"  # Windows: match server size; adjust for Linux as needed
client_count           = 1

allowlist_ip           = []  # Empty => your current IP only

# OS selection for packer/cluster build (one of: Ubuntu, RedHat, Windows)
packer_os              = "Windows"
packer_os_version      = "2022"
packer_os_name         = ""  # Not used for Windows

# Disable Nomad jobs while debugging Windows bootstrap (skip provider usage)
enable_nomad_jobs      = false

