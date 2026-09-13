#!/usr/bin/env bash
#
# rclone-config-manager.sh — per-remote encryption for rclone.conf
#
# Each rclone remote is stored three ways:
#
#   ~/.config/rclone/rclone.conf          the live config rclone actually reads
#   ~/.config/rclone-backends/<n>.conf    that remote's section, on its own
#   ~/.config/_secured/rclone_<n>.gpg     that section, symmetrically encrypted
#
# Every remote has its own passphrase, so remotes can be encrypted, decrypted
# and rotated one at a time. The .gpg name and the backend path are registered
# in ~/.config/_secured/locations.properties, which is the contract shared with
# generate-secure-resources.sh.
#
# Usage: rclone-config-manager.sh [-h|--help]
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SECURED_DIR="$HOME/.config/_secured"
BACKENDS_DIR="$HOME/.config/rclone-backends"
RCLONE_CONF="$HOME/.config/rclone/rclone.conf"
PROPERTIES_FILE="$SECURED_DIR/locations.properties"

# rclone remote names may contain letters, digits, underscore, dot, plus, dash.
SECTION_RE='^\[([A-Za-z0-9_.+-]+)\][[:space:]]*$'

# Plaintext remote configs hold live tokens; never let anyone else read them.
SECRET_MODE=600
PROPERTIES_MODE=644

# ---------------------------------------------------------------------------
# Terminal output
#
# Colour is disabled when stdout is not a terminal or NO_COLOR is set, so the
# output stays readable when piped or logged.
# ---------------------------------------------------------------------------

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'
    C_RED=$'\033[1;31m'; C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'
    C_BLUE=$'\033[1;34m'; C_MAGENTA=$'\033[1;35m'; C_CYAN=$'\033[1;36m'
    C_WHITE=$'\033[1;37m'; C_DIM=$'\033[1;30m'
else
    C_RESET=''; C_RED=''; C_GREEN=''; C_YELLOW=''
    C_BLUE=''; C_MAGENTA=''; C_CYAN=''; C_WHITE=''; C_DIM=''
fi

# say <colour> <text> — one coloured line. printf, not `echo -e`, because
# echo's handling of backslashes varies between shells and builds.
say()   { printf '%s%s%s\n' "$1" "$2" "$C_RESET"; }
info()  { say "$C_GREEN"  "✅ $1"; }
rule()  { say "$C_CYAN"   "$1"; }
# Diagnostics go to stderr so they never land inside a command substitution.
warn()  { say "$C_YELLOW" "⚠️  $1" >&2; }
fail()  { say "$C_RED"    "❌ $1" >&2; return 1; }
die()   { say "$C_RED"    "❌ $1" >&2; exit 1; }

# Pad text to a width first, then colour it, so escape sequences never count
# toward the column width.
cell() {
    local text="$1" colour="$2" width="$3"
    printf '%s%-*s%s' "$colour" "$width" "$text" "$C_RESET"
}

# Display a path with $HOME collapsed to ~.
tilde() { printf '%s' "${1/#$HOME/\~}"; }

# ---------------------------------------------------------------------------
# Portability preflight
#
# Distros differ in which GnuPG they ship and under which name. Resolve the
# binary once, and probe for --pinentry-mode (GnuPG 2.1+) rather than assuming.
# ---------------------------------------------------------------------------

GPG_BIN=''
GPG_LOOPBACK=()   # empty on GnuPG 1.x, which prompts on the tty anyway

