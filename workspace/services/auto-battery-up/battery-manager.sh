#!/usr/bin/env bash

# Battery Manager - Auto control battery charger via Home Assistant
# Monitors battery level and controls charger switch when battery < 20% or > 80%

set -uo pipefail

# Configuration - Set defaults that can be overridden in config file
CONFIG_FILE="${CONFIG_FILE:-$HOME/.config/battery-manager/config}"

# Default values (can be overridden in config file)
BATTERY_LOW_THRESHOLD="${BATTERY_LOW_THRESHOLD:-20}"
BATTERY_HIGH_THRESHOLD="${BATTERY_HIGH_THRESHOLD:-80}"
LOG_FILE="${LOG_FILE:-/var/log/battery-manager.log}"
HA_URL="${HA_URL:-http://homeassistant.local:8123}"
HA_TOKEN="${HA_TOKEN:-}"
HA_SWITCH_ENTITY="${HA_SWITCH_ENTITY:-switch.battery_charger}"

# Load configuration from file if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Create log directory if it doesn't exist
LOG_DIR="$(dirname "$LOG_FILE")"
if [[ ! -d "$LOG_DIR" ]]; then
    mkdir -p "$LOG_DIR" 2>/dev/null || {
        # If we can't create the log directory, fall back to a temp location
        LOG_FILE="/tmp/battery-manager.log"
    }
fi

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local log_line="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"

    # Try to write to log file, but don't fail if we can't
    echo "$log_line" | tee -a "$LOG_FILE" 2>/dev/null || echo "$log_line"
}

# Get current battery level
get_battery_level() {
    local battery_path="/sys/class/power_supply/BAT0/capacity"

    if [[ ! -f "$battery_path" ]]; then
        # Try BAT1
        battery_path="/sys/class/power_supply/BAT1/capacity"
        if [[ ! -f "$battery_path" ]]; then
            log "ERROR" "Battery not found"
            return 1
        fi
    fi

    cat "$battery_path"
}

# Get battery charging status
get_charging_status() {
    local status_path="/sys/class/power_supply/BAT0/status"

    if [[ ! -f "$status_path" ]]; then
        status_path="/sys/class/power_supply/BAT1/status"
        if [[ ! -f "$status_path" ]]; then
            log "ERROR" "Battery status not found"
            return 1
        fi
    fi

    cat "$status_path"
}

# Call Home Assistant API
call_ha_api() {
    local service="$1"
    local entity_id="$2"

    if [[ -z "$HA_TOKEN" ]]; then
        log "ERROR" "Home Assistant token not configured"
        return 1
    fi

    local response
    local http_code

    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: Bearer $HA_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"entity_id\": \"$entity_id\"}" \
        --connect-timeout 5 \
        --max-time 10 \
        "$HA_URL/api/services/$service" 2>&1) || {
        log "WARN" "Failed to connect to Home Assistant at $HA_URL"
        return 1
    }

    http_code=$(echo "$response" | tail -n 1)

    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        log "INFO" "Successfully called Home Assistant service: $service for $entity_id (HTTP $http_code)"
        return 0
    else
        log "WARN" "Home Assistant API call failed: HTTP $http_code"
        return 1
    fi
}

# Turn on the charger switch
turn_on_charger() {
    log "INFO" "Attempting to turn ON charger"
    call_ha_api "switch/turn_on" "$HA_SWITCH_ENTITY"
}

# Turn off the charger switch
turn_off_charger() {
    log "INFO" "Attempting to turn OFF charger"
    call_ha_api "switch/turn_off" "$HA_SWITCH_ENTITY"
}

# Main logic
main() {
    log "INFO" "Battery manager started"

    # Get battery level
    local battery_level
    if ! battery_level=$(get_battery_level); then
        log "ERROR" "Failed to read battery level, exiting"
        exit 0  # Exit gracefully, don't fail the service
    fi

    # Validate battery level is numeric
    if ! [[ "$battery_level" =~ ^[0-9]+$ ]]; then
        log "ERROR" "Battery level is not numeric: '$battery_level', exiting"
        exit 0
    fi

    log "INFO" "Current battery level: ${battery_level}%"

    # Get charging status
    local charging_status
    if charging_status=$(get_charging_status); then
        log "INFO" "Charging status: $charging_status"
    fi

    # Decision logic with hysteresis:
    # - Battery ≤ LOW: Turn ON charger (will charge up to HIGH)
    # - Battery ≥ HIGH: Turn OFF charger (will discharge down to LOW)
    # - LOW < Battery < HIGH: Maintain current state
    #   - If charging: keep charging until HIGH
    #   - If not charging: keep off until LOW

    if [[ "$battery_level" -le "$BATTERY_LOW_THRESHOLD" ]]; then
        # Battery is low - turn on charger
        log "INFO" "Battery level (${battery_level}%) is at or below low threshold (${BATTERY_LOW_THRESHOLD}%)"
        turn_on_charger || log "WARN" "Could not turn on charger, will retry next cycle"
    elif [[ "$battery_level" -ge "$BATTERY_HIGH_THRESHOLD" ]]; then
        # Battery is high - turn off charger
        log "INFO" "Battery level (${battery_level}%) is at or above high threshold (${BATTERY_HIGH_THRESHOLD}%)"
        turn_off_charger || log "WARN" "Could not turn off charger, will retry next cycle"
    else
        # Battery is in middle range - maintain current charging state
        log "INFO" "Battery level (${battery_level}%) is within range (${BATTERY_LOW_THRESHOLD}%-${BATTERY_HIGH_THRESHOLD}%)"
        if [[ -n "$charging_status" && "$charging_status" == "Charging" ]]; then
            log "INFO" "Currently charging, will continue until ${BATTERY_HIGH_THRESHOLD}%"
        else
            log "INFO" "Not charging, will wait until battery drops to ${BATTERY_LOW_THRESHOLD}%"
        fi
    fi

    log "INFO" "Battery manager completed"
}

# Run main function
main
