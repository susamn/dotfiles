#!/usr/bin/env bash

# Path to lookup file (adjust if needed)
get_script_dir() {
    local target="${BASH_SOURCE[0]}"
    while [ -h "$target" ]; do
        local dir
        dir="$(cd -P "$(dirname "$target")" && pwd)"
        target="$(readlink "$target")"
        [[ $target != /* ]] && target="$dir/$target"
    done
    echo "$(cd -P "$(dirname "$target")" && pwd)"
}
SCRIPT_DIR="$(get_script_dir)"
LOOKUP_FILE="${WORKSPACE_PATH:-$SCRIPT_DIR/..}/.alias_descriptions"
SHOW_DESCRIPTIONS=false

# Fast, fork-free whitespace trimmer using Bash namerefs
trim() {
    local -n var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
}

# Load dotfiles-managed aliases into an associative array
declare -A dotfiles_aliases

load_dotfiles_aliases() {
    local files=(
        "${WORKSPACE_PATH:-$SCRIPT_DIR/..}/.aliases.sh"
        "${WORKSPACE_PATH:-$SCRIPT_DIR/..}/.distro.aliases.sh"
        "${WORKSPACE_PATH:-$SCRIPT_DIR/..}/.generic.aliases.sh"
    )
    for f in "${files[@]}"; do
        if [[ -f "$f" ]]; then
            while read -r line || [[ -n "$line" ]]; do
                # Strip leading/trailing whitespace using bash parameter expansion
                line="${line#"${line%%[![:space:]]*}"}"
                line="${line%"${line##*[![:space:]]}"}"
                
                if [[ "$line" =~ ^alias[[:space:]]+([a-zA-Z0-9_.-]+)= ]]; then
                    dotfiles_aliases["${BASH_REMATCH[1]}"]=1
                fi
            done < "$f"
        fi
    done
}

# Handle preview card generation
show_preview_card() {
    local raw_line="$*"
    # Strip ANSI escape codes (using portable -E flag for sed)
    local clean
    clean=$(echo "$raw_line" | sed -E "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g")
    
    # Split on tabs
    local name=""
    local cmd=""
    local desc=""
    IFS=$'\t' read -r name cmd desc <<< "$clean"
    
    # Trim whitespace (fork-free)
    trim name
    trim cmd
    trim desc
    
    # Determine source (Managed vs System)
    load_dotfiles_aliases
    local source_desc="\033[1;33m💻 System / Not Managed\033[0m"
    if [[ -n "${dotfiles_aliases[$name]:-}" ]]; then
        source_desc="\033[1;32m⚙️  Dotfiles Managed\033[0m"
    fi
    
    echo -e "\033[1;36m──────────────────────────────────────────────────────────\033[0m"
    echo -e "\033[1;37m Alias Name  :\033[0m  \033[1;32m$name\033[0m"
    echo -e "\033[1;37m Source      :\033[0m  $source_desc"
    echo -e "\033[1;36m──────────────────────────────────────────────────────────\033[0m"
    echo -e "\033[1;37m Command     :\033[0m"
    # Highlight command with lime green foreground (no background color)
    echo "$cmd" | fold -s -w 54 | while IFS= read -r line || [[ -n "$line" ]]; do
        echo -e "  \033[92m$line\033[0m"
    done
    echo ""
    echo -e "\033[1;37m Description :\033[0m"
    if [[ -n "$desc" ]]; then
        # Highlight description in cyan info color
        echo "$desc" | fold -s -w 56 | while IFS= read -r line || [[ -n "$line" ]]; do
            echo -e "  \033[36m$line\033[0m"
        done
    else
        echo -e "  \033[3mNo description available.\033[0m"
    fi
    echo -e "\033[1;36m──────────────────────────────────────────────────────────\033[0m"
}

if [[ "${1:-}" == "--preview-card" ]]; then
    shift
    show_preview_card "$@"
    exit 0
fi

# Color definitions
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'

# Check for the -m flag
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m) SHOW_DESCRIPTIONS=true ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Ensure input is provided (prevent empty pipe)
if [[ -t 0 ]]; then
    echo -e "${BOLD}Error:${RESET} No input provided. Pipe alias list into this script."
    echo -e "${DIM}Example: alias | ./script.sh [-m]${RESET}"
    exit 1
fi

# Load lookup file into associative array to prevent fork-in-loop grep commands
declare -A descriptions
if [[ "$SHOW_DESCRIPTIONS" == true && -f "$LOOKUP_FILE" ]]; then
    while IFS='=' read -r key val || [[ -n "$key" ]]; do
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        
        # Strip leading/trailing whitespace using bash parameter expansion
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        
        val="${val#"${val%%[![:space:]]*}"}"
        val="${val%"${val##*[![:space:]]}"}"
        
        descriptions["$key"]="$val"
    done < "$LOOKUP_FILE"
fi

# Process input aliases and feed to fzf
selected=$(while read -r line; do
    # Strip leading 'alias ' prefix if present (common in bash, not zsh)
    line="${line#alias }"

    # Ensure the alias format is valid (has at least one '=')
    [[ "$line" =~ ^[^=]+= ]] || continue

    name="${line%%=*}"
    command="${line#*=}"
    
    # Restore escaped single quotes (e.g. '\'' becomes ')
    command="${command//\'\\\'\'/\'}"
    
    # Strip surrounding single/double quotes
    if [[ "$command" == \'*\' ]]; then
        command="${command#\'}"
        command="${command%\'}"
    elif [[ "$command" == \"*\" ]]; then
        command="${command#\"}"
        command="${command%\"}"
    fi

    # Ignore aliases that start with "_"
    if [[ ! "$name" =~ ^_ ]]; then
        description=""
        if [[ "$SHOW_DESCRIPTIONS" == true ]]; then
            description="${descriptions[$name]:-}"
        fi

        if [[ -n "$description" ]]; then
            printf "${CYAN}%s${RESET}\t${GREEN}%s${RESET}\t${DIM}%s${RESET}\n" "$name" "$command" "$description"
        else
            printf "${CYAN}%s${RESET}\t${GREEN}%s${RESET}\t\n" "$name" "$command"
        fi
    fi
done | fzf \
    --ansi \
    --layout=reverse \
    --border=rounded \
    --border-label="│ Shell Aliases │" \
    --border-label-pos=3 \
    --prompt="🔍 " \
    --pointer="▶" \
    --marker="✓" \
    --header="ALIAS NAME" \
    --header-first \
    --delimiter='\t' \
    --with-nth=1 \
    --color="border:#5f87af,label:#87afff:bold,header:#87afff:bold,prompt:#87d787:bold,pointer:#ff5f87:bold,marker:#87d787:bold" \
    --preview="bash $0 --preview-card {}" \
    --preview-window="right:65%:rounded" \
    --info=inline \
    --height=100%)

if [[ -n "$selected" ]]; then
    # Parse command from selection (using portable -E flag for sed)
    clean=$(echo "$selected" | sed -E "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g")
    
    name=""
    cmd=""
    desc=""
    IFS=$'\t' read -r name cmd desc <<< "$clean"
    
    # Trim whitespace (fork-free)
    trim name
    trim cmd
    
    # Copy to clipboard if utility exists
    if command -v pbcopy >/dev/null 2>&1; then
        echo -n "$cmd" | pbcopy
        echo -e "📋 \033[1;32mCopied to clipboard:\033[0m $cmd"
    elif command -v xsel >/dev/null 2>&1; then
        echo -n "$cmd" | xsel --clipboard --input >/dev/null 2>&1
        echo -e "📋 \033[1;32mCopied to clipboard:\033[0m $cmd"
    elif command -v wl-copy >/dev/null 2>&1; then
        echo -n "$cmd" | wl-copy
        echo -e "📋 \033[1;32mCopied to clipboard:\033[0m $cmd"
    else
        # Fallback to printing the command
        echo "$cmd"
    fi
fi
