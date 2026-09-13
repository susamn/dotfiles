#!/usr/bin/env bash
#
# generate-secure-resources.sh — symmetric GPG vault for individual files
#
# Every protected file is described by one line of
# ~/.config/_secured/locations.properties:
#
#     <name>.gpg=<path it decrypts back to>
#
# The encrypted copy lives in ~/.config/_secured/ and the decrypted copy at the
# mapped path. Each resource has its own passphrase, so they are encrypted,
# decrypted and rotated one at a time.
#
# rclone remotes registered by rclone-config-manager.sh appear here too; the
# two scripts share this properties file as their contract.
#
# Usage: generate-secure-resources.sh [-h|--help]
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SECURED_DIR="$HOME/.config/_secured"
PROPERTIES_FILE="$SECURED_DIR/locations.properties"

# Decrypted secrets are owner-only unless the name marks them as public.
PRIVATE_MODE=600
PUBLIC_MODE=644
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
info()  { say "$C_GREEN" "✅ $1"; }
rule()  { say "$C_CYAN"  "$1"; }
# Diagnostics go to stderr so they never land inside a command substitution.
warn()  { say "$C_YELLOW" "⚠️  $1" >&2; }
die()   { say "$C_RED"    "❌ $1" >&2; exit 1; }

# Pad text to a width first, then colour it, so escape sequences never count
# toward the column width.
cell() {
    local text="$1" colour="$2" width="$3"
    printf '%s%-*s%s' "$colour" "$width" "$text" "$C_RESET"
}

