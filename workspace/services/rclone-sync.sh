#!/bin/bash
# Runner script for rclone-sync systemd service template.
# Reads configuration from $HOME/.config/rclone-sync-profiles/<profile>.conf.

set -euo pipefail

PROFILE="$1"
CONF_FILE="$HOME/.config/rclone-sync-profiles/${PROFILE}.conf"

if [[ ! -f "$CONF_FILE" ]]; then
    echo "Error: Configuration file $CONF_FILE not found." >&2
    exit 1
fi

# Load configuration
REMOTE=""
REMOTE_PATH=""
LOCAL_PATH=""
SYNC_TYPE=""
DIRECTION="local-to-remote"
RCLONE_CONFIG=""
RCLONE_OPTS=""

# Source the configuration file
# shellcheck disable=SC1090
source "$CONF_FILE"

# Validation.
# REMOTE_PATH is deliberately NOT required: cloud_sync.sh offers "leave blank for
# root", and an empty value is the valid way to address the root of a remote.
if [[ -z "$REMOTE" || -z "$LOCAL_PATH" || -z "$SYNC_TYPE" ]]; then
    echo "Error: Missing required variables in $CONF_FILE." >&2
    echo "Required: REMOTE, LOCAL_PATH, SYNC_TYPE" >&2
    exit 1
fi

# Resolve default config path if not set
if [[ -z "$RCLONE_CONFIG" ]]; then
    RCLONE_CONFIG="$HOME/.config/rclone/rclone.conf"
fi

if [[ ! -f "$RCLONE_CONFIG" ]]; then
    echo "Warning: Rclone config file not found at $RCLONE_CONFIG." >&2
fi

# Check for resync flag
RESYNC_FLAG="$HOME/.config/rclone-sync-profiles/${PROFILE}.resync"
EXTRA_FLAGS=""
if [[ -f "$RESYNC_FLAG" ]]; then
    echo "Resync flag detected. Appending --resync to command."
    EXTRA_FLAGS="--resync"
fi

echo "=== Rclone Sync Profile: $PROFILE ==="
echo "User: $USER"
echo "Local Path: $LOCAL_PATH"
echo "Remote: $REMOTE:$REMOTE_PATH"
echo "Sync Type: $SYNC_TYPE"
if [[ "$SYNC_TYPE" == "one" ]]; then
    echo "Direction: $DIRECTION"
fi
echo "======================================"

# Ensure local path exists
if [[ ! -d "$LOCAL_PATH" ]]; then
    echo "Error: Local path '$LOCAL_PATH' does not exist or is not a directory." >&2
    exit 1
fi

# Run rclone directly (as the service user, which matches the config owner)
if [[ "$SYNC_TYPE" == "bidirectional" ]]; then
    echo "Running bidirectional sync (bisync)..."
    # shellcheck disable=SC2086
    rclone bisync "$LOCAL_PATH" "$REMOTE:$REMOTE_PATH" \
        --config "$RCLONE_CONFIG" \
        --verbose \
        $EXTRA_FLAGS \
        $RCLONE_OPTS
        
    # Remove resync flag file on success
    if [[ -f "$RESYNC_FLAG" ]]; then
        rm -f "$RESYNC_FLAG"
        echo "Resync completed successfully. Flag file removed."
    fi
else
    echo "Running one-way sync (rclone sync)..."
    if [[ "$DIRECTION" == "remote-to-local" ]]; then
        # shellcheck disable=SC2086
        rclone sync "$REMOTE:$REMOTE_PATH" "$LOCAL_PATH" \
            --config "$RCLONE_CONFIG" \
            --verbose \
            $RCLONE_OPTS
    else
        # shellcheck disable=SC2086
        rclone sync "$LOCAL_PATH" "$REMOTE:$REMOTE_PATH" \
            --config "$RCLONE_CONFIG" \
            --verbose \
            $RCLONE_OPTS
    fi
fi

echo "Sync completed successfully."
