#!/bin/bash
set -Eeuo pipefail

# --- unified logging (console + packer.log + local file) ---
LOG_FILE=/var/log/provision.log
if [[ -z "${_PROVISION_LOG_INITIALIZED:-}" ]]; then
  sudo install -o "$(id -u)" -g "$(id -g)" -m 0644 /dev/null "$LOG_FILE" || true
  exec > >(tee -a "$LOG_FILE")
  exec 2>&1
  export _PROVISION_LOG_INITIALIZED=1
fi
log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
log "Starting setup.sh"
trap 'log "setup.sh failed (exit code $?)"' ERR

echo "Waiting for cloud-init to complete"
timeout 180 /bin/bash -c \
  'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do echo waiting ...; sleep 1; done'

cd /ops

# Define shared/script directories
SHAREDDIR=/ops
SCRIPTDIR=$SHAREDDIR/scripts
CONFIGDIR=$SHAREDDIR/config

# Source OS detection script
source $SCRIPTDIR/os-detect.sh

# OS-specific initial setup
if [[ "${DETECTED_OS}" == "Ubuntu" ]]; then
  # Disable interactive apt prompts
  export DEBIAN_FRONTEND=noninteractive
  echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
  # Kill any debconf locks
  sudo fuser -v -k /var/cache/debconf/config.dat || true
fi

# Copy VSCode workspace
cp $CONFIGDIR/remote.code-workspace /home/$HOME_DIR/

# Update package manager and install dependencies
log "Updating package manager and installing dependencies..."
if [ "$PKG_MANAGER" = "apt-get" ]; then
  pkg_update
  pkg_install unzip tree jq curl tmux wget tar software-properties-common dnsmasq
else
  pkg_update
  # Install EPEL for RHEL/CentOS - RHEL 9 requires direct RPM install
  if [ "$DETECTED_OS" = "rhel" ] || [ "$DETECTED_OS" = "RedHat" ]; then
    log "Installing EPEL for RHEL 9..."
    sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm || log "EPEL install completed with warnings"
  else
    pkg_install epel-release
  fi
  pkg_install unzip tree jq curl tmux wget tar
fi

if [ $? -ne 0 ]; then
    log "Failed to install packages"
    exit 1
fi

# Install AWS CLI v2 manually
log "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws/

log "Installing dnsmasq..."
pkg_install dnsmasq || log "dnsmasq install completed with warnings (systemctl not available in Packer environment)"

# Install and enable SSM Agent & EC2 Instance Connect (where supported)
log "Installing SSM Agent and EC2 Instance Connect components..."
if [[ "${DETECTED_OS}" == "Ubuntu" ]]; then
  # ec2-instance-connect package available on Ubuntu
  if pkg_install amazon-ssm-agent ec2-instance-connect; then
    log "Installed amazon-ssm-agent and ec2-instance-connect"
  else
    log "WARNING: Failed to install one or more packages (amazon-ssm-agent/ec2-instance-connect)"
  fi
elif [[ "${DETECTED_OS}" == "RedHat" ]]; then
  # Try install SSM agent; ec2-instance-connect may not exist in repos
  pkg_install amazon-ssm-agent || log "WARNING: amazon-ssm-agent install failed"
  pkg_install ec2-instance-connect || log "INFO: ec2-instance-connect not available on RedHat (continuing; use SSM for access)"
fi

# Enable/start SSM agent if service present
if systemctl list-unit-files 2>/dev/null | grep -q amazon-ssm-agent; then
  sudo systemctl enable amazon-ssm-agent || true
  sudo systemctl start amazon-ssm-agent || true
  log "SSM agent enabled and started"
else
  log "SSM agent service not found"
fi


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
log "Installing Docker..."
if [[ "${DETECTED_OS}" == "Ubuntu" ]]; then
  distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
  pkg_install apt-transport-https ca-certificates gnupg2
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/${distro} $(lsb_release -cs) stable"
  pkg_update
  pkg_install docker-ce
elif [[ "${DETECTED_OS}" == "RedHat" ]]; then
  # Install Docker on RedHat/RHEL
  pkg_install dnf-plugins-core
  sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
  pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable docker
  sudo systemctl start docker
  # Add ec2-user to docker group
  sudo usermod -aG docker ${HOME_DIR}
fi

# Java
log "Installing Java..."
if [[ "${DETECTED_OS}" == "Ubuntu" ]]; then
  sudo add-apt-repository -y ppa:openjdk-r/ppa
  pkg_update
  pkg_install openjdk-8-jdk
elif [[ "${DETECTED_OS}" == "RedHat" ]]; then
  pkg_install java-1.8.0-openjdk java-1.8.0-openjdk-devel
fi
# JAVA_HOME is already set by os-detect.sh

# CNI plugins
if [ -z "$CNIVERSION" ] || [ "$CNIVERSION" = "null" ]; then
    echo "Error: CNIVERSION is not set or is null"
    exit 1
fi

curl -sL -o cni-plugins.tgz ${CNIDOWNLOAD}
if [ ! -f cni-plugins.tgz ] || [ ! -s cni-plugins.tgz ]; then
    echo "Error: Failed to download CNI plugins"
    exit 1
fi

sudo mkdir -p ${CNIDIR}/bin
sudo tar -C ${CNIDIR}/bin -xzf cni-plugins.tgz

# Restore debconf frontend to Dialog (Ubuntu only)
if [[ "${DETECTED_OS}" == "Ubuntu" ]]; then
  echo 'debconf debconf/frontend select Dialog' | sudo debconf-set-selections
fi

# Ensure prompt script runs only from setup.sh and only once
PROMPT_MARKER=/etc/.custom_prompt_set
if [[ -f "$SCRIPTDIR/set-prompt.sh" ]]; then
  if [[ ! -f "$PROMPT_MARKER" ]]; then
    sudo chmod +x "$SCRIPTDIR/set-prompt.sh"
    # Run with sudo (visible as: sudo $SCRIPTDIR/set-prompt.sh)
    sudo "$SCRIPTDIR/set-prompt.sh" || true
    # Also source so prompt/env changes apply to this shell
    # shellcheck source=/dev/null
    source "$SCRIPTDIR/set-prompt.sh"
    sudo touch "$PROMPT_MARKER"
    log "Applied set-prompt.sh (executed + sourced)"
  else
    log "Skipping set-prompt.sh (already applied)"
  fi
else
  log "Skipping set-prompt.sh (not found at $SCRIPTDIR/set-prompt.sh)"
fi

log "Finished setup.sh"
