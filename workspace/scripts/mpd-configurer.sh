#!/usr/bin/env bash
# mpd-configurer.sh — generates/updates ~/.config/mpd/mpd.conf from a
# hand-maintained ~/.config/mpd/mpd.conf.bak template (kept in version
# control) plus two rclone-sync profiles (picked interactively via fzf, or
# typed if fzf isn't available): only music_directory/playlist_directory get
# overwritten, everything else in the template is kept as-is. Also manages
# the mpd user daemon and queries it for tracks/playlists/stats via mpc.
#
# Visual style matches linux-system-manager.sh (same palette/header/icons) —
# single flat script, no menu engine.
set -euo pipefail

PROFILES_DIR="$HOME/.config/rclone-sync-profiles"
MPD_DIR="$HOME/.config/mpd"
MPD_CONF="$MPD_DIR/mpd.conf"

# --- Palette (matches linux-system-manager.sh) ---
# $'...' (ANSI-C quoting) so \033 is a real escape byte in the variable
# itself — needed for plain `cat`/heredocs, not just `echo -e`.
BOLD=$'\033[1m'
DIM=$'\033[2m'
PRIMARY=$'\033[38;5;39m'   # Cyan Blue
SUCCESS=$'\033[38;5;82m'   # Vivid Green
WARNING=$'\033[38;5;214m'  # Amber / Orange
DANGER=$'\033[38;5;196m'   # Bright Red
INFO=$'\033[38;5;75m'      # Soft Blue
ACCENT=$'\033[38;5;171m'   # Vibrant Purple / Magenta
NC=$'\033[0m'

hr() {
    local n="$1" ch="${2:-─}" out="" i
    for (( i = 0; i < n; i++ )); do out+="$ch"; done
    printf '%s' "$out"
}

