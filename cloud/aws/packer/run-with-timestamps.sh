#!/bin/bash
# Run packer with timestamps on each line of output

export PACKER_LOG=1
export PACKER_LOG_TIMESTAMP=1

packer build "$@"

# Made with Bob
