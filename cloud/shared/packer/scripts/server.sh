#!/bin/bash
# Copyright IBM Corp. 2020, 2024
# SPDX-License-Identifier: MPL-2.0

set -Eeuo pipefail

LOG_FILE=/var/log/provision.log
if [[ -z "${_PROVISION_LOG_INITIALIZED:-}" ]]; then
  sudo install -o "$(id -u)" -g "$(id -g)" -m 0644 /dev/null "$LOG_FILE" || true
  exec > >(tee -a "$LOG_FILE")
  exec 2>&1
  export _PROVISION_LOG_INITIALIZED=1
fi
log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

log "Starting server.sh"
trap 'log "server.sh failed (exit code $?)"' ERR
trap 'log "Finished server.sh"' EXIT

echo -e "\nInstalling SERVER...\n"

SHAREDDIR=/ops/
CONFIGDIR=$SHAREDDIR/config
SCRIPTDIR=$SHAREDDIR/scripts

# Source OS detection and network helper scripts
source $SCRIPTDIR/os-detect.sh
source $SCRIPTDIR/net.sh
set -e

CONSULCONFIGDIR=/etc/consul.d
NOMADCONFIGDIR=/etc/nomad.d

# Wait for network
sleep 15

IP_ADDRESS=$(net_getDefaultRouteAddress)
DOCKER_BRIDGE_IP_ADDRESS=$(net_getInterfaceAddress docker0)
CLOUD=$1
SERVER_COUNT=$2
RETRY_JOIN=$3

# Consul
## Replace existing Consul binary if remote file exists
if [[ `wget -S --spider $CONSUL_BINARY  2>&1 | grep 'HTTP/1.1 200 OK'` ]]; then
  curl -L $CONSUL_BINARY > consul.zip
  sudo unzip -o consul.zip -d /usr/local/bin
  sudo chmod 0755 /usr/local/bin/consul
  sudo chown root:root /usr/local/bin/consul
fi

sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $CONFIGDIR/consul.hcl
sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" $CONFIGDIR/consul.hcl
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" $CONFIGDIR/consul.hcl
sudo cp $CONFIGDIR/consul.hcl $CONSULCONFIGDIR
sudo cp $CONFIGDIR/consul_$CLOUD.service /etc/systemd/system/consul.service

sudo systemctl enable consul
sudo systemctl start consul.service
sleep 10
export CONSUL_HTTP_ADDR=$IP_ADDRESS:8500
export CONSUL_RPC_ADDR=$IP_ADDRESS:8400

# Nomad

## Replace existing Nomad binary if remote file exists
if [[ `wget -S --spider $NOMAD_BINARY  2>&1 | grep 'HTTP/1.1 200 OK'` ]]; then
  curl -L $NOMAD_BINARY > nomad.zip
  sudo unzip -o nomad.zip -d /usr/local/bin
  sudo chmod 0755 /usr/local/bin/nomad
  sudo chown root:root /usr/local/bin/nomad
fi

sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" $CONFIGDIR/nomad.hcl
sudo cp $CONFIGDIR/nomad.hcl $NOMADCONFIGDIR
sudo cp $CONFIGDIR/nomad.service /etc/systemd/system/nomad.service

sudo systemctl enable nomad
sudo systemctl start nomad.service
sleep 10
export NOMAD_ADDR=http://$IP_ADDRESS:4646

# Add hostname to /etc/hosts
echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts

# dnsmasq config
echo -e "\nConfiguring DNSMASQ...\n"

# Detect OS type for OS-specific DNS handling
DETECTED_OS=$(detect_os)
log "Detected OS: $DETECTED_OS"

# Check if systemd-resolved is present and active
# Ubuntu: 17.04+ has systemd-resolved (includes 20.04, 22.04, 24.04)
# RedHat: RHEL 9+ has systemd-resolved; RHEL 7/8 do not
HAS_SYSTEMD_RESOLVED=false
if systemctl list-unit-files 2>/dev/null | grep -q systemd-resolved; then
  HAS_SYSTEMD_RESOLVED=true
  log "Detected systemd-resolved, configuring for dnsmasq compatibility"
  
  # Disable DNS stub listener to free up port 53
  if [ -f /etc/systemd/resolved.conf ]; then
    if ! grep -q "^DNSStubListener=no" /etc/systemd/resolved.conf; then
      echo "DNSStubListener=no" | sudo tee -a /etc/systemd/resolved.conf
      log "Disabled systemd-resolved DNS stub listener"
    fi
  fi
  
  # Restart systemd-resolved to apply DNSStubListener change
  sudo systemctl restart systemd-resolved
  sleep 1
