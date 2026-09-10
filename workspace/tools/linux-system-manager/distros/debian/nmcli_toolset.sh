#!/bin/bash
set -euo pipefail

# NetworkManager (nmcli) Toolset
#
# A discoverable index of the network-diagnostic commands worth knowing. Every
# action prints the exact command before running it -- that is the point of this
# section. The output is available from a dozen other places; what this teaches
# is the invocation, so the user can run it directly next time without the menu.
#
# Actions are read-only diagnostics unless labelled [modifies system]. Commands
# needing root carry a visible `sudo` in the displayed string rather than
# escalating invisibly, so what is shown is exactly what runs.
#
# Distro-blind: nmcli, ip, ss and resolvectl behave identically across distros,
# so this file is byte-identical in every distros/<id>/ directory and is pinned
# that way by TestDistroParity.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'
CLR='\033[H\033[2J'

log_info()  { echo -e "${BLUE}ℹ${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}⚠${NC}  $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

usage() {
    cat <<'EOF'
usage: nmcli_toolset.sh [--help]

Interactive NetworkManager / network diagnostics menu. Every action displays the
command it runs before running it.

Categories: interfaces, connection profiles, IP configuration, Wi-Fi, DNS,
connectivity and routing, firewall and ports, NetworkManager service.
EOF
}

# Parsed before anything else touches the environment: CI runs this with `env -i`
# to prove the script survives a minimal environment.
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

pause() { echo ""; read -rp "Press ENTER to continue..." _ || true; }

# ── the core contract: show, then run ────────────────────────────────────────
# Diagnostics fail routinely and informatively -- ping cannot reach a host, nft
# needs root, a device has no IPv6. A non-zero exit is a result to report, never
# a reason to tear down the menu, so the status is surfaced and the loop lives.
show_and_run() {
    local cmd="$1"
    echo ""
    echo -e "${BLUE}──────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}Command:${NC} ${YELLOW}${cmd}${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────────────────────${NC}"
    echo ""
    local rc=0
    eval "$cmd" || rc=$?
    if [[ $rc -ne 0 ]]; then
        echo ""
        log_warn "Command exited with status ${rc}."
    fi
}

# ── argument placeholders ────────────────────────────────────────────────────
# A command string may carry @DEV@, @CON@ or @HOST@. These are resolved before
# the command is displayed, so the string shown is exactly the string executed --
# a display built from the template rather than the resolved command would be a
# lie the user might copy.
pick_from() {
    local title="$1"; shift
    local -a items=("$@")
    if [[ ${#items[@]} -eq 0 ]]; then
        log_error "Nothing to choose from."
        return 1
    fi
    echo "" >&2
    echo -e "${CYAN}${title}${NC}" >&2
    local i
    for i in "${!items[@]}"; do
        echo -e "  ${GREEN}$((i + 1))${NC}) ${items[$i]}" >&2
    done
    echo -e "  ${RED}0${NC}) Cancel" >&2
    echo "" >&2
    local choice
    read -rp "Select (0-${#items[@]}): " choice >&2 || return 1
    [[ "$choice" =~ ^[0-9]+$ ]] || return 1
    [[ "$choice" -ge 1 && "$choice" -le ${#items[@]} ]] || return 1
    printf '%s' "${items[$((choice - 1))]}"
}

list_devices() {
    nmcli -t -f DEVICE device status 2>/dev/null | grep -v '^lo$' || true
}

list_connections() {
    nmcli -t -f NAME connection show 2>/dev/null || true
}

resolve_args() {
    local cmd="$1" val
    if [[ "$cmd" == *"@DEV@"* ]]; then
        local -a devs=()
        while IFS= read -r d; do [[ -n "$d" ]] && devs+=("$d"); done < <(list_devices)
        if [[ ${#devs[@]} -eq 0 ]]; then
            log_error "No devices found. Is NetworkManager running?" >&2
            return 1
        fi
        val=$(pick_from "Select a device:" "${devs[@]}") || return 1
        [[ -n "$val" ]] || return 1
        cmd="${cmd//@DEV@/$val}"
    fi
    if [[ "$cmd" == *"@CON@"* ]]; then
        local -a cons=()
        while IFS= read -r c; do [[ -n "$c" ]] && cons+=("$c"); done < <(list_connections)
        if [[ ${#cons[@]} -eq 0 ]]; then
            log_error "No connection profiles found." >&2
            return 1
        fi
        val=$(pick_from "Select a connection profile:" "${cons[@]}") || return 1
        [[ -n "$val" ]] || return 1
        # Quoted: profile names routinely contain spaces ("Wired connection 1").
        cmd="${cmd//@CON@/\"$val\"}"
    fi
    if [[ "$cmd" == *"@HOST@"* ]]; then
        echo "" >&2
        read -rp "Host or IP (blank to cancel): " val >&2 || return 1
        [[ -n "$val" ]] || return 1
        cmd="${cmd//@HOST@/$val}"
    fi
    printf '%s' "$cmd"
}

# ── generic category menu ────────────────────────────────────────────────────
# Categories fill LABELS and CMDS, then call run_menu. Keeping one loop means
# one place where argument resolution, command display and error handling live.
LABELS=()
CMDS=()

run_menu() {
    local title="$1"
    while true; do
        echo -e "$CLR"
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
        printf "${CYAN}║${NC}  %-58s${CYAN}║${NC}\n" "$title"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        local i
        for i in "${!LABELS[@]}"; do
            printf "  ${GREEN}%2d${NC})  %b\n" "$((i + 1))" "${LABELS[$i]}"
        done
        echo ""
        echo -e "   ${RED}0${NC})  Back"
        echo ""
        local choice
        read -rp "Select (0-${#LABELS[@]}): " choice || return 0
        [[ "$choice" == "0" ]] && return 0
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#LABELS[@]} ]]; then
            log_error "Invalid option: $choice"
            sleep 1
            continue
        fi
        local cmd="${CMDS[$((choice - 1))]}"
        local resolved
        if resolved=$(resolve_args "$cmd"); then
            show_and_run "$resolved"
        else
            echo ""
            log_info "Cancelled."
        fi
        pause
    done
}

# ── 1. interfaces and devices ────────────────────────────────────────────────
menu_interfaces() {
    LABELS=(
        "Device status overview          ${DIM}all NICs, type, state, profile${NC}"
        "Device detail (pick one)        ${DIM}full nmcli property dump${NC}"
        "Every device property           ${DIM}-f all, includes capabilities${NC}"
        "Kernel link state               ${DIM}up/down, MAC, MTU${NC}"
        "Interface counters              ${DIM}rx/tx bytes, errors, drops${NC}"
        "Wired carrier detail            ${DIM}link negotiation per device${NC}"
    )
    CMDS=(
        "nmcli device status"
        "nmcli device show @DEV@"
        "nmcli -f all device show @DEV@"
        "ip -c link show"
        "ip -s -c link show"
        "nmcli -f GENERAL,WIRED-PROPERTIES device show @DEV@"
    )
    run_menu "1. Interfaces & Devices"
}

# ── 2. connection profiles ───────────────────────────────────────────────────
menu_profiles() {
    LABELS=(
        "All saved profiles              ${DIM}name, uuid, type, device${NC}"
        "Active profiles only"
        "Profile detail (pick one)       ${DIM}every configured property${NC}"
        "Profile detail with secrets     ${DIM}sudo — reveals PSK/passwords${NC}"
        "Autoconnect settings            ${DIM}which profiles come up on boot${NC}"
        "Profile files on disk           ${DIM}sudo — /etc/NetworkManager${NC}"
    )
    CMDS=(
        "nmcli connection show"
        "nmcli connection show --active"
        "nmcli connection show @CON@"
        "sudo nmcli --show-secrets connection show @CON@"
        "nmcli -f NAME,TYPE,AUTOCONNECT,AUTOCONNECT-PRIORITY connection show"
        "sudo ls -l /etc/NetworkManager/system-connections/"
    )
    run_menu "2. Connection Profiles"
}

# ── 3. IP configuration ──────────────────────────────────────────────────────
menu_ipconfig() {
    LABELS=(
        "IPv4 addresses"
        "IPv6 addresses"
        "IPv4 config per device          ${DIM}address, gateway, DNS, routes${NC}"
        "IPv6 config per device"
        "DHCPv4 lease options            ${DIM}what the server actually sent${NC}"
        "Static vs automatic (profile)   ${DIM}ipv4.method and friends${NC}"
        "Addresses with scope + lifetime ${DIM}spot temporary/deprecated v6${NC}"
    )
    CMDS=(
        "ip -4 -c addr show"
        "ip -6 -c addr show"
        "nmcli -f IP4 device show @DEV@"
        "nmcli -f IP6 device show @DEV@"
        "nmcli -f DHCP4 device show @DEV@"
        "nmcli -f ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,ipv6.method connection show @CON@"
        "ip -c -d addr show"
    )
    run_menu "3. IP Configuration"
}

# ── 4. Wi-Fi ─────────────────────────────────────────────────────────────────
menu_wifi() {
    LABELS=(
        "Radio status                    ${DIM}wifi/wwan enabled or blocked${NC}"
        "Scan for networks               ${DIM}forces a fresh rescan${NC}"
        "Nearby networks, full detail    ${DIM}security, channel, rate${NC}"
        "Current link quality            ${DIM}signal, bitrate, frequency${NC}"
        "Access point in use             ${DIM}which BSSID is connected${NC}"
        "Saved Wi-Fi password            ${DIM}sudo — PSK for a profile${NC}"
        "Enable Wi-Fi radio              ${YELLOW}[modifies system]${NC}"
        "Disable Wi-Fi radio             ${YELLOW}[modifies system]${NC}"
    )
    CMDS=(
        "nmcli radio all"
        "nmcli device wifi list --rescan yes"
        "nmcli -f ALL device wifi list"
        "iw dev @DEV@ link"
        "nmcli -f ACTIVE,SSID,BSSID,CHAN,RATE,SIGNAL,SECURITY device wifi list"
        "sudo nmcli --show-secrets -f 802-11-wireless-security.psk connection show @CON@"
        "nmcli radio wifi on"
        "nmcli radio wifi off"
    )
    run_menu "4. Wi-Fi"
}

# ── 5. DNS ───────────────────────────────────────────────────────────────────
menu_dns() {
    LABELS=(
        "DNS servers per device          ${DIM}what NetworkManager handed over${NC}"
        "Resolver status                 ${DIM}systemd-resolved, per-link${NC}"
        "Effective resolv.conf           ${DIM}what libc actually reads${NC}"
        "Resolve a hostname"
        "Full dig lookup                 ${DIM}answer, authority, timing${NC}"
        "Delegation trace                ${DIM}dig +trace, root to answer${NC}"
        "Reverse lookup"
        "DNS over a specific server      ${DIM}bypass the local resolver${NC}"
    )
    local resolve_cmd="getent hosts @HOST@"
    command -v resolvectl >/dev/null 2>&1 && resolve_cmd="resolvectl query @HOST@"
    local status_cmd="cat /etc/resolv.conf"
    command -v resolvectl >/dev/null 2>&1 && status_cmd="resolvectl status"
    CMDS=(
        "nmcli -f IP4.DNS,IP6.DNS,IP4.DOMAIN device show"
        "$status_cmd"
        "cat /etc/resolv.conf"
        "$resolve_cmd"
        "dig @HOST@"
        "dig +trace @HOST@"
        "dig -x @HOST@"
        "dig @8.8.8.8 @HOST@"
    )
    run_menu "5. DNS"
}

# ── 6. connectivity and routing ──────────────────────────────────────────────
menu_connectivity() {
    # Whichever path tool exists. tracepath needs no root and ships with
    # iputils, so it is the most commonly present of the three.
    local trace="tracepath @HOST@"
    if command -v mtr >/dev/null 2>&1; then
        trace="mtr --report --report-cycles 10 @HOST@"
    elif command -v traceroute >/dev/null 2>&1; then
        trace="traceroute @HOST@"
    elif ! command -v tracepath >/dev/null 2>&1; then
        trace=""
    fi

    LABELS=(
        "NetworkManager connectivity     ${DIM}full / limited / portal / none${NC}"
        "Routing table"
        "IPv6 routing table"
        "Route to a destination          ${DIM}which route the kernel picks${NC}"
        "ARP / neighbour table"
        "Ping a host"
        "Ping continuously               ${DIM}Ctrl+C to stop${NC}"
    )
    CMDS=(
        "nmcli networking connectivity check"
        "ip -c route show"
        "ip -6 -c route show"
        "ip route get @HOST@"
        "ip -c neigh show"
        "ping -c 4 @HOST@"
        "ping @HOST@"
    )
    if [[ -n "$trace" ]]; then
        LABELS+=("Trace path to a host            ${DIM}${trace%% *}${NC}")
        CMDS+=("$trace")
    else
        LABELS+=("Trace path to a host            ${RED}unavailable${NC}${DIM} — install mtr or traceroute${NC}")
        CMDS+=("echo 'No path-tracing tool found. Install one of: mtr, traceroute, iputils (tracepath).'")
    fi
    run_menu "6. Connectivity & Routing"
}

# ── 7. firewall and ports ────────────────────────────────────────────────────
# Only backends actually present are listed: offering `firewall-cmd` on a box
# running nftables produces a command-not-found the user has to decode.
menu_firewall() {
    LABELS=(
        "Listening sockets               ${DIM}sudo — with owning process${NC}"
        "Established connections"
        "Socket summary                  ${DIM}counts by protocol and state${NC}"
    )
    CMDS=(
        "sudo ss -tulpn"
        "ss -tup state established"
        "ss -s"
    )
    if command -v nft >/dev/null 2>&1; then
        LABELS+=("nftables ruleset                ${DIM}sudo${NC}")
        CMDS+=("sudo nft list ruleset")
    fi
    if command -v iptables >/dev/null 2>&1; then
        LABELS+=("iptables rules                  ${DIM}sudo — with counters${NC}")
        CMDS+=("sudo iptables -L -n -v")
    fi
    if command -v ufw >/dev/null 2>&1; then
        LABELS+=("ufw status                      ${DIM}sudo${NC}")
        CMDS+=("sudo ufw status verbose")
    fi
    if command -v firewall-cmd >/dev/null 2>&1; then
        LABELS+=("firewalld zones                 ${DIM}sudo${NC}")
        CMDS+=("sudo firewall-cmd --list-all")
    fi
    run_menu "7. Firewall & Ports"
}

# ── 8. NetworkManager service ────────────────────────────────────────────────
menu_general() {
    LABELS=(
        "General status                  ${DIM}state, connectivity, wifi radio${NC}"
        "Hostname"
        "Caller permissions              ${DIM}what this user may change${NC}"
        "Logging level and domains"
        "Service status"
        "Recent service logs             ${DIM}last 50 journal lines${NC}"
        "Watch events live               ${DIM}Ctrl+C to stop${NC}"
        "Device connect/disconnect log   ${DIM}filtered journal${NC}"
    )
    CMDS=(
        "nmcli general status"
        "nmcli general hostname"
        "nmcli general permissions"
        "nmcli general logging"
        "systemctl status NetworkManager --no-pager"
        "journalctl -u NetworkManager -n 50 --no-pager"
        "nmcli monitor"
        "journalctl -u NetworkManager -n 100 --no-pager | grep -Ei 'device .* state change|carrier'"
    )
    run_menu "8. NetworkManager Service"
}

# ── entry ────────────────────────────────────────────────────────────────────
preflight() {
    if ! command -v nmcli >/dev/null 2>&1; then
        log_error "nmcli not found. This section needs NetworkManager installed."
        log_info "Sections 6 and 7 (routing, firewall) still work without it;"
        log_info "the nmcli-specific ones will not."
        pause
        return 0
    fi
    if ! systemctl is-active --quiet NetworkManager 2>/dev/null; then
        log_warn "NetworkManager is installed but not active."
        log_info "This machine may be using systemd-networkd or iwd instead."
        log_info "nmcli actions will report no devices until it is running."
        pause
    fi
}

main() {
    preflight
    local -a titles=(
        "Interfaces & Devices            ${DIM}status, link state, counters${NC}"
        "Connection Profiles             ${DIM}saved connections and secrets${NC}"
        "IP Configuration                ${DIM}addresses, DHCP, static vs auto${NC}"
        "Wi-Fi                           ${DIM}scan, signal, radio, passwords${NC}"
        "DNS                             ${DIM}resolvers, lookups, delegation${NC}"
        "Connectivity & Routing          ${DIM}reachability, routes, path trace${NC}"
        "Firewall & Ports                ${DIM}listening sockets, rulesets${NC}"
        "NetworkManager Service          ${DIM}state, permissions, logs${NC}"
    )
    while true; do
        echo -e "$CLR"
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}NetworkManager (nmcli) Toolset${NC}                            ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${DIM}Every action prints the command it runs before running it.${NC}"
        echo ""
        local i
        for i in "${!titles[@]}"; do
            printf "  ${GREEN}%d${NC})  %b\n" "$((i + 1))" "${titles[$i]}"
        done
        echo ""
        echo -e "  ${RED}0${NC})  Back"
        echo ""
        local choice
        read -rp "Select a category (0-${#titles[@]}): " choice || break
        case "$choice" in
            1) menu_interfaces ;;
            2) menu_profiles ;;
            3) menu_ipconfig ;;
            4) menu_wifi ;;
            5) menu_dns ;;
            6) menu_connectivity ;;
            7) menu_firewall ;;
            8) menu_general ;;
            0) break ;;
            *) log_error "Invalid option: $choice"; sleep 1 ;;
        esac
    done
}

main