# Shorten for display: $HOME becomes ~, and over-long text is ellipsised.
tilde() { printf '%s' "${1/#$HOME/\~}"; }
# Truncate to fit a column. ASCII only: printf pads %-*s by bytes, so a
# multi-byte ellipsis would silently shift every column after it.
elide() {
    local text="$1" width="$2"
    if (( ${#text} > width )); then
        printf '%s...' "${text:0:width-3}"
    else
        printf '%s' "$text"
    fi
}

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
    for cmd in awk grep sort mktemp chmod cp mv date; do
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

    mkdir -p "$SECURED_DIR"
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

# Modification time, without depending on python3. GNU and busybox date both
# understand -r; stat is the fallback; neither is required.
file_mtime() {
    local file="$1" out
    [[ -e "$file" ]] || { printf '%s' '-'; return 0; }
    if out=$(date -r "$file" '+%Y-%m-%d %H:%M' 2>/dev/null) && [[ -n "$out" ]]; then
        printf '%s' "$out"
    elif out=$(stat -c '%y' "$file" 2>/dev/null) && [[ -n "$out" ]]; then
        printf '%s' "${out:0:16}"
    else
        printf '%s' 'unknown'
    fi
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

# Decrypted secrets are owner-only unless the name marks them public. A name
# containing both (id_ed25519.pub.private.gpg) is treated as private.
target_mode() {
    case "$1" in
        *private*|*credentials*) printf '%s' "$PRIVATE_MODE" ;;
        *pub*|*public*)          printf '%s' "$PUBLIC_MODE" ;;
        *)                       printf '%s' "$PRIVATE_MODE" ;;
    esac
}

# ---------------------------------------------------------------------------
# locations.properties
#
# Format:  <gpg filename>=<path to decrypt to>
# Blank lines and #comments are preserved by every rewrite.
# ---------------------------------------------------------------------------

# Key of a property line, whitespace trimmed. Empty for blanks and comments.
property_key() {
    local key="${1%%=*}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    printf '%s' "$key"
}

# Value of a property line, whitespace trimmed, ~ left as written.
property_value() {
    local line="$1"
    [[ "$line" == *=* ]] || { printf ''; return 0; }
    local value="${line#*=}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

# Rewrite the properties file. Uses `cat >` rather than `mv` so a symlinked
# properties file keeps its symlink.
properties_write() {
    local source="$1"
    cat "$source" > "$PROPERTIES_FILE"
    chmod "$PROPERTIES_MODE" "$PROPERTIES_FILE"
}

# Add or update one mapping, leaving comments, blanks and order intact.
properties_set() {
    local key="$1" value="$2"
    local temp updated=0 line
    temp=$(mktemp)

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$(property_key "$line")" == "$key" ]]; then
            printf '%s=%s\n' "$key" "$value" >> "$temp"
            updated=1
        else
            printf '%s\n' "$line" >> "$temp"
        fi
    done < "$PROPERTIES_FILE"

    (( updated == 0 )) && printf '%s=%s\n' "$key" "$value" >> "$temp"

    properties_write "$temp"
    rm -f "$temp"
}

properties_remove() {
    local key="$1" temp line
    temp=$(mktemp)

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$(property_key "$line")" == "$key" ]] && continue
        printf '%s\n' "$line" >> "$temp"
    done < "$PROPERTIES_FILE"

    properties_write "$temp"
    rm -f "$temp"
}

# ---------------------------------------------------------------------------
# Inventory
#
# A resource is any mapping in the properties file, plus any .gpg sitting in
# the secured directory with no mapping at all — those would otherwise be
# invisible and unrestorable, so they are surfaced as UNTRACKED.
# ---------------------------------------------------------------------------

RES_KEY=()       # the .gpg filename
RES_TARGET=()    # absolute path it decrypts to ('' when untracked)
RES_STATE=()

encrypted_path() { printf '%s/%s' "$SECURED_DIR" "$1"; }

# DECRYPTED plaintext is present · LOCKED encrypted only
# BROKEN     mapped but the .gpg is gone
# UNTRACKED  a .gpg with no mapping, so nothing knows where it belongs
classify_resource() {
    local key="$1" target="$2"

    if [[ -z "$target" ]];                      then printf 'UNTRACKED'
    elif [[ ! -f "$(encrypted_path "$key")" ]]; then printf 'BROKEN'
    elif [[ -e "$target" ]];                    then printf 'DECRYPTED'
    else                                             printf 'LOCKED'
    fi
}

scan_resources() {
    RES_KEY=(); RES_TARGET=(); RES_STATE=()

    local line key value target
    while IFS= read -r line || [[ -n "$line" ]]; do
        key="$(property_key "$line")"
        [[ -z "$key" || "$key" == \#* ]] && continue
        [[ "$line" == *=* ]] || continue

        value="$(property_value "$line")"
        [[ -z "$value" ]] && continue

        target="${value/#\~/$HOME}"
        RES_KEY+=("$key")
        RES_TARGET+=("$target")
        RES_STATE+=("$(classify_resource "$key" "$target")")
    done < "$PROPERTIES_FILE"

    # Surface encrypted files nothing maps. Backups (*.gpg.<stamp>.backup) do
    # not match the glob, so they are correctly ignored.
    local file name
    for file in "$SECURED_DIR"/*.gpg; do
        name="${file##*/}"
        contains "$name" ${RES_KEY[@]+"${RES_KEY[@]}"} && continue
        RES_KEY+=("$name")
        RES_TARGET+=('')
        RES_STATE+=('UNTRACKED')
    done
}

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

state_label() {
    case "$1" in
        DECRYPTED) printf '%s' 'Decrypted' ;;
        LOCKED)    printf '%s' 'Locked' ;;
        BROKEN)    printf '%s' 'Broken' ;;
        UNTRACKED) printf '%s' 'Untracked' ;;
        *)         printf '%s' "$1" ;;
    esac
}

state_colour() {
    case "$1" in
        DECRYPTED) printf '%s' "$C_GREEN" ;;
        LOCKED)    printf '%s' "$C_YELLOW" ;;
        BROKEN)    printf '%s' "$C_RED" ;;
        UNTRACKED) printf '%s' "$C_MAGENTA" ;;
        *)         printf '%s' "$C_RESET" ;;
    esac
}

HEAVY='══════════════════════════════════════════════════════════════════════════════════════════'
LIGHT='──────────────────────────────────────────────────────────────────────────────────────────'

