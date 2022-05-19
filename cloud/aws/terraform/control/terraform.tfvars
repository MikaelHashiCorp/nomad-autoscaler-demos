region                  = "us-east-1"
availability_zones      = ["us-east-1a"]
ami                     = "ami-02bebb047a1163512"
key_name                = "support_eng_dev-access-key-mikael"
owner_name              = "Mikael_Sikora"
owner_email             = "mikael.sikora@hashicorp.com"
stack_name              = "nomad-mikael"
server_instance_type    = "t3.medium" 
server_count            = "3"
client_instance_type    = "t3.medium"
client_count            = "1"
allowlist_ip            = "73.109.72.170/32"
nomad_autoscaler_image  = "hashicorp/nomad-autoscaler:latest
"