fi

# Handle /etc/resolv.conf based on whether it's a symlink or regular file
if [ -L /etc/resolv.conf ]; then
  log "Detected /etc/resolv.conf as symlink, removing it"
  # Store the target of the symlink for fallback nameservers
  SYMLINK_TARGET=$(readlink -f /etc/resolv.conf)
  if [ -f "$SYMLINK_TARGET" ]; then
    sudo cp "$SYMLINK_TARGET" /etc/resolv.conf.orig
  fi
  sudo rm -f /etc/resolv.conf
elif [ -f /etc/resolv.conf ]; then
  log "Backing up existing /etc/resolv.conf"
  sudo cp /etc/resolv.conf /etc/resolv.conf.orig
fi

# For RedHat 9+ with systemd-resolved, also check /run/systemd/resolve/resolv.conf
if [ "$HAS_SYSTEMD_RESOLVED" = "true" ] && [ "$DETECTED_OS" = "RedHat" ]; then
  log "RedHat with systemd-resolved: using /run/systemd/resolve/resolv.conf for fallback"
  if [ -f /run/systemd/resolve/resolv.conf ]; then
    sudo cp /run/systemd/resolve/resolv.conf /etc/resolv.conf.orig
  fi
fi

sudo cp /ops/config/10-consul.dnsmasq /etc/dnsmasq.d/10-consul
sudo cp /ops/config/99-default.dnsmasq.$CLOUD /etc/dnsmasq.d/99-default

# Build new resolv.conf with 127.0.0.1 (dnsmasq) as primary nameserver
log "Creating /etc/resolv.conf with dnsmasq as primary nameserver"
sudo tee /etc/resolv.conf > /dev/null <<EOF
nameserver 127.0.0.1
EOF

# Add fallback nameservers from original config
# Skip systemd-resolved stub (127.0.0.53) and localhost (127.0.0.1)
if [ -f /etc/resolv.conf.orig ]; then
  log "Adding fallback nameservers from original configuration"
  grep "^nameserver" /etc/resolv.conf.orig 2>/dev/null | \
    grep -v "127.0.0.53" | \
    grep -v "127.0.0.1" | \
    sudo tee -a /etc/resolv.conf > /dev/null || true
fi

# If no fallback nameservers were added, add cloud provider DNS as fallback
if [ $(grep -c "^nameserver" /etc/resolv.conf) -eq 1 ]; then
  log "No fallback nameservers found, adding cloud provider DNS"
  case "$CLOUD" in
    aws)
      echo "nameserver 169.254.169.253" | sudo tee -a /etc/resolv.conf
      ;;
    azure)
      echo "nameserver 168.63.129.16" | sudo tee -a /etc/resolv.conf
      ;;
    gcp)
      echo "nameserver 169.254.169.254" | sudo tee -a /etc/resolv.conf
      ;;
  esac
fi

sudo systemctl enable dnsmasq
sudo systemctl restart dnsmasq

# Wait for dnsmasq to start
sleep 2

# Verify dnsmasq is listening on port 53
if ! sudo netstat -tulpn 2>/dev/null | grep -q ":53.*dnsmasq" && ! sudo ss -tulpn 2>/dev/null | grep -q ":53.*dnsmasq"; then
  log "WARNING: dnsmasq may not be listening on port 53"
else
  log "Verified: dnsmasq is listening on port 53"
fi

# Add Docker bridge network IP to /etc/resolv.conf (at the top)
echo "nameserver $DOCKER_BRIDGE_IP_ADDRESS" | sudo tee /etc/resolv.conf.new
cat /etc/resolv.conf | sudo tee --append /etc/resolv.conf.new
sudo mv /etc/resolv.conf.new /etc/resolv.conf

# Set env vars for tool CLIs
echo "export CONSUL_RPC_ADDR=$IP_ADDRESS:8400" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export CONSUL_HTTP_ADDR=$IP_ADDRESS:8500" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export JAVA_HOME=${JAVA_HOME}"  | sudo tee --append /home/$HOME_DIR/.bashrc

# set alias
alias env="env -0 | sort -z | tr '\0' '\n'"

# set terminal color
echo "export TERM=xterm-256color" | sudo tee --append /home/$HOME_DIR/.bashrc

log "Finished server.sh"