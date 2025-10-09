#!/bin/bash

# Check if nvidia-smi is available
if ! command -v nvidia-smi &> /dev/null; then
    echo "nvidia-smi not found"
    exit 0
fi

# Get GPU processes
output=$(nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits 2>/dev/null)

if [ -z "$output" ]; then
    echo "No GPU processes running"
else
    echo "$output" | head -5 | awk -F', ' '{
        process = $2
        if (length(process) > 20) {
            process = substr(process, 1, 17) "..."
        }
        printf "%-20s %5s MB\n", process, $3
    }'
fi
