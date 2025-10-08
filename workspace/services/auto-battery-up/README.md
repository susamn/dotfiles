# Battery Manager Service

Automatically controls your battery charger via Home Assistant based on battery levels.

## Features

- Monitors battery level every 2 minutes
- Turns ON charger when battery ≤ 20%
- Turns OFF charger when battery ≥ 80%
- Graceful failure handling - won't crash if Home Assistant is unreachable
- Comprehensive logging
- Configurable thresholds and settings

## Requirements

- Linux system with systemd
- Home Assistant instance accessible via network
- Home Assistant Long-Lived Access Token
- Battery charger switch configured in Home Assistant

## Installation

1. Run the installation script:
   ```bash
   ./install.sh
   ```

2. Edit the configuration file:
   ```bash
   nano ~/.config/battery-manager/config
   ```

3. Add your Home Assistant details:
   - `HA_URL`: Your Home Assistant URL (e.g., `http://homeassistant.local:8123`)
   - `HA_TOKEN`: Long-lived access token (create at Profile → Security → Long-Lived Access Tokens)
   - `HA_SWITCH_ENTITY`: Entity ID of your charger switch (e.g., `switch.battery_charger`)

4. Test the service:
   ```bash
   systemctl --user start battery-manager.service
   systemctl --user status battery-manager.service
   ```

## Usage

The timer runs automatically and checks battery every 2 minutes.

### View status
```bash
systemctl --user status battery-manager.timer
systemctl --user status battery-manager.service
```

### View logs
```bash
# Systemd logs
journalctl --user -u battery-manager.service -f

# Application logs
tail -f ~/.local/log/battery-manager.log
```

### Manual trigger
```bash
systemctl --user start battery-manager.service
```

### Stop/Disable
```bash
systemctl --user stop battery-manager.timer
systemctl --user disable battery-manager.timer
```

## Configuration

Edit `~/.config/battery-manager/config`:

```bash
# Home Assistant URL
HA_URL="http://homeassistant.local:8123"

# Home Assistant Long-Lived Access Token
HA_TOKEN="your_token_here"

# Switch entity ID
HA_SWITCH_ENTITY="switch.battery_charger"

# Battery thresholds (percentage)
BATTERY_LOW_THRESHOLD=20
BATTERY_HIGH_THRESHOLD=80

# Log file location
LOG_FILE="$HOME/.local/log/battery-manager.log"
```

## Troubleshooting

**Service not starting:**
- Check logs: `journalctl --user -u battery-manager.service -xe`
- Verify config file exists and has correct settings
- Ensure script is executable: `chmod +x battery-manager.sh`

**Home Assistant not reachable:**
- Service will log warnings but won't fail
- Check HA_URL and network connectivity
- Verify Home Assistant is running

**Token errors:**
- Regenerate Long-Lived Access Token in Home Assistant
- Update token in config file
- Ensure no extra spaces or quotes in token

**Battery not detected:**
- Check if `/sys/class/power_supply/BAT0/` or `BAT1` exists
- Run script manually to see error messages

## Files

- `battery-manager.sh` - Main script
- `battery-manager.service` - Systemd service unit
- `battery-manager.timer` - Systemd timer unit
- `install.sh` - Installation script
- `~/.config/battery-manager/config` - User configuration

## Uninstall

```bash
systemctl --user stop battery-manager.timer
systemctl --user disable battery-manager.timer
rm ~/.config/systemd/user/battery-manager.{service,timer}
systemctl --user daemon-reload
rm -rf ~/.config/battery-manager
```
