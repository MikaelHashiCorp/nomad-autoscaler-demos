#!/bin/zsh
# Wrapper to run validation with logcmd

# Source environment to get logcmd function
source ~/.zshrc

# Change to packer directory
cd "$(dirname "$0")"

# Run validation with logcmd
logcmd ./validate-build12.sh

# Made with Bob