preflight() {
    if (( ${BASH_VERSINFO[0]:-0} < 4 )); then
        die "bash 4.0 or newer is required (found ${BASH_VERSION:-unknown})."
    fi

    local cmd
    for cmd in awk grep sort mktemp chmod cp date; do
        command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
    done

    local candidate
    for candidate in gpg gpg2; do
        if command -v "$candidate" >/dev/null 2>&1; then
            GPG_BIN="$candidate"
            break
        fi
    done
    [[ -n "$GPG_BIN" ]] || die "GnuPG not found (looked for: gpg, gpg2)."

    # --pinentry-mode loopback keeps the passphrase prompt on stdin instead of
    # handing it to a graphical pinentry, which may not exist on a headless box.
    if "$GPG_BIN" --dump-options 2>/dev/null | grep -qx -- '--pinentry-mode'; then
        GPG_LOOPBACK=(--pinentry-mode loopback)
    fi

    # An unmatched glob must expand to nothing, not to the pattern itself.
    shopt -s nullglob

    mkdir -p "$SECURED_DIR" "$BACKENDS_DIR" "$(dirname "$RCLONE_CONF")"
    [[ -f "$PROPERTIES_FILE" ]] || : > "$PROPERTIES_FILE"
}

# gpg_run <args...> — GnuPG with the right binary and prompt mode for this host.
gpg_run() {
    "$GPG_BIN" ${GPG_LOOPBACK[@]+"${GPG_LOOPBACK[@]}"} "$@"
}

