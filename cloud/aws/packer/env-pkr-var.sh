#!/bin/bash
# https://discuss.hashicorp.com/t/hcl2-environment-variables/9290/2
# https://developer.hashicorp.com/packer/docs/templates/hcl_templates/functions/contextual/env

# SHELL FRIENDLY

CNIVERSION=$(curl -s https://api.github.com/repos/containernetworking/plugins/releases/latest | jq -r .tag_name)
CONSULVERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/consul | jq -r '.current_version')
NOMADVERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/nomad | jq -r '.current_version')

export CNIVERSION CONSULVERSION NOMADVERSION 

echo "CNIVERSION:    $CNIVERSION"
echo "CONSULVERSION: $CONSULVERSION"
echo "NOMADVERSION:  $NOMADVERSION"