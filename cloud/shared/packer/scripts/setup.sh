#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


set -e

echo "Waiting for cloud-init to update /etc/apt/sources.list"
timeout 180 /bin/bash -c \
  'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do echo waiting ...; sleep 1; done'

# Disable interactive apt prompts
export DEBIAN_FRONTEND=noninteractive
echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections

cd /ops

# Dependencies
sudo apt-get update

sudo apt-get install -y software-properties-common unzip tree redis-tools jq curl tmux awscli ec2-instance-connect
echo -e "\nInstalling DNSMASQ.  Ignore por 53 errors\n"
sudo apt-get install -y dnsmasq

CONFIGDIR=/ops/config

# CONSULVERSION=1.12.2
# CONSULVERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/consul | jq -r '.current_version')
CONSULDOWNLOAD=https://releases.hashicorp.com/consul/${CONSULVERSION}/consul_${CONSULVERSION}_linux_amd64.zip
echo "CONSULDOWNLOAD=${CONSULDOWNLOAD}"
CONSULCONFIGDIR=/etc/consul.d
CONSULDIR=/opt/consul

# NOMADVERSION=1.1.1
# NOMADVERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/nomad | jq -r '.current_version')
NOMADDOWNLOAD=https://releases.hashicorp.com/nomad/${NOMADVERSION}/nomad_${NOMADVERSION}_linux_amd64.zip
echo "NOMADDOWNLOAD=${NOMADDOWNLOAD}"
NOMADCONFIGDIR=/etc/nomad.d
NOMADDIR=/opt/nomad

# CNIVERSION=v1.3.0
CNIDOWNLOAD=https://github.com/containernetworking/plugins/releases/download/${CNIVERSION}/cni-plugins-linux-amd64-${CNIVERSION}.tgz
echo "CNIDOWNLOAD=${CNIDOWNLOAD}"
CNIDIR=/opt/cni

# Disable the firewall
sudo ufw disable || echo "ufw not installed"

# Consul
curl -sL -o consul.zip ${CONSULDOWNLOAD}

## Install
sudo unzip -o consul.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/consul
sudo chown root:root /usr/local/bin/consul

## Configure
sudo mkdir -p ${CONSULCONFIGDIR}
sudo chmod 755 ${CONSULCONFIGDIR}
sudo mkdir -p ${CONSULDIR}
sudo chmod 755 ${CONSULDIR}
sudo mkdir -p ${CONSULDIR}/logs
sudo chmod 755 ${CONSULDIR}/logs

# Nomad
curl -sL -o nomad.zip ${NOMADDOWNLOAD}

## Install
sudo unzip -o nomad.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/nomad
sudo chown root:root /usr/local/bin/nomad

## Configure
sudo mkdir -p ${NOMADCONFIGDIR}
sudo chmod 755 ${NOMADCONFIGDIR}
sudo mkdir -p ${NOMADDIR}
sudo chmod 755 ${NOMADDIR}
sudo mkdir -p ${NOMADDIR}/logs
sudo chmod 755 ${NOMADDIR}/logs

# Docker
distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
sudo apt-get install -y apt-transport-https ca-certificates gnupg2
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/${distro} $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce

# Java
sudo add-apt-repository -y ppa:openjdk-r/ppa
sudo apt-get update
sudo apt-get install -y openjdk-8-jdk
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")

# CNI plugins
curl -sL -o cni-plugins.tgz ${CNIDOWNLOAD}
sudo mkdir -p ${CNIDIR}/bin
sudo tar -C ${CNIDIR}/bin -xzf cni-plugins.tgz

echo 'debconf debconf/frontend select Dialog' | sudo debconf-set-selections
