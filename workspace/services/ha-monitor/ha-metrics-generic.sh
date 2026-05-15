#!/usr/bin/env bash
# Generic metrics collection logic using kernel interfaces (/proc, /sys)

get_cpu_usage() {
    local CPU_STATS=($(grep '^cpu ' /proc/stat))
    local IDLE1=${CPU_STATS[4]}
    local TOTAL1=0
    for i in "${CPU_STATS[@]:1:10}"; do TOTAL1=$((TOTAL1 + i)); done
    sleep 1
    local CPU_STATS2=($(grep '^cpu ' /proc/stat))
    local IDLE2=${CPU_STATS2[4]}
    local TOTAL2=0
    for i in "${CPU_STATS2[@]:1:10}"; do TOTAL2=$((TOTAL2 + i)); done
    local IDLE_DELTA=$((IDLE2 - IDLE1))
    local TOTAL_DELTA=$((TOTAL2 - TOTAL1))
    awk "BEGIN {printf \"%.1f\", 100 * (1 - $IDLE_DELTA / $TOTAL_DELTA)}"
}

get_ram_usage() {
    local MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local MEM_AVAIL=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    if [[ -z "$MEM_AVAIL" ]]; then
        local MEM_FREE=$(grep MemFree /proc/meminfo | awk '{print $2}')
        local MEM_BUFF=$(grep Buffers /proc/meminfo | awk '{print $2}')
        local MEM_CACH=$(grep ^Cached /proc/meminfo | awk '{print $2}')
        MEM_AVAIL=$((MEM_FREE + MEM_BUFF + MEM_CACH))
    fi
    awk "BEGIN {printf \"%.1f\", 100 * (1 - $MEM_AVAIL / $MEM_TOTAL)}"
}

get_disk_usage() {
    df / | awk 'NR==2 {print $5}' | tr -d '%'
}

get_disk_free() {
    df -BG / | awk 'NR==2 {gsub("G",""); print $4}'
}

get_cpu_temp() {
    local temp=0
    for zone in /sys/class/thermal/thermal_zone*; do
        if [[ -f "$zone/type" ]] && grep -qE "pkg_temp|package|cpu" "$zone/type" 2>/dev/null; then
            temp=$(cat "$zone/temp" 2>/dev/null)
            break
        fi
    done
    [[ "$temp" -eq 0 ]] && temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    printf "%.1f" "$(awk "BEGIN {print $temp / 1000}")" 2>/dev/null || echo "0.0"
}

get_load_1m() {
    cut -d' ' -f1 /proc/loadavg
}

get_uptime() {
    local UPTIME_SEC=$(cut -d' ' -f1 /proc/uptime | cut -d. -f1)
    local UPTIME_MIN=$((UPTIME_SEC / 60))
    local UPTIME_HRS=$((UPTIME_MIN / 60))
    local UPTIME_DAYS=$((UPTIME_HRS / 24))
    if [ "$UPTIME_DAYS" -gt 0 ]; then
        echo "$UPTIME_DAYS days, $((UPTIME_HRS % 24)) hours"
    else
        echo "$((UPTIME_HRS % 24)) hours, $((UPTIME_MIN % 60)) minutes"
    fi
}

get_ip_address() {
    ip route get 1.1.1.1 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}'
}

get_network_rx() {
    local iface=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}')
    [[ -z "$iface" ]] && echo "0" && return
    local rx1=$(grep "$iface" /proc/net/dev | tr ':' ' ' | awk '{print $2}')
    sleep 1
    local rx2=$(grep "$iface" /proc/net/dev | tr ':' ' ' | awk '{print $2}')
    echo "$(( (rx2 - rx1) / 1024 ))"
}

get_network_tx() {
    local iface=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}')
    [[ -z "$iface" ]] && echo "0" && return
    local tx1=$(grep "$iface" /proc/net/dev | tr ':' ' ' | awk '{print $10}')
    sleep 1
    local tx2=$(grep "$iface" /proc/net/dev | tr ':' ' ' | awk '{print $10}')
    echo "$(( (tx2 - tx1) / 1024 ))"
}

get_process_count() {
    find /proc -maxdepth 1 -name '[0-9]*' | wc -l
}

get_os_version() {
    grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"'
}

get_kernel_version() {
    uname -r
}
