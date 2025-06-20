# https://developer.hashicorp.com/packer/guides/hcl/variables
# Packer loads all files ending in .pkr.hcl in a directory and merges them together.
# Packer will automatically load any var file that matches the name *.auto.pkrvars.hcl
# https://developer.hashicorp.com/packer/docs/templates/hcl_templates/functions/contextual/env
# "env" allows you to get the value for an environment variable inside input variables only. 

variable "created_email" { default = "mikael.sikora@hashicorp.com" }
variable "created_name"  { default = "mikael_sikora"}
variable "region"        { default = "us-east-1" }
variable "name_prefix"   { default = "autosc-mws" }
variable "architecture"  { default = "amd64" }
variable "os"            { default = "Ubuntu" }
variable "os_version"    { default = "22.04" }

# assign variables from environment variables
variable "cni_version"    { default = env("CNIVERSION") }
variable "consul_version" { default = env("CONSULVERSION") }
variable "nomad_version"  { default = env("NOMADVERSION") }
variable "vault_version"  { default = env("VAULTVERSION") }
