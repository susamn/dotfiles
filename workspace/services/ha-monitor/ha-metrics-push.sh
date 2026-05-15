#!/usr/bin/env bash
# Push metrics to Home Assistant via MQTT
# Enhanced for distro-independence and system metadata

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
    pub -r -t "$topic" -m "$payload"
}

# ── Collect metrics ─────────────────────────────────────────────────────────
log "Collecting metrics for $NODE_ID..."

# CPU Usage (Calculated from /proc/stat for distro-independence)
# Reads total and idle time, waits 1s, reads again, calculates delta.
CPU_STATS=($(grep '^cpu ' /proc/stat))
IDLE1=${CPU_STATS[4]}
TOTAL1=0
for i in "${CPU_STATS[@]:1:10}"; do TOTAL1=$((TOTAL1 + i)); done
sleep 1
CPU_STATS=($(grep '^cpu ' /proc/stat))
IDLE2=${CPU_STATS[4]}
TOTAL2=0
for i in "${CPU_STATS[@]:1:10}"; do TOTAL2=$((TOTAL2 + i)); done
IDLE_DELTA=$((IDLE2 - IDLE1))
TOTAL_DELTA=$((TOTAL2 - TOTAL1))
CPU_PCT=$(awk "BEGIN {printf \"%.1f\", 100 * (1 - $IDLE_DELTA / $TOTAL_DELTA)}")

# RAM Usage (From /proc/meminfo)
MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_AVAIL=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
# Fallback for older kernels without MemAvailable
if [[ -z "$MEM_AVAIL" ]]; then
    MEM_FREE=$(grep MemFree /proc/meminfo | awk '{print $2}')
    MEM_BUFF=$(grep Buffers /proc/meminfo | awk '{print $2}')
    MEM_CACH=$(grep ^Cached /proc/meminfo | awk '{print $2}')
    MEM_AVAIL=$((MEM_FREE + MEM_BUFF + MEM_CACH))
fi
RAM_PCT=$(awk "BEGIN {printf \"%.1f\", 100 * (1 - $MEM_AVAIL / $MEM_TOTAL)}")

# Disk (From df, which is ubiquitous)
DISK_USE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
DISK_FREE=$(df -BG / | awk 'NR==2 {gsub("G",""); print $4}')

# CPU Temp (Thermal zones are standard in /sys/class/thermal)
TEMP=0
for zone in /sys/class/thermal/thermal_zone*; do
    if [[ -f "$zone/type" ]] && grep -qE "pkg_temp|package|cpu" "$zone/type" 2>/dev/null; then
        TEMP=$(cat "$zone/temp" 2>/dev/null)
        break
    fi
done
# Fallback to zone 0 if no specific cpu zone found
[[ "$TEMP" -eq 0 ]] && TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
TEMP=$(printf "%.1f" "$(awk "BEGIN {print $TEMP / 1000}")" 2>/dev/null || echo "0.0")

# Load average (From /proc/loadavg)
LOAD=$(cut -d' ' -f1 /proc/loadavg)

# Uptime (From /proc/uptime)
UPTIME_SEC=$(cut -d' ' -f1 /proc/uptime | cut -d. -f1)
UPTIME_MIN=$((UPTIME_SEC / 60))
UPTIME_HRS=$((UPTIME_MIN / 60))
UPTIME_DAYS=$((UPTIME_HRS / 24))
if [ "$UPTIME_DAYS" -gt 0 ]; then
    UPTIME_STR="$UPTIME_DAYS days, $((UPTIME_HRS % 24)) hours"
else
    UPTIME_STR="$((UPTIME_HRS % 24)) hours, $((UPTIME_MIN % 60)) minutes"
fi

# IP (primary non-loopback)
IP=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')

# Network RX/TX (From /proc/net/dev)
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}')
RX_KB=0
TX_KB=0
if [[ -n "$IFACE" ]]; then
    NET_STATS1=($(grep "$IFACE" /proc/net/dev | tr ':' ' '))
    RX1=${NET_STATS1[1]}
    TX1=${NET_STATS1[9]}
    sleep 1
    NET_STATS2=($(grep "$IFACE" /proc/net/dev | tr ':' ' '))
    RX2=${NET_STATS2[1]}
    TX2=${NET_STATS2[9]}
    RX_KB=$(( (RX2 - RX1) / 1024 ))
    TX_KB=$(( (TX2 - TX1) / 1024 ))
fi

# Process count (Count /proc entries)
PROCS=$(find /proc -maxdepth 1 -name '[0-9]*' | wc -l)

# Distribution and Kernel
DISTRO=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
KERNEL=$(uname -r)

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
register "OS Version"    ""    "linux"             ""
register "Kernel"        ""    "identifier"        ""

BASE="linux/${NODE_ID}"
pub -t "${BASE}/CPU_Usage"     -m "$CPU_PCT"
pub -t "${BASE}/RAM_Usage"     -m "$RAM_PCT"
pub -t "${BASE}/Disk_Usage"    -m "$DISK_USE"
pub -t "${BASE}/Disk_Free"     -m "$DISK_FREE"
pub -t "${BASE}/CPU_Temp"      -m "$TEMP"
pub -t "${BASE}/Load_1m"       -m "$LOAD"
pub -t "${BASE}/Uptime"        -m "$UPTIME_STR"
pub -t "${BASE}/IP_Address"    -m "${IP:-unknown}"
pub -t "${BASE}/Network_RX"    -m "$RX_KB"
pub -t "${BASE}/Network_TX"    -m "$TX_KB"
pub -t "${BASE}/Process_Count" -m "$PROCS"
pub -t "${BASE}/OS_Version"    -m "$DISTRO"
pub -t "${BASE}/Kernel"        -m "$KERNEL"

log "Done."