# gpg_archive_sane <file> — true if the file is a well-formed symmetrically
# encrypted OpenPGP message. Reads only the packet headers, so it needs no
# passphrase and costs the user no extra prompt.
gpg_archive_sane() {
    local args=(--list-packets --batch)
    if (( ${#GPG_LOOPBACK[@]} > 0 )); then
        args+=(--pinentry-mode cancel)
    fi
    { "$GPG_BIN" "${args[@]}" < "$1" 2>/dev/null || true; } | grep -q 'symkey enc packet'
}

# ---------------------------------------------------------------------------
# Small file helpers
# ---------------------------------------------------------------------------

# Timestamped copy beside the original, so no destructive step is one-way.
backup_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    local stamp
    stamp=$(date +%Y%m%d_%H%M%S)
    cp -p "$file" "${file}.${stamp}.backup"
    info "Backup created: ${file##*/}.${stamp}.backup"
}

# Overwrite a file's contents in place. Uses `cat >` rather than `mv` so a
# symlinked target (locations.properties is often one) keeps its symlink.
write_over() {
    local source="$1" target="$2" mode="$3"
    cat "$source" > "$target"
    chmod "$mode" "$target"
}

# Drop trailing blank lines. awk, not sed: the sed idiom for this is GNU-only.
strip_trailing_blank_lines() {
    awk '
        NF            { last = NR }
                      { line[NR] = $0 }
        END           { for (i = 1; i <= last; i++) print line[i] }
    ' "$1"
}

# True if $1 appears in the remaining arguments.
contains() {
    local needle="$1"; shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# locations.properties
#
# Format, shared with generate-secure-resources.sh:
#   <gpg filename>=<path to decrypt to>      # blank lines and #comments kept
# ---------------------------------------------------------------------------

# Key of a property line, whitespace trimmed. Empty for blanks and comments.
property_key() {
    local key="${1%%=*}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    printf '%s' "$key"
}

properties_has_key() {
    local wanted="$1" line
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$(property_key "$line")" == "$wanted" ]] && return 0
    done < "$PROPERTIES_FILE"
    return 1
}

# Register a remote so generate-secure-resources.sh can restore it too.
register_remote() {
    local name="$1"
    local key="rclone_${name}.gpg"
    local value="~/.config/rclone-backends/${name}.conf"

    properties_has_key "$key" && return 0

    printf '%s=%s\n' "$key" "$value" >> "$PROPERTIES_FILE"
    chmod "$PROPERTIES_MODE" "$PROPERTIES_FILE"
    info "Registered in locations.properties: $key -> $value"
}

# ---------------------------------------------------------------------------
# rclone.conf parsing
# ---------------------------------------------------------------------------

# Names of every [section] in the active config, one per line.
active_section_names() {
    [[ -f "$RCLONE_CONF" ]] || return 0
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ $SECTION_RE ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
        fi
    done < "$RCLONE_CONF"
}

# Copy just the [name] section of rclone.conf into <outfile>. False if absent.
extract_section() {
    local name="$1" outfile="$2"
    local inside=0 found=0 line

    [[ -f "$RCLONE_CONF" ]] || return 1

    : > "$outfile"
    chmod "$SECRET_MODE" "$outfile"

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ $SECTION_RE ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$name" ]]; then
                inside=1
                found=1
            else
                inside=0
            fi
        fi
        if (( inside )); then
            printf '%s\n' "$line" >> "$outfile"
        fi
    done < "$RCLONE_CONF"

    (( found == 1 ))
}

# ---------------------------------------------------------------------------
# Inventory
#
# A remote is any name found in the active config, in the backends directory,
# or among the encrypted files. Its state is derived from which of the three
# it appears in — nothing is tracked separately, so a remote added by
# `rclone config` is noticed on the next refresh with no bookkeeping.
# ---------------------------------------------------------------------------

REMOTE_NAMES=()
REMOTE_IN_ACTIVE=()   # 1 if [name] is in rclone.conf
REMOTE_HAS_PLAIN=()   # 1 if the backend .conf exists
REMOTE_HAS_GPG=()     # 1 if the encrypted .gpg exists
REMOTE_STATE=()

backend_path()   { printf '%s/%s.conf' "$BACKENDS_DIR" "$1"; }
encrypted_path() { printf '%s/rclone_%s.gpg' "$SECURED_DIR" "$1"; }

# Classify one remote from the three booleans plus file times.
classify_remote() {
    local name="$1" in_active="$2" has_plain="$3" has_gpg="$4"

    if   (( has_gpg == 0 ));                    then printf 'NEW'
    elif (( has_plain == 0 && in_active == 0 )); then printf 'LOCKED'
    elif (( has_plain == 0 && in_active == 1 )); then printf 'ORPHAN'
    elif (( in_active == 0 ));                   then printf 'UNLINKED'
    elif [[ "$(backend_path "$name")" -nt "$(encrypted_path "$name")" ]]; then
        printf 'MODIFIED'
    else
        printf 'SYNCED'
    fi
}

scan_remotes() {
    REMOTE_NAMES=(); REMOTE_IN_ACTIVE=(); REMOTE_HAS_PLAIN=()
    REMOTE_HAS_GPG=(); REMOTE_STATE=()

    local candidates=() active=() name file

    while IFS= read -r name; do
        [[ -n "$name" ]] && { active+=("$name"); candidates+=("$name"); }
    done < <(active_section_names)

    for file in "$BACKENDS_DIR"/*.conf; do
        name="${file##*/}"
        candidates+=("${name%.conf}")
    done

    for file in "$SECURED_DIR"/rclone_*.gpg; do
        name="${file##*/}"; name="${name#rclone_}"
        candidates+=("${name%.gpg}")
    done

    (( ${#candidates[@]} == 0 )) && return 0

    local sorted=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && sorted+=("$name")
    done < <(printf '%s\n' "${candidates[@]}" | sort -u)

    for name in "${sorted[@]}"; do
        local in_active=0 has_plain=0 has_gpg=0

        if contains "$name" ${active[@]+"${active[@]}"}; then
            in_active=1
        fi

        if [[ -f "$(backend_path "$name")" ]]; then
            has_plain=1
            # Self-heal: a plaintext remote config must never be readable by
            # anyone else, however it came to be there.
            chmod "$SECRET_MODE" "$(backend_path "$name")"
        fi

        if [[ -f "$(encrypted_path "$name")" ]]; then
            has_gpg=1
        fi

        REMOTE_NAMES+=("$name")
        REMOTE_IN_ACTIVE+=("$in_active")
        REMOTE_HAS_PLAIN+=("$has_plain")
        REMOTE_HAS_GPG+=("$has_gpg")
        REMOTE_STATE+=("$(classify_remote "$name" "$in_active" "$has_plain" "$has_gpg")")
    done
}

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

state_label() {
    case "$1" in
        NEW)      printf '%s' 'NEW' ;;
        LOCKED)   printf '%s' 'Locked' ;;
        MODIFIED) printf '%s' 'Modified' ;;
        ORPHAN)   printf '%s' 'Orphan' ;;
        UNLINKED) printf '%s' 'Unlinked' ;;
        *)        printf '%s' 'Synced' ;;
    esac
}

