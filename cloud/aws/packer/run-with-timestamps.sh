#!/bin/bash
# Run packer with timestamps on each line of output AND save to logfile
# Combines functionality of logcmd with run-with-timestamps

export PACKER_LOG=1
export PACKER_LOG_TIMESTAMP=1

# Setup logging (from logcmd function)
cmd="packer"
logdir="./logs"
timestamp="$(gdate -u +%Y%m%d-%H%M%S.%3N)Z"
logfile="${logdir}/$(hostname -s)_${cmd}_${timestamp}.out"

# Create logs directory if it doesn't exist
[[ ! -d "$logdir" ]] && mkdir -p "$logdir"

echo "Logging to: $logfile"

# Add timestamps to stdout using ts (if available) or a simple date prefix
# AND save to logfile using tee
if command -v ts &> /dev/null; then
    # Use ts from moreutils if available (brew install moreutils)
    packer build "$@" 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' | tee "$logfile"
elif command -v gawk &> /dev/null; then
    # Use gawk if available
    packer build "$@" 2>&1 | gawk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0; fflush(); }' | tee "$logfile"
else
    # Fallback: use while loop with date
    packer build "$@" 2>&1 | while IFS= read -r line; do
        printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"
    done | tee "$logfile"
fi

# Made with Bob
