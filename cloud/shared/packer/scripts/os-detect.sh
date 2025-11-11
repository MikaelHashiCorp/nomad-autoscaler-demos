#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# OS Detection and Configuration Helper
# This script detects the OS type and exports OS-specific variables for use in other provisioning scripts.
# Usage: source /path/to/os-detect.sh

set -euo pipefail

# Detect OS from /etc/os-release or environment variable
detect_os() {
  # Allow override via environment variable (from Packer)
  if [[ -n "${TARGET_OS:-}" ]]; then
    echo "${TARGET_OS}"
    return
  fi
  
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "${ID}" in
      ubuntu)
        echo "Ubuntu"
        ;;
      rhel|redhat)
        echo "RedHat"
        ;;
      *)
        echo "Unknown"
        ;;
    esac
  else
    echo "Unknown"
  fi
}

# Export OS-specific variables
export DETECTED_OS=$(detect_os)

case "${DETECTED_OS}" in
  Ubuntu)
    export HOME_DIR="ubuntu"
    export PKG_MANAGER="apt-get"
    export PKG_UPDATE="sudo apt-get update"
    export PKG_INSTALL="sudo apt-get install -y"
    export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64/jre"
    export DOCKER_REPO="ubuntu"
    export LSB_RELEASE_CMD="lsb_release -cs"
    ;;
  RedHat)
    export HOME_DIR="ec2-user"
    export PKG_MANAGER="dnf"
    export PKG_UPDATE="sudo dnf check-update || true"
    export PKG_INSTALL="sudo dnf install -y"
    export JAVA_HOME="/usr/lib/jvm/jre-1.8.0-openjdk"
    export DOCKER_REPO="rhel"
    export LSB_RELEASE_CMD="echo '9'"
    ;;
  *)
    echo "ERROR: Unsupported OS: ${DETECTED_OS}"
    exit 1
    ;;
esac

# Export common functions for package management
pkg_update() {
  eval "${PKG_UPDATE}"
}

pkg_install() {
  eval "${PKG_INSTALL} $*"
}

log() { 
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

log "OS Detection: ${DETECTED_OS}"
log "HOME_DIR: ${HOME_DIR}"
log "PKG_MANAGER: ${PKG_MANAGER}"
log "JAVA_HOME: ${JAVA_HOME}"
