#!/usr/bin/env bash
# Push metrics to Home Assistant via MQTT
# Refactored for robustness and better discovery handling

# Force numeric locale to ensure consistent awk/printf behavior
export LC_NUMERIC=C

# Load configuration
CONFIG_DIR="$HOME/.config/ha-monitor"
CONFIG_FILE="$CONFIG_DIR/config"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Defaults
BROKER="${BROKER:-192.168.1.111}"
PORT="${PORT:-1883}"
USER="${USER:-linux-monitor}"
PASS="${PASS:-<password>}"
NODE_ID="${NODE_ID:-$(hostname)}"
DISCOVERY_PREFIX="${DISCOVERY_PREFIX:-homeassistant}"

# Logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# MQTT Publish
pub() {
    if [[ "$PASS" == "<password>" ]]; then
        log "ERROR: Password not configured in $CONFIG_FILE"
        return 1
    fi
    mosquitto_pub -h "$BROKER" -p "$PORT" -u "$USER" -P "$PASS" "$@"
}

# ── Register sensors via MQTT Discovery (run once, idempotent) ──────────────
register() {
    local name="$1" unit="$2" icon="$3" device_class="$4"
    local slug="${name// /_}"
    local topic="${DISCOVERY_PREFIX}/sensor/${NODE_ID}/${slug}/config"
    
    # Build JSON payload manually to omit empty fields
    local payload="{"
    payload+="\"name\": \"$name\","
    payload+="\"unique_id\": \"${NODE_ID}_${slug}\","
    payload+="\"state_topic\": \"linux/${NODE_ID}/${slug}\","
    [[ -n "$unit" ]] && payload+="\"unit_of_measurement\": \"$unit\","
    [[ -n "$icon" ]] && payload+="\"icon\": \"mdi:$icon\","
    [[ -n "$device_class" ]] && payload+="\"device_class\": \"$device_class\","
    payload+="\"device\": {"
    payload+="\"identifiers\": [\"$NODE_ID\"],"
    payload+="\"name\": \"$NODE_ID\","
    payload+="\"model\": \"Linux Server\""
    payload+="}"
    payload+="}"

    log "Registering sensor: $name ($slug)"
    if ! pub -r -t "$topic" -m "$payload"; then
        log "ERROR: Failed to register $name"
    fi
}

# ── Collect metrics ─────────────────────────────────────────────────────────
log "Collecting metrics for $NODE_ID..."

# CPU (1-second sample)
CPU=$(top -bn2 | grep "Cpu(s)" | tail -1 | awk '{print 100 - $8}')
CPU=$(printf "%.1f" "$CPU" 2>/dev/null || echo "0.0")

# RAM
RAM=$(free | awk '/^Mem:/ {print $3/$2 * 100}')
RAM=$(printf "%.1f" "$RAM" 2>/dev/null || echo "0.0")

# Disk (root partition)
DISK_USE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
DISK_FREE=$(df -BG / | awk 'NR==2 {gsub("G",""); print $4}')

# CPU temp
if command -v sensors &>/dev/null; then
    TEMP=$(sensors 2>/dev/null | awk '/^(Package|Core 0|Tdie|Tctl)/{gsub(/[^0-9.]/,"",$2); print $2; exit}')
else
    TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000}')
fi
TEMP=$(printf "%.1f" "${TEMP:-0}" 2>/dev/null || echo "0.0")

# Load average (1m)
LOAD=$(cut -d' ' -f1 /proc/loadavg)

# Uptime
UPTIME=$(uptime -p | sed 's/^up //')

# IP
IP=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')

# Network
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}')
RX_KB=0
TX_KB=0
if [[ -n "$IFACE" ]]; then
    RX1=$(cat "/sys/class/net/${IFACE}/statistics/rx_bytes" 2>/dev/null || echo 0)
    TX1=$(cat "/sys/class/net/${IFACE}/statistics/tx_bytes" 2>/dev/null || echo 0)
    sleep 1
    RX2=$(cat "/sys/class/net/${IFACE}/statistics/rx_bytes" 2>/dev/null || echo 0)
    TX2=$(cat "/sys/class/net/${IFACE}/statistics/tx_bytes" 2>/dev/null || echo 0)
    RX_KB=$(( (RX2 - RX1) / 1024 ))
    TX_KB=$(( (TX2 - TX1) / 1024 ))
fi

# Process count
PROCS=$(ps ax --no-header | wc -l)

# ── Register and Publish ───────────────────────────────────────────────────
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

BASE="linux/${NODE_ID}"
pub -t "${BASE}/CPU_Usage"     -m "$CPU"
pub -t "${BASE}/RAM_Usage"     -m "$RAM"
pub -t "${BASE}/Disk_Usage"    -m "$DISK_USE"
pub -t "${BASE}/Disk_Free"     -m "$DISK_FREE"
pub -t "${BASE}/CPU_Temp"      -m "$TEMP"
pub -t "${BASE}/Load_1m"       -m "$LOAD"
pub -t "${BASE}/Uptime"        -m "$UPTIME"
pub -t "${BASE}/IP_Address"    -m "${IP:-unknown}"
pub -t "${BASE}/Network_RX"    -m "$RX_KB"
pub -t "${BASE}/Network_TX"    -m "$TX_KB"
pub -t "${BASE}/Process_Count" -m "$PROCS"

log "Done."