state_colour() {
    case "$1" in
        NEW)      printf '%s' "$C_MAGENTA" ;;
        LOCKED)   printf '%s' "$C_YELLOW" ;;
        MODIFIED) printf '%s' "$C_RED" ;;
        ORPHAN)   printf '%s' "$C_RED" ;;
        UNLINKED) printf '%s' "$C_CYAN" ;;
        *)        printf '%s' "$C_GREEN" ;;
    esac
}

# Note the '%s' format: a bare printf '--' would be read as end-of-options.
flag_label()  { (( $1 )) && printf '%s' 'yes'     || printf '%s' '--'; }
flag_colour() { (( $1 )) && printf '%s' "$C_GREEN" || printf '%s' "$C_DIM"; }

DIVIDER='──────────────────────────────────────────────────────────────────────────'

show_status() {
    scan_remotes

    echo
    rule "══════════════════════════════════════════════════════════════════════════"
    printf ' ⚡ %sRCLONE PROFILE MANAGER%s   %s(%s)%s\n' \
        "$C_WHITE" "$C_RESET" "$C_DIM" "$(tilde "$RCLONE_CONF")" "$C_RESET"
    rule "$DIVIDER"
    printf ' %s%-4s %-22s %-8s %-10s %-8s %s%s\n' \
        "$C_WHITE" 'ID' 'REMOTE' 'GPG' 'PLAINTEXT' 'ACTIVE' 'STATE' "$C_RESET"
    rule "$DIVIDER"

    if (( ${#REMOTE_NAMES[@]} == 0 )); then
        echo '   No remotes found (no rclone.conf, no backend files, no rclone_*.gpg).'
    else
        local i state
        for i in "${!REMOTE_NAMES[@]}"; do
            state="${REMOTE_STATE[i]}"
            printf ' %s%-4d%s %-22s %s %s %s %s\n' \
                "$C_GREEN" "$((i + 1))" "$C_RESET" "${REMOTE_NAMES[i]}" \
                "$(cell "$(flag_label "${REMOTE_HAS_GPG[i]}")"   "$(flag_colour "${REMOTE_HAS_GPG[i]}")"   8)" \
                "$(cell "$(flag_label "${REMOTE_HAS_PLAIN[i]}")" "$(flag_colour "${REMOTE_HAS_PLAIN[i]}")" 10)" \
                "$(cell "$(flag_label "${REMOTE_IN_ACTIVE[i]}")" "$(flag_colour "${REMOTE_IN_ACTIVE[i]}")" 8)" \
                "$(cell "$(state_label "$state")" "$(state_colour "$state")" 10)"
        done
    fi

    rule "══════════════════════════════════════════════════════════════════════════"
    say "$C_DIM" " NEW = never encrypted · MODIFIED = plaintext newer than .gpg"
    say "$C_DIM" " UNLINKED = decrypted but not in rclone.conf · ORPHAN = in rclone.conf but no backend file"
}

# ---------------------------------------------------------------------------
# Selection
#
# Every action shares this prompt, which accepts ids (1,3), ranges (2-4),
# 'all', or 'q' to cancel. SELECTED receives indices into REMOTE_NAMES.
# ---------------------------------------------------------------------------

SELECTED=()

# Expand one token into the ids it covers. False if malformed or out of range.
expand_token() {
    local token="$1" max="$2" low high i

    if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        low="${BASH_REMATCH[1]}"; high="${BASH_REMATCH[2]}"
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
        low="$token"; high="$token"
    else
        warn "Invalid selection: '$token'"
        return 1
    fi

    for (( i = low; i <= high; i++ )); do
        if (( i < 1 || i > max )); then
            warn "Out of range: $i"
            return 1
        fi
        printf '%s\n' "$i"
    done
}

# prompt_selection <verb> [allowed states...] — no states means any remote.
prompt_selection() {
    local verb="$1"; shift
    SELECTED=()

    if (( ${#REMOTE_NAMES[@]} == 0 )); then
        warn "No remotes to $verb."
        return 1
    fi

    # Offer only the remotes the action can actually work on.
    local offered=() i
    for i in "${!REMOTE_NAMES[@]}"; do
        if (( $# == 0 )) || contains "${REMOTE_STATE[i]}" "$@"; then
            offered+=("$i")
        fi
    done

    if (( ${#offered[@]} == 0 )); then
        warn "No remotes are eligible to $verb."
        return 1
    fi

    echo
    say "$C_BLUE" "--- Select remote(s) to $verb ---"

    local position=1
    for i in "${offered[@]}"; do
        printf ' %s%-3d%s %-22s %s\n' "$C_GREEN" "$position" "$C_RESET" \
            "${REMOTE_NAMES[i]}" \
            "$(cell "$(state_label "${REMOTE_STATE[i]}")" "$(state_colour "${REMOTE_STATE[i]}")" 10)"
        position=$(( position + 1 ))
    done

    say "$C_DIM" " Enter ids (1,3), ranges (1-3), 'all', or 'q' to cancel"
    printf 'Choice: '

    local reply
    read -r reply
    reply="${reply// /}"

    if [[ -z "$reply" || "$reply" == 'q' ]]; then
        echo 'Cancelled.'
        return 1
    fi

    local chosen=()
    if [[ "$reply" == 'all' ]]; then
        chosen=("${offered[@]}")
    else
        local token position_id
        local saved_ifs="$IFS"
        IFS=','
        local tokens=($reply)
        IFS="$saved_ifs"

        for token in "${tokens[@]}"; do
            local expanded
            expanded=$(expand_token "$token" "${#offered[@]}") || return 1
            while IFS= read -r position_id; do
                [[ -n "$position_id" ]] || continue
                chosen+=("${offered[position_id - 1]}")
            done <<< "$expanded"
        done
    fi

    # Deduplicate while preserving the order the user typed.
    local index
    for index in ${chosen[@]+"${chosen[@]}"}; do
        contains "$index" ${SELECTED[@]+"${SELECTED[@]}"} || SELECTED+=("$index")
    done

    if (( ${#SELECTED[@]} == 0 )); then
        echo 'Nothing selected.'
        return 1
    fi
    return 0
}

confirm() {
    printf '%s [yes/no]: ' "$1"
    local reply
    read -r reply
    [[ "$reply" == 'yes' ]]
}

# ---------------------------------------------------------------------------
# Per-remote operations
#
# Each takes an index into REMOTE_NAMES and returns non-zero if it did nothing.
# ---------------------------------------------------------------------------

encrypt_remote() {
    local index="$1"
    local name="${REMOTE_NAMES[index]}"
    local plain encrypted temp
    plain="$(backend_path "$name")"
    encrypted="$(encrypted_path "$name")"

    echo
    say "$C_BLUE" "🔐 Encrypting '$name'"

    # Prefer the live rclone.conf so an edited remote is captured as it stands.
    if (( REMOTE_IN_ACTIVE[index] )); then
        if extract_section "$name" "$plain"; then
            info "Extracted section [$name] from the active rclone.conf"
        else
            fail "Could not extract [$name] from rclone.conf"
            return 1
        fi
    elif [[ -f "$plain" ]]; then
        info "Using existing backend file: $(tilde "$plain")"
    else
        warn "'$name' has no plaintext source. Decrypt it first."
        return 1
    fi
    chmod "$SECRET_MODE" "$plain"

    temp=$(mktemp "$SECURED_DIR/.encrypt.XXXXXX")
    trap 'rm -f "$temp"' RETURN

    echo "🔐 Enter NEW passphrase for '$name':"
    if ! gpg_run --symmetric --cipher-algo AES256 --yes --output "$temp" "$plain"; then
        warn "Encryption failed for '$name'."
        return 1
    fi
    if ! gpg_archive_sane "$temp"; then
        warn "The new archive for '$name' is malformed. Original left untouched."
        return 1
    fi

    # Only now is the previous archive touched, and a copy is kept.
    backup_file "$encrypted"
    mv "$temp" "$encrypted"
    chmod "$SECRET_MODE" "$encrypted"
    trap - RETURN

    info "Encrypted -> rclone_${name}.gpg"
    register_remote "$name"
}

decrypt_remote() {
    local index="$1"
    local name="${REMOTE_NAMES[index]}"
    local plain encrypted
    plain="$(backend_path "$name")"
    encrypted="$(encrypted_path "$name")"

    echo
    say "$C_BLUE" "🔓 Decrypting '$name'"

    if [[ ! -f "$encrypted" ]]; then
        warn "'$name' has no encrypted file."
        return 1
    fi
    if [[ -f "$plain" ]]; then
        if ! confirm "The backend file for '$name' already exists. Overwrite?"; then
            echo 'Skipped.'
            return 0
        fi
        backup_file "$plain"
    fi

    echo "🔒 Enter passphrase for '$name':"
    if ! gpg_run --quiet --yes --decrypt --output "$plain" < "$encrypted"; then
        rm -f "$plain"
        warn "Decryption failed for '$name'."
        return 1
    fi

    chmod "$SECRET_MODE" "$plain"
    info "Decrypted -> $(tilde "$plain")"
    register_remote "$name"
}

verify_remote() {
    local index="$1"
    local name="${REMOTE_NAMES[index]}"
    local encrypted
    encrypted="$(encrypted_path "$name")"

    echo
    if [[ ! -f "$encrypted" ]]; then
        warn "'$name' is not encrypted yet."
        return 1
    fi

    echo "🔒 Enter passphrase to verify '$name':"
    if gpg_run --quiet --decrypt < "$encrypted" > /dev/null 2>&1; then
        info "Passphrase is correct for '$name'."
    else
        warn "Passphrase is incorrect for '$name'."
    fi
}

change_passphrase() {
    local index="$1"
    local name="${REMOTE_NAMES[index]}"
    local encrypted temp_plain temp_cipher
    encrypted="$(encrypted_path "$name")"

    echo
    say "$C_BLUE" "🔑 Changing the passphrase for '$name'"

    if [[ ! -f "$encrypted" ]]; then
        warn "'$name' is not encrypted yet. Use Encrypt instead."
        return 1
    fi

    # The decrypted copy lives in the backends directory, not /tmp, so it stays
    # on the same already-restricted filesystem as the other plaintext configs.
    temp_plain=$(mktemp "$BACKENDS_DIR/.rotate.XXXXXX")
    temp_cipher=$(mktemp "$SECURED_DIR/.rotate.XXXXXX")
    chmod "$SECRET_MODE" "$temp_plain" "$temp_cipher"
    trap 'rm -f "$temp_plain" "$temp_cipher"' RETURN

    echo "🔒 Enter the CURRENT passphrase for '$name':"
    if ! gpg_run --quiet --yes --decrypt --output "$temp_plain" < "$encrypted"; then
        warn "Decryption failed for '$name'. The passphrase may be wrong."
        return 1
    fi

    echo
    echo "🔐 Enter the NEW passphrase for '$name':"
    if ! gpg_run --symmetric --cipher-algo AES256 --yes --output "$temp_cipher" "$temp_plain"; then
        warn "Re-encryption failed for '$name'."
        return 1
    fi
    if ! gpg_archive_sane "$temp_cipher"; then
        warn "The re-encrypted archive for '$name' is malformed. Original left untouched."
        return 1
    fi

    backup_file "$encrypted"
    mv "$temp_cipher" "$encrypted"
    chmod "$SECRET_MODE" "$encrypted"
    rm -f "$temp_plain"
    trap - RETURN

    info "Passphrase changed for '$name'."
}

lock_remote() {
    local index="$1"
    local name="${REMOTE_NAMES[index]}"
    local plain
    plain="$(backend_path "$name")"

    echo
    if [[ ! -f "$(encrypted_path "$name")" ]]; then
        warn "Refusing to lock '$name': there is no rclone_${name}.gpg. Encrypt it first."
        return 1
    fi

    if [[ -f "$plain" ]]; then
        rm -f "$plain"
        info "Removed the plaintext backend for '$name'."
    else
        info "'$name' already had no plaintext backend."
    fi
}

sync_remote_from_active() {
    local index="$1"
    local name="${REMOTE_NAMES[index]}"

    if (( REMOTE_IN_ACTIVE[index] == 0 )); then
        warn "'$name' is not in the active rclone.conf. Skipped."
        return 1
    fi
    if extract_section "$name" "$(backend_path "$name")"; then
        info "Synced [$name] -> $(tilde "$(backend_path "$name")")"
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# Whole-config operations
# ---------------------------------------------------------------------------

# A rebuild reads backend files, so a remote present only in rclone.conf would
# be erased by one. Rescue those — but only when they have no .gpg to fall back
# on. A remote that IS encrypted and has no backend file was deliberately
# locked, and must be allowed to drop out of the active config.
preserve_unbacked_remotes() {
    [[ -f "$RCLONE_CONF" ]] || return 0

    local name preserved=()
    while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        [[ -f "$(backend_path "$name")" ]] && continue
        [[ -f "$(encrypted_path "$name")" ]] && continue
        extract_section "$name" "$(backend_path "$name")" && preserved+=("$name")
    done < <(active_section_names)

    if (( ${#preserved[@]} > 0 )); then
        warn "Preserved remote(s) that existed only in rclone.conf: ${preserved[*]}"
        warn "They are NOT encrypted yet — run Encrypt on them."
    fi
}

# Rebuild rclone.conf from every decrypted backend file.
rebuild_active_config() {
    preserve_unbacked_remotes

    local temp found=0 file

    temp=$(mktemp "$BACKENDS_DIR/.rebuild.XXXXXX")
    chmod "$SECRET_MODE" "$temp"

    for file in "$BACKENDS_DIR"/*.conf; do
        strip_trailing_blank_lines "$file" >> "$temp"
        printf '\n' >> "$temp"   # exactly one blank line between sections
        found=1
    done

    if (( found == 0 )); then
        rm -f "$temp"
        if [[ -f "$RCLONE_CONF" ]]; then
            backup_file "$RCLONE_CONF"
            rm -f "$RCLONE_CONF"
        fi
        warn "No decrypted backends remain. The active rclone.conf was removed."
        return 0
    fi

    write_over "$temp" "$RCLONE_CONF" "$SECRET_MODE"
    rm -f "$temp"
    info "Rebuilt the active config: $(tilde "$RCLONE_CONF")"
}

lock_everything() {
    echo
    scan_remotes

    local i unencrypted=()
    for i in "${!REMOTE_NAMES[@]}"; do
        (( REMOTE_HAS_GPG[i] == 0 )) && unencrypted+=("${REMOTE_NAMES[i]}")
    done

    if (( ${#unencrypted[@]} > 0 )); then
        warn "These remotes are NOT encrypted and would be lost: ${unencrypted[*]}"
        if ! confirm 'Lock anyway, destroying them?'; then
            echo 'Aborted.'
            return 0
        fi
    fi

    rm -f "$BACKENDS_DIR"/*.conf
    rm -f "$RCLONE_CONF"
    info 'Locked everything: backend files cleared, rclone.conf removed.'
}

# ---------------------------------------------------------------------------
# Menu
# ---------------------------------------------------------------------------

# apply_to_selection <function> <verb> [allowed states...]
apply_to_selection() {
    local operation="$1" verb="$2"
    shift 2

    prompt_selection "$verb" "$@" || return 0

    local index succeeded=0 skipped=0
    for index in "${SELECTED[@]}"; do
        if "$operation" "$index"; then
            succeeded=$(( succeeded + 1 ))
        else
            skipped=$(( skipped + 1 ))
        fi
    done

    echo
    info "Done: $succeeded succeeded, $skipped skipped or failed."
}

action_decrypt() {
    apply_to_selection decrypt_remote 'decrypt'
    if confirm 'Rebuild the active rclone.conf from all decrypted backends now?'; then
        rebuild_active_config
    fi
}

action_lock() {
    apply_to_selection lock_remote 'lock'
    rebuild_active_config
}

action_sync() {
    if [[ ! -f "$RCLONE_CONF" ]]; then
        warn 'There is no active rclone.conf to sync from.'
        return 0
    fi
    apply_to_selection sync_remote_from_active 'sync from the active rclone.conf'
    info 'Encrypt the synced remote(s) to persist the change.'
}

show_menu() {
    local choice
    while true; do
        show_status
        echo
        printf ' %s1%s) Encrypt remote(s)             %s(picks up NEW and MODIFIED remotes)%s\n' "$C_WHITE" "$C_RESET" "$C_DIM" "$C_RESET"
        printf ' %s2%s) Decrypt remote(s)\n' "$C_WHITE" "$C_RESET"
        printf ' %s3%s) Change the passphrase for remote(s)\n' "$C_WHITE" "$C_RESET"
        printf ' %s4%s) Verify the passphrase for remote(s)\n' "$C_WHITE" "$C_RESET"
        printf ' %s5%s) Sync the active rclone.conf -> backend file(s)\n' "$C_WHITE" "$C_RESET"
        printf ' %s6%s) Rebuild the active rclone.conf from decrypted backends\n' "$C_WHITE" "$C_RESET"
        printf ' %s7%s) Lock remote(s)                %s(drop plaintext, keep the .gpg)%s\n' "$C_WHITE" "$C_RESET" "$C_DIM" "$C_RESET"
        printf ' %s8%s) Lock everything\n' "$C_WHITE" "$C_RESET"
        printf ' %s9%s) Refresh\n' "$C_WHITE" "$C_RESET"
        printf ' %sq%s) Exit\n' "$C_WHITE" "$C_RESET"
        printf 'Select action: '

        read -r choice
        case "$choice" in
            1)   apply_to_selection encrypt_remote   'encrypt' ;;
            2)   action_decrypt ;;
            3)   apply_to_selection change_passphrase 'change the passphrase' ;;
            4)   apply_to_selection verify_remote     'verify' ;;
            5)   action_sync ;;
            6)   rebuild_active_config ;;
            7)   action_lock ;;
            8)   lock_everything ;;
            9)   continue ;;
            q|Q) exit 0 ;;
            *)   warn 'Invalid option' ;;
        esac

        echo
        printf 'Press Enter to continue...'
        read -r _
    done
}

# Print the header comment block, stopping at the first non-comment line.
usage() {
    awk 'NR > 1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
}

main() {
    case "${1:-}" in
        -h|--help) usage; exit 0 ;;
        '')        ;;
        *)         die "Unknown argument: $1 (try --help)" ;;
    esac

    preflight
    show_menu
}

main "$@"
