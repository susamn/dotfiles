#!/usr/bin/env bash
# Push metrics to Home Assistant via MQTT
# Modular Orchestrator

export LC_NUMERIC=C
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Load configuration
CONFIG_FILE="$HOME/.config/ha-monitor/config"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

BROKER="${BROKER:-192.168.1.111}"
PORT="${PORT:-1883}"
USER="${USER:-linux-monitor}"
PASS="${PASS:-<password>}"
NODE_ID="${NODE_ID:-$(hostname)}"
DISCOVERY_PREFIX="${DISCOVERY_PREFIX:-homeassistant}"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

pub() {
    [[ "$PASS" == "<password>" ]] && { log "ERROR: Password not set"; return 1; }
    mosquitto_pub -h "$BROKER" -p "$PORT" -u "$USER" -P "$PASS" "$@"
}

# 2. Detect Platform and Load Platform-Specific Script
ID=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
ID_LIKE=$(grep ^ID_LIKE= /etc/os-release | cut -d= -f2 | tr -d '"')

PLATFORM_SCRIPT=""
if [[ -f "$SCRIPT_DIR/ha-metrics-${ID}.sh" ]]; then
    PLATFORM_SCRIPT="$SCRIPT_DIR/ha-metrics-${ID}.sh"
elif [[ -n "$ID_LIKE" ]]; then
    for LIKE in $ID_LIKE; do
        if [[ -f "$SCRIPT_DIR/ha-metrics-${LIKE}.sh" ]]; then
            PLATFORM_SCRIPT="$SCRIPT_DIR/ha-metrics-${LIKE}.sh"
            break
        fi
    done
fi

if [[ -n "$PLATFORM_SCRIPT" ]]; then
    log "Loading platform script: $(basename "$PLATFORM_SCRIPT")"
    source "$PLATFORM_SCRIPT"
else
    log "No platform script found for $ID ($ID_LIKE), using generic"
    source "$SCRIPT_DIR/ha-metrics-generic.sh"
fi

# 3. Registration Wrapper
register() {
    local name="$1" unit="$2" icon="$3" device_class="$4"
    local slug="${name// /_}"
    local topic="${DISCOVERY_PREFIX}/sensor/${NODE_ID}/${slug}/config"
    local payload="{\"name\":\"$name\",\"unique_id\":\"${NODE_ID}_${slug}\",\"state_topic\":\"linux/${NODE_ID}/${slug}\""
    [[ -n "$unit" ]] && payload+=",\"unit_of_measurement\":\"$unit\""
    [[ -n "$icon" ]] && payload+=",\"icon\":\"mdi:$icon\""
    [[ -n "$device_class" ]] && payload+=",\"device_class\":\"$device_class\""
    payload+=",\"device\":{\"identifiers\":[\"$NODE_ID\"],\"name\":\"$NODE_ID\",\"model\":\"Linux Server\"}}"
    pub -r -t "$topic" -m "$payload"
}

# 4. Collect and Publish
log "Collecting metrics..."

# Register all sensors
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

# Publish values
BASE="linux/${NODE_ID}"
pub -t "${BASE}/CPU_Usage"     -m "$(get_cpu_usage)"
pub -t "${BASE}/RAM_Usage"     -m "$(get_ram_usage)"
pub -t "${BASE}/Disk_Usage"    -m "$(get_disk_usage)"
pub -t "${BASE}/Disk_Free"     -m "$(get_disk_free)"
pub -t "${BASE}/CPU_Temp"      -m "$(get_cpu_temp)"
pub -t "${BASE}/Load_1m"       -m "$(get_load_1m)"
pub -t "${BASE}/Uptime"        -m "$(get_uptime)"
pub -t "${BASE}/IP_Address"    -m "$(get_ip_address)"
pub -t "${BASE}/Network_RX"    -m "$(get_network_rx)"
pub -t "${BASE}/Network_TX"    -m "$(get_network_tx)"
pub -t "${BASE}/Process_Count" -m "$(get_process_count)"
pub -t "${BASE}/OS_Version"    -m "$(get_os_version)"
pub -t "${BASE}/Kernel"        -m "$(get_kernel_version)"

log "Done."
