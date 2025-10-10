#!/bin/bash

# Check if nvidia-smi is available
if ! command -v nvidia-smi &> /dev/null; then
    echo "nvidia-smi not found"
    exit 0
fi

# Get GPU processes with memory usage and utilization
output=$(nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits 2>/dev/null)

# Get overall GPU utilization (fallback since per-process util may not be available)
overall_util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)

if [ -z "$output" ]; then
    echo "No GPU processes running"
else
    echo "$output" | head -5 | awk -F', ' -v overall="$overall_util" '{
        process = $2
        memory = $3

        # Extract last two path components
        n = split(process, parts, "/")
        if (n >= 2) {
            process = parts[n-1] "/" parts[n]
        } else if (n == 1) {
            process = parts[n]
        }
        if (length(process) > 20) {
            process = substr(process, 1, 17) "..."
        }

        # Use overall GPU utilization
        util_pct = (overall != "") ? overall : "0"

        printf "%-20s %5s MB | %2s%%\n", process, memory, util_pct
    }'
fi
