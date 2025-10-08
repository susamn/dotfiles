#!/usr/bin/env bash

# Installation script for Battery Manager service

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="battery-manager"
CONFIG_DIR="$HOME/.config/battery-manager"
CONFIG_FILE="$CONFIG_DIR/config"
LOG_DIR="/var/log"
LOG_FILE="$LOG_DIR/battery-manager.log"

echo "=== Battery Manager Installation ==="
echo

# Create config directory
echo "Creating configuration directory..."
mkdir -p "$CONFIG_DIR"

# Create config file if it doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Creating configuration file at $CONFIG_FILE"
    cat > "$CONFIG_FILE" << 'EOF'
# Battery Manager Configuration
# Edit this file to customize your setup

# Home Assistant URL
HA_URL="http://homeassistant.local:8123"

# Home Assistant Long-Lived Access Token
# Create one at: Home Assistant -> Profile -> Long-Lived Access Tokens
HA_TOKEN=""

# Switch entity ID in Home Assistant
HA_SWITCH_ENTITY="switch.battery_charger"

# Battery thresholds (percentage)
BATTERY_LOW_THRESHOLD=20
BATTERY_HIGH_THRESHOLD=80

# Log file location
LOG_FILE="$HOME/.local/log/battery-manager.log"
EOF
    echo "Please edit $CONFIG_FILE and add your Home Assistant token and settings"
else
    echo "Configuration file already exists at $CONFIG_FILE"
fi

# Create log directory from config file if it was just created
if [[ -f "$CONFIG_FILE" ]]; then
    # Extract LOG_FILE from config and create directory if needed
    CONFIG_LOG_FILE=$(grep "^LOG_FILE=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"' | envsubst)
    if [[ -n "$CONFIG_LOG_FILE" && "$CONFIG_LOG_FILE" == "$HOME"* ]]; then
        LOG_DIR="$(dirname "$CONFIG_LOG_FILE")"
        mkdir -p "$LOG_DIR" 2>/dev/null && echo "Created log directory at $LOG_DIR" || true
    fi
fi

# Make script executable
echo "Making battery-manager.sh executable..."
chmod +x "$SCRIPT_DIR/battery-manager.sh"

# Install systemd user service and timer
echo "Installing systemd user service..."
mkdir -p "$HOME/.config/systemd/user"
cp "$SCRIPT_DIR/${SERVICE_NAME}.service" "$HOME/.config/systemd/user/"
cp "$SCRIPT_DIR/${SERVICE_NAME}.timer" "$HOME/.config/systemd/user/"

# Reload systemd
echo "Reloading systemd user daemon..."
systemctl --user daemon-reload

# Enable and start the timer
echo "Enabling and starting the timer..."
systemctl --user enable "${SERVICE_NAME}.timer"
systemctl --user start "${SERVICE_NAME}.timer"

echo
echo "=== Installation Complete ==="
echo
echo "Next steps:"
echo "1. Edit the configuration file: $CONFIG_FILE"
echo "   - Add your Home Assistant URL"
echo "   - Add your Home Assistant long-lived access token"
echo "   - Set your battery charger switch entity ID"
echo "   - Adjust thresholds if needed"
echo
echo "2. Test the service manually:"
echo "   systemctl --user start ${SERVICE_NAME}.service"
echo
echo "3. Check service status:"
echo "   systemctl --user status ${SERVICE_NAME}.timer"
echo "   systemctl --user status ${SERVICE_NAME}.service"
echo
echo "4. View logs:"
echo "   journalctl --user -u ${SERVICE_NAME}.service -f"
echo "   cat \$(grep LOG_FILE $CONFIG_FILE | cut -d'=' -f2 | tr -d '\"')"
echo
echo "To uninstall:"
echo "   systemctl --user stop ${SERVICE_NAME}.timer"
echo "   systemctl --user disable ${SERVICE_NAME}.timer"
echo "   rm ~/.config/systemd/user/${SERVICE_NAME}.{service,timer}"
echo "   systemctl --user daemon-reload"
echo