show_status() {
    scan_resources

    echo
    rule "$HEAVY"
    printf ' 🔐 %sSECURE RESOURCE MANAGER%s   %s(%s)%s\n' \
        "$C_WHITE" "$C_RESET" "$C_DIM" "$(tilde "$SECURED_DIR")" "$C_RESET"
    rule "$LIGHT"
    printf ' %s%-4s %-30s %-32s %-17s %s%s\n' \
        "$C_WHITE" 'ID' 'RESOURCE (GPG)' 'DECRYPTS TO' 'ENCRYPTED' 'STATE' "$C_RESET"
    rule "$LIGHT"

    if (( ${#RES_KEY[@]} == 0 )); then
        echo '   No secure resources configured.'
    else
        local i target_text
        for i in "${!RES_KEY[@]}"; do
            if [[ -n "${RES_TARGET[i]}" ]]; then
                target_text="$(elide "$(tilde "${RES_TARGET[i]}")" 32)"
            else
                target_text='(not mapped)'
            fi
            printf ' %s%-4d%s %-30s %-32s %-17s %s\n' \
                "$C_GREEN" "$((i + 1))" "$C_RESET" \
                "$(elide "${RES_KEY[i]}" 30)" \
                "$target_text" \
                "$(file_mtime "$(encrypted_path "${RES_KEY[i]}")")" \
                "$(cell "$(state_label "${RES_STATE[i]}")" "$(state_colour "${RES_STATE[i]}")" 10)"
        done
    fi

    rule "$HEAVY"
    say "$C_DIM" " DECRYPTED = plaintext is on disk · LOCKED = encrypted only"
    say "$C_DIM" " BROKEN = mapped but the .gpg is missing · UNTRACKED = a .gpg nothing maps"

    report_target_conflicts
}

# Two resources mapped to the same path will overwrite each other on decrypt,
# with whichever ran last winning — and the file modes may differ too. That is
# almost always a mistake in the properties file, so say so loudly.
report_target_conflicts() {
    local i j reported=()

    for i in "${!RES_KEY[@]}"; do
        [[ -z "${RES_TARGET[i]}" ]] && continue
        contains "${RES_TARGET[i]}" ${reported[@]+"${reported[@]}"} && continue

        local clash=()
        for j in "${!RES_KEY[@]}"; do
            [[ "${RES_TARGET[j]}" == "${RES_TARGET[i]}" ]] && clash+=("${RES_KEY[j]}")
        done

        if (( ${#clash[@]} > 1 )); then
            reported+=("${RES_TARGET[i]}")
            echo
            warn "Conflict: ${#clash[@]} resources decrypt to $(tilde "${RES_TARGET[i]}")"
            local name
            for name in "${clash[@]}"; do
                printf '     - %s  (mode %s)
' "$name" "$(target_mode "$name")" >&2
            done
            warn 'Decrypting them in turn overwrites the same file. Fix the mapping.'
        fi
    done
}

# ---------------------------------------------------------------------------
# Selection
#
# Every action shares this prompt, which accepts ids (1,3), ranges (2-4),
# 'all', or 'q' to cancel. SELECTED receives indices into RES_KEY.
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

# prompt_selection <verb> [allowed states...] — no states means any resource.
prompt_selection() {
    local verb="$1"; shift
    SELECTED=()

    if (( ${#RES_KEY[@]} == 0 )); then
        warn "No resources to $verb."
        return 1
    fi

    local offered=() i
    for i in "${!RES_KEY[@]}"; do
        if (( $# == 0 )) || contains "${RES_STATE[i]}" "$@"; then
            offered+=("$i")
        fi
    done

    if (( ${#offered[@]} == 0 )); then
        warn "No resources are eligible to $verb."
        return 1
    fi

    echo
    say "$C_BLUE" "--- Select resource(s) to $verb ---"

    local position=1
    for i in "${offered[@]}"; do
        printf ' %s%-3d%s %-30s %s\n' "$C_GREEN" "$position" "$C_RESET" \
            "$(elide "${RES_KEY[i]}" 30)" \
            "$(cell "$(state_label "${RES_STATE[i]}")" "$(state_colour "${RES_STATE[i]}")" 10)"
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
        local token position_id expanded
        local saved_ifs="$IFS"
        IFS=','
        local tokens=($reply)
        IFS="$saved_ifs"

        for token in "${tokens[@]}"; do
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

# Read a value, falling back to a default when the reply is empty.
# The prompt goes to stderr so that $(ask ...) captures only the answer.
ask() {
    local prompt="$1" fallback="${2:-}" reply
    if [[ -n "$fallback" ]]; then
        printf '%s [default: %s]: ' "$prompt" "$fallback" >&2
    else
        printf '%s: ' "$prompt" >&2
    fi
    read -r reply
    printf '%s' "${reply:-$fallback}"
}

# ---------------------------------------------------------------------------
# Per-resource operations
#
# Each takes an index into RES_KEY and returns non-zero if it did nothing.
# ---------------------------------------------------------------------------

decrypt_resource() {
    local index="$1"
    local key="${RES_KEY[index]}"
    local target="${RES_TARGET[index]}"
    local encrypted
    encrypted="$(encrypted_path "$key")"

    echo
    say "$C_BLUE" "🔓 Decrypting '$key'"

    if [[ -z "$target" ]]; then
        warn "'$key' has no mapping. Register it first, so it knows where to go."
        return 1
    fi
    if [[ ! -f "$encrypted" ]]; then
        warn "Encrypted file not found: $(tilde "$encrypted")"
        return 1
    fi
    if [[ -d "$target" ]]; then
        warn "The target path is a directory: $(tilde "$target")"
        return 1
    fi

    if [[ -f "$target" ]]; then
        if ! confirm "'$(tilde "$target")' already exists. Overwrite?"; then
            echo 'Skipped.'
            return 0
        fi
        backup_file "$target"
    fi

    mkdir -p "$(dirname "$target")"

    echo "🔒 Enter the passphrase for '$key':"
    if ! gpg_run --quiet --yes --decrypt --output "$target" < "$encrypted"; then
        rm -f "$target"
        warn "Decryption failed for '$key'."
        return 1
    fi

    chmod "$(target_mode "$key")" "$target"
    info "Decrypted -> $(tilde "$target")  (mode $(target_mode "$key"))"

    check_ssh_key "$target"
}

# Courtesy check after restoring an SSH identity; never fails the operation.
check_ssh_key() {
    local target="$1"
    [[ "$target" == */.ssh/id_* && "$target" != *.pub ]] || return 0
    command -v ssh >/dev/null 2>&1 || return 0

    info 'Testing SSH authentication with GitHub...'
    if ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
           -i "$target" -T git@github.com 2>&1 | grep -q 'successfully authenticated'; then
        info 'GitHub authentication succeeded.'
    else
        warn 'GitHub authentication did not succeed (wrong key, or no network).'
    fi
}

# Re-encrypt a resource from the plaintext currently at its target path.
reencrypt_resource() {
    local index="$1"
    local key="${RES_KEY[index]}"
    local target="${RES_TARGET[index]}"
    local encrypted temp
    encrypted="$(encrypted_path "$key")"

    echo
    say "$C_BLUE" "🔐 Re-encrypting '$key' from its decrypted copy"

    if [[ -z "$target" || ! -f "$target" ]]; then
        warn "'$key' has no decrypted file to read from."
        return 1
    fi

    temp=$(mktemp "$SECURED_DIR/.encrypt.XXXXXX")
    trap 'rm -f "$temp"' RETURN

    echo "🔐 Enter the NEW passphrase for '$key':"
    if ! gpg_run --symmetric --cipher-algo AES256 --yes --output "$temp" "$target"; then
        warn "Encryption failed for '$key'."
        return 1
    fi
    if ! gpg_archive_sane "$temp"; then
        warn "The new archive for '$key' is malformed. Original left untouched."
        return 1
    fi

    backup_file "$encrypted"
    mv "$temp" "$encrypted"
    chmod "$PRIVATE_MODE" "$encrypted"
    trap - RETURN

    info "Re-encrypted from $(tilde "$target")"
}

verify_resource() {
    local index="$1"
    local key="${RES_KEY[index]}"
    local encrypted
    encrypted="$(encrypted_path "$key")"

    echo
    if [[ ! -f "$encrypted" ]]; then
        warn "'$key' has no encrypted file to verify."
        return 1
    fi

    echo "🔒 Enter the passphrase to verify '$key':"
    if gpg_run --quiet --decrypt < "$encrypted" > /dev/null 2>&1; then
        info "Passphrase is correct for '$key'."
    else
        warn "Passphrase is incorrect for '$key'."
    fi
}

change_passphrase() {
    local index="$1"
    local key="${RES_KEY[index]}"
    local encrypted temp_plain temp_cipher
    encrypted="$(encrypted_path "$key")"

    echo
    say "$C_BLUE" "🔑 Changing the passphrase for '$key'"

    if [[ ! -f "$encrypted" ]]; then
        warn "'$key' has no encrypted file."
        return 1
    fi

    # Both temporaries live in the already-restricted secured directory rather
    # than /tmp, which may be world-traversable or a different filesystem.
    temp_plain=$(mktemp "$SECURED_DIR/.rotate.XXXXXX")
    temp_cipher=$(mktemp "$SECURED_DIR/.rotate.XXXXXX")
    chmod "$PRIVATE_MODE" "$temp_plain" "$temp_cipher"
    trap 'rm -f "$temp_plain" "$temp_cipher"' RETURN

    echo "🔒 Enter the CURRENT passphrase for '$key':"
    if ! gpg_run --quiet --yes --decrypt --output "$temp_plain" < "$encrypted"; then
        warn "Decryption failed for '$key'. The passphrase may be wrong."
        return 1
    fi

    echo
    echo "🔐 Enter the NEW passphrase for '$key':"
    if ! gpg_run --symmetric --cipher-algo AES256 --yes --output "$temp_cipher" "$temp_plain"; then
        warn "Re-encryption failed for '$key'."
        return 1
    fi
    if ! gpg_archive_sane "$temp_cipher"; then
        warn "The re-encrypted archive for '$key' is malformed. Original left untouched."
        return 1
    fi

    backup_file "$encrypted"
    mv "$temp_cipher" "$encrypted"
    chmod "$PRIVATE_MODE" "$encrypted"
    rm -f "$temp_plain"
    trap - RETURN

    info "Passphrase changed for '$key'."
}

# Remove the decrypted copy, keeping the encrypted one.
lock_resource() {
    local index="$1"
    local key="${RES_KEY[index]}"
    local target="${RES_TARGET[index]}"

    echo
    if [[ ! -f "$(encrypted_path "$key")" ]]; then
        warn "Refusing to lock '$key': there is no encrypted copy to restore from."
        return 1
    fi
    if [[ -z "$target" || ! -f "$target" ]]; then
        info "'$key' has no decrypted copy on disk."
        return 0
    fi

    rm -f "$target"
    info "Removed the decrypted copy at $(tilde "$target")"
}

# Give an UNTRACKED .gpg a mapping so it can be restored.
register_resource() {
    local index="$1"
    local key="${RES_KEY[index]}"

    echo
    say "$C_BLUE" "🔗 Registering '$key'"

    # A sensible guess: the .gpg name without its suffix, under $HOME.
    local suggestion="$HOME/${key%.gpg}"
    local target
    target="$(ask "Path this should decrypt to" "$(tilde "$suggestion")")"
    target="${target/#\~/$HOME}"

    if [[ -z "$target" || "$target" != /* ]]; then
        warn 'The target must be an absolute path (or start with ~).'
        return 1
    fi

    properties_set "$key" "$(tilde "$target")"
    info "Registered: $key -> $(tilde "$target")"
}

delete_resource() {
    local index="$1"
    local key="${RES_KEY[index]}"
    local encrypted
    encrypted="$(encrypted_path "$key")"

    if [[ -f "$encrypted" ]]; then
        rm -f "$encrypted"
        info "Deleted the encrypted file: $key"
    else
        warn "There was no encrypted file at $(tilde "$encrypted")"
    fi

    properties_remove "$key"
    info "Removed the mapping for $key"

    # Earlier rotations and re-encryptions leave timestamped copies behind.
    # They are still encrypted, but they still hold the secret, so say so.
    local leftovers=("$encrypted".*.backup)
    if (( ${#leftovers[@]} > 0 )); then
        warn "${#leftovers[@]} backup copy/copies of '$key' remain in $(tilde "$SECURED_DIR")."
        warn "Remove them by hand if this secret should be gone entirely."
    fi
}

# ---------------------------------------------------------------------------
# Adding a new resource
# ---------------------------------------------------------------------------

add_resource() {
    echo
    say "$C_BLUE" '--- Encrypt a new plaintext file ---'

    local source
    source="$(ask 'Absolute path of the plaintext file to encrypt')"
    source="${source/#\~/$HOME}"

    if [[ -z "$source" || ! -f "$source" ]]; then
        warn "Plaintext file not found: ${source:-<empty>}"
        return 1
    fi

    local name
    name="$(ask "GPG filename to store in $(tilde "$SECURED_DIR")" "${source##*/}.gpg")"

    if [[ "$name" == */* ]]; then
        warn "The GPG filename cannot contain a slash: $name"
        return 1
    fi
    if [[ -z "$name" ]]; then
        warn 'The GPG filename cannot be empty.'
        return 1
    fi

    local target
    target="$(ask 'Path it should decrypt back to' "$(tilde "$source")")"
    target="${target/#\~/$HOME}"

    local encrypted temp
    encrypted="$(encrypted_path "$name")"

    if [[ -f "$encrypted" ]]; then
        if ! confirm "'$name' already exists. Overwrite?"; then
            echo 'Aborted.'
            return 0
        fi
    fi

    temp=$(mktemp "$SECURED_DIR/.encrypt.XXXXXX")
    trap 'rm -f "$temp"' RETURN

    echo "🔐 Enter the passphrase for '$name':"
    if ! gpg_run --symmetric --cipher-algo AES256 --yes --output "$temp" "$source"; then
        warn 'Encryption failed.'
        return 1
    fi
    if ! gpg_archive_sane "$temp"; then
        warn 'The new archive is malformed. Nothing was written.'
        return 1
    fi

    backup_file "$encrypted"
    mv "$temp" "$encrypted"
    chmod "$PRIVATE_MODE" "$encrypted"
    trap - RETURN

    properties_set "$name" "$(tilde "$target")"
    info "Encrypted -> $(tilde "$encrypted")"
    info "Mapped: $name -> $(tilde "$target")"
    warn "You can now delete the plaintext file: $(tilde "$source")"
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

# Deletion is confirmed once for the whole selection rather than per item.
action_delete() {
    prompt_selection 'delete' || return 0

    echo
    warn 'These resources will be permanently deleted:'
    local index
    for index in "${SELECTED[@]}"; do
        printf '   - %s\n' "${RES_KEY[index]}"
    done

    if ! confirm 'Delete them, removing the GPG files and their mappings?'; then
        echo 'Aborted.'
        return 0
    fi

    for index in "${SELECTED[@]}"; do
        echo
        delete_resource "$index"
    done
}

show_menu() {
    local choice
    while true; do
        show_status
        echo
        printf ' %s1%s) Decrypt resource(s)\n' "$C_WHITE" "$C_RESET"
        printf ' %s2%s) Encrypt a new file            %s(adds a new resource)%s\n' "$C_WHITE" "$C_RESET" "$C_DIM" "$C_RESET"
        printf ' %s3%s) Re-encrypt from the decrypted copy\n' "$C_WHITE" "$C_RESET"
        printf ' %s4%s) Change the passphrase for resource(s)\n' "$C_WHITE" "$C_RESET"
        printf ' %s5%s) Verify the passphrase for resource(s)\n' "$C_WHITE" "$C_RESET"
        printf ' %s6%s) Register untracked .gpg file(s)\n' "$C_WHITE" "$C_RESET"
        printf ' %s7%s) Lock resource(s)              %s(delete the plaintext, keep the .gpg)%s\n' "$C_WHITE" "$C_RESET" "$C_DIM" "$C_RESET"
        printf ' %s8%s) Delete resource(s)            %s(removes the .gpg and its mapping)%s\n' "$C_WHITE" "$C_RESET" "$C_DIM" "$C_RESET"
        printf ' %s9%s) Refresh\n' "$C_WHITE" "$C_RESET"
        printf ' %sq%s) Exit\n' "$C_WHITE" "$C_RESET"
        printf 'Select action: '

        read -r choice
        case "$choice" in
            1)   apply_to_selection decrypt_resource   'decrypt'    LOCKED DECRYPTED BROKEN ;;
            2)   add_resource || true ;;
            3)   apply_to_selection reencrypt_resource 'to re-encrypt' DECRYPTED ;;
            4)   apply_to_selection change_passphrase  'change the passphrase' LOCKED DECRYPTED UNTRACKED ;;
            5)   apply_to_selection verify_resource     'verify'     LOCKED DECRYPTED UNTRACKED ;;
            6)   apply_to_selection register_resource   'register'   UNTRACKED ;;
            7)   apply_to_selection lock_resource       'lock'       DECRYPTED ;;
            8)   action_delete ;;
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
