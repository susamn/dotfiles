#!/bin/bash

# Music Control Script - Control playerctl and MPD with fuzzy selection
# Beautiful terminal-based music controller

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
RESET='\033[0m'
BOLD='\033[1m'

# Icons
PLAY_ICON="▶"
PAUSE_ICON="⏸"
MUSIC_ICON="♫"
LIST_ICON="☰"
SEARCH_ICON="🔍"
PLAYER_ICON="🎵"

# MPD music directory from config
MUSIC_DIR="/home/susamn/Music/susamn-music-collection"
PLAYLIST_DIR="$HOME/.config/mpd/playlists"

# Function to display header
header() {
    clear
    printf "${CYAN}╔════════════════════════════════════════╗${RESET}\n"
    printf "${CYAN}║${RESET}  ${MAGENTA}${BOLD}${MUSIC_ICON}  Music Control Center  ${MUSIC_ICON}${RESET}      ${CYAN}║${RESET}\n"
    printf "${CYAN}╚════════════════════════════════════════╝${RESET}\n"
    printf "\n"
}

# Function to get all available players
get_players() {
    playerctl -l 2>/dev/null
}

# Function to get all active players as array
get_all_players() {
    local player_array=()

    # Add playerctl detected players
    local players=$(get_players)
    if [[ -n "$players" ]]; then
        while IFS= read -r player; do
            player_array+=("$player")
        done <<< "$players"
    fi

    # Add MPD if available
    if mpc status &>/dev/null; then
        player_array+=("mpd")
    fi

    printf '%s\n' "${player_array[@]}"
}

