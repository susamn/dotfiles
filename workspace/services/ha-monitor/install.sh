#!/usr/bin/env bash

# Installation script for HA Metrics Monitor service

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="ha-metrics"
CONFIG_DIR="$HOME/.config/ha-monitor"
CONFIG_FILE="$CONFIG_DIR/config"

echo "=== HA Metrics Monitor Installation ==="
echo

# Create config directory
echo "Creating configuration directory..."
mkdir -p "$CONFIG_DIR"

# Create config file if it doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Creating configuration file at $CONFIG_FILE"
    cat > "$CONFIG_FILE" << 'EOF'
# HA Metrics Monitor Configuration
# Edit this file to customize your setup

# MQTT Broker address
BROKER="192.168.1.111"

# MQTT Port
PORT="1883"

# MQTT Username
USER="linux-monitor"

# MQTT Password
PASS="<password>"

# Node ID (defaults to hostname if empty)
NODE_ID=""

# MQTT Discovery Prefix
DISCOVERY_PREFIX="homeassistant"
EOF
    echo "Please edit $CONFIG_FILE and add your MQTT credentials"
else
    echo "Configuration file already exists at $CONFIG_FILE"
fi

# Make script executable
echo "Making ha-metrics-push.sh executable..."
chmod +x "$SCRIPT_DIR/ha-metrics-push.sh"

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
echo "   - Add your MQTT Broker address"
echo "   - Add your MQTT credentials"
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
echo
