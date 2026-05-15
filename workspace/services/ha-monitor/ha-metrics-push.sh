#!/usr/bin/env bash
# Push metrics to Home Assistant via MQTT

# Load configuration
CONFIG_FILE="$HOME/.config/ha-monitor/config"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

BROKER="${BROKER:-192.168.1.111}"
PORT="${PORT:-1883}"
USER="${USER:-linux-monitor}"
PASS="${PASS:-<password>}"
NODE_ID="${NODE_ID:-$(hostname)}"
DISCOVERY_PREFIX="${DISCOVERY_PREFIX:-homeassistant}"

pub() {
  mosquitto_pub -h "$BROKER" -p "$PORT" -u "$USER" -P "$PASS" "$@"
}

# ── Register sensors via MQTT Discovery (run once, idempotent) ──────────────
register() {
  local name="$1" unit="$2" icon="$3" device_class="$4"
  local slug="${name// /_}"
  local topic="${DISCOVERY_PREFIX}/sensor/${NODE_ID}/${slug}/config"
  local payload
  payload=$(printf '{
    "name": "%s",
    "unique_id": "%s_%s",
    "state_topic": "linux/%s/%s",
    "unit_of_measurement": "%s",
    "icon": "mdi:%s",
    "device_class": "%s",
    "device": {
      "identifiers": ["%s"],
      "name": "%s",
      "model": "Linux Server"
    }
  }' "$name" "$NODE_ID" "$slug" "$NODE_ID" "$slug" \
     "$unit" "$icon" "$device_class" \
     "$NODE_ID" "$NODE_ID")
  pub -r -t "$topic" -m "$payload"
}

# Only register on the first run of the day or if forced
# (For simplicity, we just register every time, it's idempotent)
register "CPU Usage"     "%"   "cpu-64-bit"        ""
register "RAM Usage"     "%"   "memory"            ""
register "Disk Usage"    "%"   "harddisk"          ""
register "Disk Free"     "GB"  "harddisk"          ""
register "CPU Temp"      "°C"  "thermometer"       "temperature"
register "Load 1m"       ""    "chart-line"        ""
register "Uptime"        ""    "clock-outline"     ""
register "IP Address"    ""    "ip-network"        ""
register "Network RX"    "KB/s" "download-network" ""
register "Network TX"    "KB/s" "upload-network"   ""
register "Process Count" ""    "format-list-numbered" ""

# ── Collect and publish metrics ──────────────────────────────────────────────
BASE="linux/${NODE_ID}"

# CPU (1-second sample)
CPU=$(top -bn2 | grep "Cpu(s)" | tail -1 \
      | awk '{print 100 - $8}' | xargs printf "%.1f")
pub -t "${BASE}/CPU_Usage"     -m "$CPU"

# RAM
RAM=$(free | awk '/^Mem:/ {printf "%.1f", $3/$2 * 100}')
pub -t "${BASE}/RAM_Usage"     -m "$RAM"

# Disk (root partition)
DISK_USE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
DISK_FREE=$(df -BG / | awk 'NR==2 {gsub("G",""); print $4}')
pub -t "${BASE}/Disk_Usage"    -m "$DISK_USE"
pub -t "${BASE}/Disk_Free"     -m "$DISK_FREE"

# CPU temp (lm-sensors or thermal zone fallback)
if command -v sensors &>/dev/null; then
  TEMP=$(sensors 2>/dev/null \
         | awk '/^(Package|Core 0|Tdie|Tctl)/{gsub(/[^0-9.]/,"",$2); print $2; exit}')
else
  TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null \
         | awk '{printf "%.1f", $1/1000}')
fi
pub -t "${BASE}/CPU_Temp"      -m "${TEMP:-0}"

# Load average (1m)
LOAD=$(cut -d' ' -f1 /proc/loadavg)
pub -t "${BASE}/Load_1m"       -m "$LOAD"

# Uptime (human-readable)
UPTIME=$(uptime -p | sed 's/^up //')
pub -t "${BASE}/Uptime"        -m "$UPTIME"

# IP (primary non-loopback)
IP=$(ip route get 1.1.1.1 2>/dev/null \
     | awk '/src/{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')
pub -t "${BASE}/IP_Address"    -m "${IP:-unknown}"

# Network RX/TX (delta over 1s on primary interface)
IFACE=$(ip route get 1.1.1.1 2>/dev/null \
        | awk '/dev/{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}')
if [[ -n "$IFACE" ]]; then
  RX1=$(cat "/sys/class/net/${IFACE}/statistics/rx_bytes" 2>/dev/null || echo 0)
  TX1=$(cat "/sys/class/net/${IFACE}/statistics/tx_bytes" 2>/dev/null || echo 0)
  sleep 1
  RX2=$(cat "/sys/class/net/${IFACE}/statistics/rx_bytes" 2>/dev/null || echo 0)
  TX2=$(cat "/sys/class/net/${IFACE}/statistics/tx_bytes" 2>/dev/null || echo 0)
  RX_KB=$(( (RX2 - RX1) / 1024 ))
  TX_KB=$(( (TX2 - TX1) / 1024 ))
  pub -t "${BASE}/Network_RX"    -m "$RX_KB"
  pub -t "${BASE}/Network_TX"    -m "$TX_KB"
fi

# Process count
PROCS=$(ps ax --no-header | wc -l)
pub -t "${BASE}/Process_Count" -m "$PROCS"