# Function to show current status with numbered players
show_status() {
    # Get all active players
    local players=($(get_all_players))

    if [[ ${#players[@]} -eq 0 ]]; then
        printf "${GRAY}No active players${RESET}\n\n"
        return
    fi

    printf "${CYAN}${PLAYER_ICON} Active Players:${RESET}\n"

    local i=1
    for player in "${players[@]}"; do
        if [[ "$player" == "mpd" ]]; then
            local mpc_status=$(mpc status 2>/dev/null)
            if [[ -n "$mpc_status" ]]; then
                local current=$(mpc current 2>/dev/null)
                local state=$(mpc status | grep -o '\[.*\]' | head -1 | tr -d '[]')

                if [[ "$state" == "playing" ]]; then
                    printf "${WHITE}[%d]${RESET} ${GREEN}${PLAY_ICON}${RESET} ${WHITE}%-15s${RESET} %s\n" "$i" "$player" "$current"
                elif [[ "$state" == "paused" ]]; then
                    printf "${WHITE}[%d]${RESET} ${YELLOW}${PAUSE_ICON}${RESET} ${WHITE}%-15s${RESET} %s\n" "$i" "$player" "$current"
                else
                    printf "${WHITE}[%d]${RESET} ${GRAY}○${RESET} ${WHITE}%-15s${RESET} ${GRAY}(stopped)${RESET}\n" "$i" "$player"
                fi
            fi
        else
            local status=$(playerctl -p "$player" status 2>/dev/null)
            local title=$(playerctl -p "$player" metadata title 2>/dev/null || echo "Unknown")
            local artist=$(playerctl -p "$player" metadata artist 2>/dev/null)

            if [[ "$status" == "Playing" ]]; then
                printf "${WHITE}[%d]${RESET} ${GREEN}${PLAY_ICON}${RESET} ${WHITE}%-15s${RESET} %s" "$i" "$player" "$title"
                [[ -n "$artist" ]] && printf " - %s" "$artist"
                printf "\n"
            elif [[ "$status" == "Paused" ]]; then
                printf "${WHITE}[%d]${RESET} ${YELLOW}${PAUSE_ICON}${RESET} ${WHITE}%-15s${RESET} %s" "$i" "$player" "$title"
                [[ -n "$artist" ]] && printf " - %s" "$artist"
                printf "\n"
            else
                printf "${WHITE}[%d]${RESET} ${GRAY}○${RESET} ${WHITE}%-15s${RESET}\n" "$i" "$player"
            fi
        fi
        ((i++))

        # Limit to 9 players
        if [[ $i -gt 9 ]]; then
            break
        fi
    done
    printf "\n"
}

# Function to check if any player is playing
is_any_playing() {
    local players=($(get_all_players))

    for player in "${players[@]}"; do
        if [[ "$player" == "mpd" ]]; then
            local mpc_state=$(mpc status 2>/dev/null | grep -o '\[.*\]' | head -1 | tr -d '[]')
            if [[ "$mpc_state" == "playing" ]]; then
                return 0
            fi
        else
            local status=$(playerctl -p "$player" status 2>/dev/null)
            if [[ "$status" == "Playing" ]]; then
                return 0
            fi
        fi
    done
    return 1
}

# Function to pause all players unconditionally
pause_all_players() {
    local players=($(get_all_players))

    if [[ ${#players[@]} -eq 0 ]]; then
        printf "${YELLOW}No active players${RESET}\n"
        sleep 1.5
        return
    fi

    # Pause all players regardless of state
    for player in "${players[@]}"; do
        if [[ "$player" == "mpd" ]]; then
            mpc pause &>/dev/null
            printf "${CYAN}Paused: ${WHITE}mpd${RESET}\n"
        else
            playerctl -p "$player" pause 2>/dev/null
            printf "${CYAN}Paused: ${WHITE}%s${RESET}\n" "$player"
        fi
    done
    printf "${YELLOW}${PAUSE_ICON} All players paused${RESET}\n"
    sleep 1.5
}

# Function to pause/resume all players (smart toggle)
toggle_all_players() {
    local players=($(get_all_players))

    # Check if any player is playing
    if is_any_playing; then
        # Pause all
        for player in "${players[@]}"; do
            if [[ "$player" == "mpd" ]]; then
                mpc pause &>/dev/null
                printf "${CYAN}Paused: ${WHITE}mpd${RESET}\n"
            else
                playerctl -p "$player" pause 2>/dev/null
                printf "${CYAN}Paused: ${WHITE}%s${RESET}\n" "$player"
            fi
        done
        printf "${YELLOW}${PAUSE_ICON} All players paused${RESET}\n"
    else
        # Resume all
        for player in "${players[@]}"; do
            if [[ "$player" == "mpd" ]]; then
                mpc play &>/dev/null
                printf "${CYAN}Resumed: ${WHITE}mpd${RESET}\n"
            else
                playerctl -p "$player" play 2>/dev/null
                printf "${CYAN}Resumed: ${WHITE}%s${RESET}\n" "$player"
            fi
        done
        printf "${GREEN}${PLAY_ICON} All players resumed${RESET}\n"
    fi
    sleep 1.5
}

# Function to toggle play/pause - accepts player number (1-9) or 0 for all
toggle_playback() {
    local player_num="$1"
    local players=($(get_all_players))

    if [[ "$player_num" == "0" ]]; then
        # Toggle all players
        for player in "${players[@]}"; do
            if [[ "$player" == "mpd" ]]; then
                mpc toggle &>/dev/null
                printf "${CYAN}Toggled: ${WHITE}mpd${RESET}\n"
            else
                playerctl -p "$player" play-pause 2>/dev/null
                printf "${CYAN}Toggled: ${WHITE}%s${RESET}\n" "$player"
            fi
        done
        printf "${GREEN}${PLAY_ICON} All players toggled${RESET}\n"
    else
        # Toggle specific player
        if [[ "$player_num" -ge 1 ]] && [[ "$player_num" -le ${#players[@]} ]]; then
            local selected_player="${players[$((player_num-1))]}"

            if [[ "$selected_player" == "mpd" ]]; then
                mpc toggle &>/dev/null
                local mpc_state=$(mpc status | grep -o '\[.*\]' | head -1 | tr -d '[]')
                if [[ "$mpc_state" == "playing" ]]; then
                    printf "${GREEN}${PLAY_ICON} MPD: Playback resumed${RESET}\n"
                else
                    printf "${YELLOW}${PAUSE_ICON} MPD: Playback paused${RESET}\n"
                fi
            else
                playerctl -p "$selected_player" play-pause 2>/dev/null
                local state=$(playerctl -p "$selected_player" status 2>/dev/null)
                if [[ "$state" == "Playing" ]]; then
                    printf "${GREEN}${PLAY_ICON} %s: Playback resumed${RESET}\n" "$selected_player"
                else
                    printf "${YELLOW}${PAUSE_ICON} %s: Playback paused${RESET}\n" "$selected_player"
                fi
            fi
        else
            printf "${RED}Invalid player number: %s${RESET}\n" "$player_num"
        fi
    fi
    sleep 1.5
}

# Function to load and play a playlist
load_playlist() {
    header
    printf "${CYAN}${LIST_ICON} Select a playlist:${RESET}\n"
    printf "\n"

    # Check if playlist directory exists
    if [[ ! -d "$PLAYLIST_DIR" ]]; then
        printf "${RED}Playlist directory not found: %s${RESET}\n" "$PLAYLIST_DIR"
        sleep 2
        return
    fi

    # Get list of playlists using mpc
    local playlists=$(mpc lsplaylists 2>/dev/null)

    if [[ -z "$playlists" ]]; then
        printf "${YELLOW}No playlists found${RESET}\n"
        sleep 2
        return
    fi

    # Use fzf for selection with preview
    local selected=$(echo "$playlists" | fzf \
        --height=60% \
        --border=rounded \
        --prompt="Select playlist: " \
        --header="Enter to load | Esc to cancel" \
        --preview="mpc playlist {} 2>/dev/null | head -20" \
        --preview-window=right:50%:wrap \
        --color="fg:#d0d0d0,bg:#121212,hl:#5f87af" \
        --color="fg+:#d0d0d0,bg+:#262626,hl+:#5fd7ff" \
        --color="info:#afaf87,prompt:#d7005f,pointer:#af5fff" \
        --color="marker:#87ff00,spinner:#af5fff,header:#87afaf")

    if [[ -n "$selected" ]]; then
        printf "\n"
        printf "${BLUE}Loading playlist: ${WHITE}%s${RESET}\n" "$selected"
        mpc clear &>/dev/null
        mpc load "$selected" &>/dev/null
        mpc play &>/dev/null
        printf "${GREEN}✓ Playlist loaded and playing!${RESET}\n"
        sleep 1.5
    fi
}

# Function to search and play a song
play_song() {
    header
    printf "${CYAN}${SEARCH_ICON} Search for a song:${RESET}\n"
    printf "\n"

    # Get all songs from MPD database
    local songs=$(mpc listall 2>/dev/null)

    if [[ -z "$songs" ]]; then
        printf "${YELLOW}No songs found in MPD database${RESET}\n"
        printf "${GRAY}Try running: mpc update${RESET}\n"
        sleep 3
        return
    fi

    # Use fzf for fuzzy search
    local selected=$(echo "$songs" | fzf \
        --height=70% \
        --border=rounded \
        --prompt="Search song: " \
        --header="Enter to play | Esc to cancel" \
        --preview="echo {} | sed 's|.*/||' | sed 's|\.[^.]*$||'" \
        --preview-window=up:3:wrap \
        --color="fg:#d0d0d0,bg:#121212,hl:#5f87af" \
        --color="fg+:#d0d0d0,bg+:#262626,hl+:#5fd7ff" \
        --color="info:#afaf87,prompt:#d7005f,pointer:#af5fff" \
        --color="marker:#87ff00,spinner:#af5fff,header:#87afaf")

    if [[ -n "$selected" ]]; then
        printf "\n"
        printf "${BLUE}Playing: ${WHITE}%s${RESET}\n" "$(basename "$selected")"
        mpc clear &>/dev/null
        mpc add "$selected" &>/dev/null
        mpc play &>/dev/null
        printf "${GREEN}✓ Song added and playing!${RESET}\n"
        sleep 1.5
    fi
}

# Function to show MPD queue
show_queue() {
    header
    printf "${CYAN}${LIST_ICON} Current Queue:${RESET}\n"
    printf "\n"

    local queue=$(mpc playlist 2>/dev/null)

    if [[ -z "$queue" ]]; then
        printf "${YELLOW}Queue is empty${RESET}\n"
        sleep 2
        return
    fi

    # Show queue with fzf (read-only)
    echo "$queue" | nl -w3 -s'. ' | fzf \
        --height=70% \
        --border=rounded \
        --prompt="Queue: " \
        --header="Esc to go back" \
        --color="fg:#d0d0d0,bg:#121212,hl:#5f87af" \
        --color="fg+:#d0d0d0,bg+:#262626,hl+:#5fd7ff" \
        --color="info:#afaf87,prompt:#d7005f,pointer:#af5fff" \
        --color="marker:#87ff00,spinner:#af5fff,header:#87afaf" \
        --no-mouse
}

# Main menu
main_menu() {
    while true; do
        header

        # Display menu options
        printf "${GREEN}[1]${RESET} ${PLAY_ICON}/${PAUSE_ICON}  Toggle All Players\n"
        printf "${MAGENTA}[2]${RESET} ${LIST_ICON}  Load Playlist\n"
        printf "${CYAN}[3]${RESET} ${SEARCH_ICON}  Search and Play Song\n"
        printf "${BLUE}[4]${RESET} ${LIST_ICON}  Show Current Queue\n"
        printf "${RED}[5]${RESET} ✗  Exit\n"
        printf "\n"

        # Show active players below menu
        show_status

        printf "${GRAY}Tip: Enter '11' to toggle player 1, '12' for player 2${RESET}\n"
        printf "${YELLOW}Enter choice:${RESET} "

        # Read user choice
        read -r choice

        # Parse input - check if it's a two-digit command
        if [[ "$choice" =~ ^[1-5][0-9]$ ]]; then
            # Two digit input: first digit is action, second is player number
            local action="${choice:0:1}"
            local player_num="${choice:1:1}"

            case "$action" in
                1)
                    # Toggle specific player (10 = all, 11-19 = specific)
                    toggle_playback "$player_num"
                    ;;
                2)
                    printf "${YELLOW}Playlist loading doesn't support specific players${RESET}\n"
                    sleep 1
                    ;;
                3)
                    printf "${YELLOW}Song search doesn't support specific players${RESET}\n"
                    sleep 1
                    ;;
                4)
                    printf "${YELLOW}Queue view doesn't support specific players${RESET}\n"
                    sleep 1
                    ;;
            esac
        else
            # Single digit or other input
            case "$choice" in
                1)
                    # Toggle all players (smart: pause if any playing, resume if all paused)
                    toggle_all_players
                    ;;
                2)
                    load_playlist
                    ;;
                3)
                    play_song
                    ;;
                4)
                    show_queue
                    ;;
                5|q|quit|exit)
                    clear
                    printf "${CYAN}Goodbye! ${MUSIC_ICON}${RESET}\n"
                    exit 0
                    ;;
                *)
                    printf "${RED}Invalid option. Please try again.${RESET}\n"
                    sleep 1
                    ;;
            esac
        fi
    done
}

