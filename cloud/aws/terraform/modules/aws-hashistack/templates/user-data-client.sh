#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo chmod +x /ops/scripts/client.sh
sudo bash -c "NOMAD_BINARY=${nomad_binary} CONSUL_BINARY=${consul_binary}  /ops/scripts/client.sh \"aws\" \"${retry_join}\" \"${node_class}\""
rm -rf /ops/

# Mount data volume
sudo mkfs -t xfs /dev/nvme1n1
sudo mkdir /mnt/data
sudo mount /dev/nvme1n1 /mnt/data
sudo chown ubuntu:ubuntu data
ln -s /mnt/data /home/ubuntu/data

# Install ec2 Instance Connect
sudo apt -y install awscli ec2-instance-connect
