#!/usr/bin/env zsh
# Benchmark script to profile the load time of .bootstrap.sh

# We define a function 'command' to mock 'command -v' and simulate tool availability
command() {
  if [[ "$1" == "-v" || "$1" == "-x" ]]; then
    # Add a 1ms delay to simulate disk/path lookup
    sleep 0.001
    # Return a path that is guaranteed to be executable so `[ -x ... ]` succeeds
    echo "/usr/bin/env"
    return 0
  fi
  builtin command "$@"
}

echo "Starting benchmark of ~/.bootstrap.sh..."

# Capture start time in milliseconds
startTime=$(date +%s%3N)

# Source the bootstrap script just like the real shell would
source ~/.bootstrap.sh

# Capture end time in milliseconds
endTime=$(date +%s%3N)

duration=$((endTime - startTime))

echo "Benchmark complete. Sourcing took ${duration}ms."

# If running in GitHub Actions, publish to the step summary
if [[ -n "$GITHUB_STEP_SUMMARY" ]]; then
    echo "## Shell Startup Benchmark Result 🚀" >> $GITHUB_STEP_SUMMARY
    echo "- **Total Startup Time**: ${duration}ms" >> $GITHUB_STEP_SUMMARY
    echo "- **Simulated Tool Lookups**: Enabled (1ms delay per lookup)" >> $GITHUB_STEP_SUMMARY
fi