# Quick mode - if argument provided, execute directly without menu
case "$1" in
    toggle|t)
        toggle_all_players
        exit 0
        ;;
    pause|p)
        pause_all_players
        exit 0
        ;;
    playlist|pl)
        header
        load_playlist
        exit 0
        ;;
    song|s)
        header
        play_song
        exit 0
        ;;
    queue|q)
        header
        show_queue
        exit 0
        ;;
    --help|-h|help)
        printf "${CYAN}${MUSIC_ICON} Music Control - Usage:${RESET}\n\n"
        printf "${WHITE}Quick Commands:${RESET}\n"
        printf "  ${GREEN}music${RESET}           - Interactive menu\n"
        printf "  ${GREEN}music t${RESET}         - Toggle all players (pause ↔ play)\n"
        printf "  ${GREEN}music p${RESET}         - Pause all players (unconditional)\n"
        printf "  ${GREEN}music pl${RESET}        - Load playlist\n"
        printf "  ${GREEN}music s${RESET}         - Search and play song\n"
        printf "  ${GREEN}music q${RESET}         - Show queue\n\n"
        printf "${YELLOW}In interactive mode:${RESET}\n"
        printf "  Enter ${WHITE}1${RESET}   - Toggle all (pause if any playing, play if all paused)\n"
        printf "  Enter ${WHITE}10${RESET}  - Toggle all players\n"
        printf "  Enter ${WHITE}11${RESET}  - Toggle player 1 only\n"
        printf "  Enter ${WHITE}12${RESET}  - Toggle player 2 only\n"
        printf "  Enter ${WHITE}13${RESET}  - Toggle player 3, etc.\n"
        exit 0
        ;;
    *)
        # No argument or unknown argument - show interactive menu
        main_menu
        ;;
esac