print_header() {
    local title="$1" width=62
    local inner=$(( width - 2 ))
    local padded=" $title "
    local pad_total=$(( inner - ${#padded} ))
    local pad_left=$(( pad_total / 2 ))
    local pad_right=$(( pad_total - pad_left ))
    echo -e "${PRIMARY}╭$(hr "$inner")╮${NC}"
    echo -e "${PRIMARY}│${NC}$(printf '%*s' "$pad_left" '')${BOLD}${ACCENT}${padded}${NC}$(printf '%*s' "$pad_right" '')${PRIMARY}│${NC}"
    echo -e "${PRIMARY}╰$(hr "$inner")╯${NC}"
    echo
}

ok()   { echo -e "${SUCCESS}✓ $*${NC}"; }
err()  { echo -e "${DANGER}✗ $*${NC}" >&2; }
warn() { echo -e "${WARNING}⚠ $*${NC}"; }
info() { echo -e "${INFO}ℹ $*${NC}"; }

FZF_COLOR="fg:#c9d1d9,bg:-1,hl:#ea9d34,fg+:#ffffff,bg+:-1,hl+:#ea9d34,info:#7b6ca6,prompt:#a899d9,pointer:#ea9d34,marker:#8fbf7a,header:#5c6370"

profile_field() {
    local profile="$1"
    local key="$2"
    local file="$PROFILES_DIR/${profile}.conf"
    if [[ ! -f "$file" ]]; then
        err "Profile not found: $file"
        exit 1
    fi
    grep -E "^${key}=" "$file" | head -1 | sed -E "s/^${key}=\"?([^\"]*)\"?.*/\1/"
}

list_profiles() {
    [[ -d "$PROFILES_DIR" ]] || return 0
    local f
    for f in "$PROFILES_DIR"/*.conf; do
        [[ -e "$f" ]] || continue
        basename "$f" .conf
    done
}

# Interactively resolves a profile name: fzf-picks from what's installed if
# fzf is available, otherwise prompts to type one — either way, the result
# is verified to actually exist before being returned.
select_profile() {
    local prompt="$1"
    local candidates
    candidates="$(list_profiles)"

    local choice
    if [[ -n "$candidates" ]] && command -v fzf >/dev/null 2>&1; then
        choice="$(printf '%s\n' "$candidates" | fzf --prompt="$prompt> " --height=40% --layout=reverse --border=rounded --color="$FZF_COLOR")"
    else
        if [[ -n "$candidates" ]]; then
            echo -e "${DIM}Available profiles:${NC}" >&2
            printf "  ${ACCENT}%s${NC}\n" $candidates >&2
        else
            warn "No rclone-sync profiles found in $PROFILES_DIR."
        fi
        echo -en "${PRIMARY}${prompt} (type profile name):${NC} " >&2
        read -r choice
    fi

    if [[ -z "$choice" ]]; then
        err "No profile selected for '$prompt'."
        exit 1
    fi
    if [[ ! -f "$PROFILES_DIR/${choice}.conf" ]]; then
        err "Profile '$choice' not found ($PROFILES_DIR/${choice}.conf doesn't exist)."
        exit 1
    fi

    echo "$choice"
}

generate_conf() {
    print_header "🎵 MPD Configure"

    local bak_file="$MPD_CONF.bak"
    if [[ ! -f "$bak_file" ]]; then
        err "No template at $bak_file — nothing to generate mpd.conf from."
        err "Save your mpd.conf template there (music_directory / playlist_directory"
        err "get overwritten, everything else is kept as-is) and re-run."
        exit 1
    fi

    local tracks_profile playlists_profile
    tracks_profile="$(select_profile "Select TRACKS sync profile")"
    playlists_profile="$(select_profile "Select PLAYLISTS sync profile")"

    local music_dir playlist_dir
    music_dir="$(profile_field "$tracks_profile" LOCAL_PATH)"
    playlist_dir="$(profile_field "$playlists_profile" LOCAL_PATH)"

    echo
    echo -e "${PRIMARY}$(hr 62)${NC}"
    echo -e "${DIM}Tracks profile:${NC}    ${BOLD}$tracks_profile${NC} ${DIM}($music_dir)${NC}"
    echo -e "${DIM}Playlists profile:${NC} ${BOLD}$playlists_profile${NC} ${DIM}($playlist_dir)${NC}"
    echo -e "${PRIMARY}$(hr 62)${NC}"
    echo

    mkdir -p "$MPD_DIR" "$music_dir" "$playlist_dir"

    local mpd_share_dir="$HOME/.local/share/mpd"
    if [[ ! -d "$mpd_share_dir" ]]; then
        mkdir -p "$mpd_share_dir"
        ok "Created $mpd_share_dir"
    fi

    if ! grep -qE '^music_directory[[:space:]]' "$bak_file"; then
        warn "$bak_file has no 'music_directory' line — it won't be set."
    fi
    if ! grep -qE '^playlist_directory[[:space:]]' "$bak_file"; then
        warn "$bak_file has no 'playlist_directory' line — it won't be set."
    fi

    sed -E \
        -e "s|^(music_directory[[:space:]]+)\".*\"|\1\"${music_dir}\"|" \
        -e "s|^(playlist_directory[[:space:]]+)\".*\"|\1\"${playlist_dir}\"|" \
        "$bak_file" > "$MPD_CONF"

    ok "Wrote $MPD_CONF (from $bak_file — music_directory/playlist_directory updated, everything else kept)"
}

daemon_cmd() {
    print_header "🎵 MPD ${1^}"

    # start/restart/enable actually try to bring mpd up — refuse with a clear
    # error if there's no config yet, instead of letting mpd itself fail with
    # "Failed to access ... No such file or directory" (the original bug this
    # whole setup started from).
    case "$1" in
        start|restart|enable)
            if [[ ! -f "$MPD_CONF" ]]; then
                err "No config at $MPD_CONF — run '$(basename "$0") configure' first."
                exit 1
            fi
            ;;
    esac

    case "$1" in
        start|stop|restart)
            systemctl --user "$1" mpd.service && ok "mpd.service ${1}ed" || { err "Failed to $1 mpd.service"; exit 1; }
            ;;
        daemon-status) systemctl --user status mpd.service --no-pager ;;
        enable)
            systemctl --user enable --now mpd.service && ok "mpd.service enabled + started" || { err "Failed to enable mpd.service"; exit 1; }
            ;;
        disable)
            systemctl --user disable --now mpd.service && ok "mpd.service disabled + stopped" || { err "Failed to disable mpd.service"; exit 1; }
            ;;
        *) err "Unknown daemon action: $1"; exit 1 ;;
    esac
}

query_tracks() {
    local filter="${1:-}"
    print_header "🎵 Tracks"
    if [[ -n "$filter" ]]; then
        mpc search any "$filter"
    else
        mpc listall
    fi
}

query_playlist_contents() {
    local name="${1:?playlist name required}"
    print_header "🎵 Playlist: $name"
    mpc load "$name" >/dev/null
    mpc playlist
}

usage() {
    print_header "🎵 MPD Configurer"
    cat <<EOF
Usage: $(basename "$0") <command> [args]

${ACCENT}configure${NC}                   regenerate ~/.config/mpd/mpd.conf from the
                             ~/.config/mpd/mpd.conf.bak template (errors out if
                             missing); prompts (fzf, or type-to-enter) to pick
                             the tracks/playlists rclone-sync profiles, patches
                             only music_directory/playlist_directory, and
                             ensures the target folders exist

${ACCENT}start | stop | restart${NC}      manage the mpd.service user daemon
${ACCENT}enable${NC}                      enable + start mpd.service (persist across reboot)
${ACCENT}disable${NC}                     stop + disable mpd.service
${ACCENT}daemon-status${NC}                systemctl --user status mpd.service

${ACCENT}tracks${NC} [search-term]        list all tracks, or search (artist/title/any)
${ACCENT}playlists${NC}                   list stored playlists
${ACCENT}playlist${NC} <name>              load a stored playlist and print its contents
${ACCENT}stats${NC}                       mpc stats (library/db summary)
${ACCENT}status${NC}                      mpc status (current playback state)
${ACCENT}mpc${NC} -- <args>                 raw passthrough to mpc for anything else
EOF
}

main() {
    case "${1:-}" in
        configure) generate_conf ;;
        start|stop|restart) daemon_cmd "$1" ;;
        enable) daemon_cmd enable ;;
        disable) daemon_cmd disable ;;
        daemon-status) daemon_cmd daemon-status ;;
        tracks) query_tracks "${2:-}" ;;
        playlists) print_header "🎵 Playlists"; mpc lsplaylists ;;
        playlist) query_playlist_contents "${2:-}" ;;
        stats) print_header "🎵 Stats"; mpc stats ;;
        status) print_header "🎵 Status"; mpc status ;;
        mpc) shift; mpc "$@" ;;
        -h|--help|"") usage ;;
        *) err "Unknown command: $1"; usage; exit 1 ;;
    esac
}

main "$@"
