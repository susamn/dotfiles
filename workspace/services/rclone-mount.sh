#!/bin/bash
# Runner script for rclone-mount systemd service template.
# Reads configuration from $HOME/.config/rclone-sync-profiles/<profile>.conf.

set -euo pipefail

UNMOUNT_ONLY=false
if [[ "${1:-}" == "--unmount" ]]; then
    UNMOUNT_ONLY=true
    shift
fi

if [[ $# -lt 1 || -z "${1:-}" ]]; then
    echo "Usage: $0 [--unmount] <profile>" >&2
    exit 2
fi

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
RCLONE_CONFIG=""
RCLONE_OPTS=""

# Source the configuration file
# shellcheck disable=SC1090
source "$CONF_FILE"

# Validation
if [[ -z "$REMOTE" || -z "$LOCAL_PATH" || -z "$SYNC_TYPE" ]]; then
    echo "Error: Missing required variables in $CONF_FILE." >&2
    echo "Required: REMOTE, LOCAL_PATH, SYNC_TYPE" >&2
    exit 1
fi

# Resolve default config path if not set
if [[ -z "$RCLONE_CONFIG" ]]; then
    RCLONE_CONFIG="$HOME/.config/rclone/rclone.conf"
fi

# Invoked by the unit's ExecStopPost to clear a stale FUSE mountpoint left behind
# when rclone dies without unmounting. Exits 0 when there is nothing to do, since
# that is the normal case after a clean shutdown.
if [[ "$UNMOUNT_ONLY" == true ]]; then
    if mountpoint -q "$LOCAL_PATH" 2>/dev/null; then
        echo "Clearing stale mount at $LOCAL_PATH"
        fusermount -uz "$LOCAL_PATH" 2>/dev/null \
            || umount -l "$LOCAL_PATH" 2>/dev/null \
            || echo "Warning: could not unmount $LOCAL_PATH" >&2
    fi
    exit 0
fi

# Ensure local mount point directory exists
mkdir -p "$LOCAL_PATH"

echo "=== Rclone Mount Profile: $PROFILE ==="
echo "Local Path: $LOCAL_PATH"
echo "Remote: $REMOTE:$REMOTE_PATH"
echo "======================================"

# Run rclone mount
# We use exec so rclone replaces this shell process and receives systemd signals directly
exec rclone mount "$REMOTE:$REMOTE_PATH" "$LOCAL_PATH" \
    --config "$RCLONE_CONFIG" \
    --vfs-cache-mode writes \
    --vfs-cache-max-age 24h \
    --vfs-read-chunk-size 16M \
    $RCLONE_OPTS
