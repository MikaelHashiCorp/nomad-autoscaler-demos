#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo chmod +x /ops/scripts/server.sh
sudo bash -c "NOMAD_BINARY=${nomad_binary} CONSUL_BINARY=${consul_binary}  /ops/scripts/server.sh \"aws\" \"${server_count}\" \"${retry_join}\""
rm -rf /ops/

# Install ec2 Instance Connect
sudo apt -y install awscli ec2-instance-connect
