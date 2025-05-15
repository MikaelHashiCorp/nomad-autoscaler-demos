#!/bin/bash
# https://discuss.hashicorp.com/t/hcl2-environment-variables/9290/2
# https://developer.hashicorp.com/packer/docs/templates/hcl_templates/functions/contextual/en
# https://releases.hashicorp.com/

# SHELL FRIENDLY

CNIVERSION=$(curl -s https://api.github.com/repos/containernetworking/plugins/releases/latest | jq -r .tag_name)
CONSULVERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/consul | jq -r '.current_version')
NOMADVERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/nomad | jq -r '.current_version')
VAULTVERSION=$(curl -s https://releases.hashicorp.com/vault/index.json | jq --raw-output '.versions |= with_entries(select(.key|match("^\\d+\\.\\d+\\.\\d+$"))) | .versions | keys[]' | sort -rV | head -n1)
CONSULTEMPLATEVERSION=$(curl -s https://releases.hashicorp.com/consul-template/index.json | jq --raw-output '.versions |= with_entries(select(.key|match("^\\d+\\.\\d+\\.\\d+$"))) | .versions | keys[]' | sort -rV | head -n1)

# OVERRIDE ENVIRONMENT VARIABLES
# NOMADVERSION="1.8.3+ent"

export CNIVERSION CONSULVERSION NOMADVERSION VAULTVERSION CONSULTEMPLATEVERSION

echo "CNIVERSION:             $CNIVERSION"
echo "CONSULVERSION:          $CONSULVERSION"
echo "NOMADVERSION:           $NOMADVERSION"
echo "VAULTVERSION:           $VAULTVERSION"
echo "CONSULTEMPLATEVERSION:  $CONSULTEMPLATEVERSION"
