# HA Metrics Monitor

Pushes Linux server metrics to Home Assistant via MQTT Discovery.

## Features

- **MQTT Discovery**: Automatically creates 11 sensors in Home Assistant.
- **Metrics**: CPU Usage, RAM Usage, Disk Usage/Free, CPU Temp, Load 1m, Uptime, IP Address, Network RX/TX, Process Count.
- **Lightweight**: Uses `mosquitto_pub` and standard Linux tools.
- **Easy Deployment**: Managed via systemd timer (every 30s by default).

## Installation

1. **Prerequisites**:
   - Install MQTT broker (e.g., Mosquitto) in Home Assistant.
   - Install `mosquitto-clients` on this server.
     - Debian/Ubuntu: `sudo apt install mosquitto-clients`
     - Arch: `sudo pacman -S mosquitto`

2. **Setup**:
   - Stow the dotfiles (if not already done): `./do-stow.sh`
   - Run the install script:
     ```bash
     ~/workspace/services/ha-monitor/install.sh
     ```

3. **Configure**:
   - Edit `~/.config/ha-monitor/config` with your MQTT broker details and credentials.

4. **Verify**:
   - Check the timer status: `systemctl --user status ha-metrics.timer`
   - Trigger a manual run: `systemctl --user start ha-metrics.service`
   - View logs: `journalctl --user -u ha-metrics.service -f`

## Home Assistant Setup

1. Settings → Add-ons → Mosquitto broker → Install → Start.
2. Create a dedicated MQTT user: Settings → People → Users → Add User (e.g., `linux-monitor`).
3. Add the MQTT integration: Settings → Devices & Services → Add Integration → MQTT.
4. Sensors will appear automatically under the MQTT integration as a device named after your hostname.
