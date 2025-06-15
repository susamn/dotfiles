#!/bin/bash

CONFIG_FLAGS="$HOME/.config/flags.conf"

# Load flags from config if file exists
if [[ ! -f "$CONFIG_FLAGS" ]]; then
  echo "⚠️  Flags config file not found: $CONFIG_FLAGS"
  exit 0
fi
source "$CONFIG_FLAGS"

# Check dependencies function
check_command() {
  local cmd=$1
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Required command '$cmd' is not installed."
    exit 1
  fi
}

# Iterate over all ENABLE_ flags and run their corresponding feature functions
for var in $(compgen -A variable | grep '^ENABLE_'); do
  value="${!var}"
  if [[ "$value" == "true" ]]; then
    # Convert var name to lowercase to match function name
    feature_func="feature_$(echo "$var" | tr '[:upper:]' '[:lower:]')"
    if declare -f "$feature_func" > /dev/null; then
      echo "▶ Running: $feature_func"
      "$feature_func"
    else
      echo "⚠️ No function defined for flag: $var"
    fi
  fi
done

