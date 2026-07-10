#!/usr/bin/env bash

set -euo pipefail

SECURED_DIR="$HOME/.config/_secured"
BACKENDS_DIR="$HOME/.config/rclone-backends"
RCL_CONF_DIR="$HOME/.config/rclone"
RCL_CONF_FILE="$RCL_CONF_DIR/rclone.conf"
PROPERTIES_FILE="$SECURED_DIR/locations.properties"

# Ensure GPG TTY is set
export GPG_TTY=$(tty 2>/dev/null || echo "")

log_info() { echo -e "✅ \033[1;32m$1\033[0m"; }
log_warn() { echo -e "⚠️  \033[1;33m$1\033[0m"; }
log_err()  { echo -e "❌ \033[1;31m$1\033[0m"; exit 1; }

trim() {
    local -n var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
}

# Ensure directories exist
mkdir -p "$SECURED_DIR" "$BACKENDS_DIR" "$RCL_CONF_DIR"

show_status() {
    echo -e "\033[1;36m──────────────────────────────────────────────────────────\033[0m"
    echo -e " ⚡ \033[1;37mRCLONE CONFIGURATION STATUS\033[0m"
    echo -e "\033[1;36m──────────────────────────────────────────────────────────\033[0m"
    
    # 1. Check GPG files in _secured
    echo -e "\033[1;34m🔒 Secured Backends (GPG):\033[0m"
    local gpg_files=()
    shopt -s nullglob
    for f in "$SECURED_DIR"/rclone_*.gpg; do
        gpg_files+=("$(basename "$f")")
    done
    
    if [[ ${#gpg_files[@]} -eq 0 ]]; then
        echo "   No secured rclone backends found in ~/.config/_secured/"
    else
        for gf in "${gpg_files[@]}"; do
            local name="${gf#rclone_}"
            name="${name%.gpg}"
            local decrypted_file="$BACKENDS_DIR/${name}.conf"
            local dec_status="\033[1;33m🔒 Locked\033[0m"
            if [[ -f "$decrypted_file" ]]; then
                dec_status="\033[1;32m🔓 Decrypted\033[0m"
            fi
            echo -e "   - $gf  [$dec_status]"
        done
    fi
    
    # 2. Check active assembled config
    echo ""
    echo -e "\033[1;34m⚙️  Active Configuration:\033[0m"
    if [[ -f "$RCL_CONF_FILE" ]]; then
        local size
        size=$(wc -c < "$RCL_CONF_FILE")
        echo -e "   - File   : $RCL_CONF_FILE ($size bytes)"
        
        # List sections
        local backends=()
        while read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^\[([a-zA-Z0-9_-]+)\] ]]; then
                backends+=("${BASH_REMATCH[1]}")
            fi
        done < "$RCL_CONF_FILE"
        if [[ ${#backends[@]} -gt 0 ]]; then
            echo -e "   - Active Backends : \033[1;32m${backends[*]}\033[0m"
        else
            echo -e "   - Active Backends : None"
        fi
    else
        echo -e "   - File   : \033[1;31mNot configured\033[0m"
    fi
    echo -e "\033[1;36m──────────────────────────────────────────────────────────\033[0m"
}

handle_decrypt_and_assemble() {
    echo ""
    echo "🔓 Decrypting and Assembling Configurations..."
    
    shopt -s nullglob
    local gpg_files=()
    for f in "$SECURED_DIR"/rclone_*.gpg; do
        gpg_files+=("$(basename "$f")")
    done
    
    if [[ ${#gpg_files[@]} -eq 0 ]]; then
        log_warn "No secured rclone GPG files found in ~/.config/_secured/"
        return
    fi
    
    local decrypted_count=0
    for gf in "${gpg_files[@]}"; do
        local name="${gf#rclone_}"
        name="${name%.gpg}"
        local enc_file="$SECURED_DIR/$gf"
        local dec_file="$BACKENDS_DIR/${name}.conf"
        
        if [[ -f "$dec_file" ]]; then
            log_info "Backend '$name' is already decrypted."
            decrypted_count=$((decrypted_count+1))
            continue
        fi
        
        echo "🔒 Enter passphrase for '$gf':"
        if gpg --quiet --yes --pinentry-mode loopback --decrypt --output "$dec_file" < "$enc_file"; then
            log_info "Decrypted '$gf' successfully."
            chmod 600 "$dec_file"
            decrypted_count=$((decrypted_count+1))
        else
            log_warn "Failed to decrypt '$gf'. Skipping."
        fi
    done
    
    if [[ $decrypted_count -gt 0 ]]; then
        # Assemble
        local temp_conf
        temp_conf=$(mktemp)
        for conf in "$BACKENDS_DIR"/*.conf; do
            cat "$conf" >> "$temp_conf"
            echo "" >> "$temp_conf" # Add newline spacer
        done
        
        # Move to active config file
        cat "$temp_conf" > "$RCL_CONF_FILE"
        rm -f "$temp_conf"
        chmod 600 "$RCL_CONF_FILE"
        log_info "Assembled active config at: $RCL_CONF_FILE"
    else
        log_warn "No configurations decrypted. Active config not assembled."
    fi
}

handle_split_and_encrypt() {
    echo ""
    if [[ ! -f "$RCL_CONF_FILE" ]]; then
        log_err "No active rclone config found at: $RCL_CONF_FILE"
    fi
    
    echo "⚙️  Splitting and Encrypting Active Configurations..."
    
    # Split
    local current_section=""
    local section_file=""
    local sections=()
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^\[([a-zA-Z0-9_-]+)\] ]]; then
            current_section="${BASH_REMATCH[1]}"
            sections+=("$current_section")
            section_file="$BACKENDS_DIR/${current_section}.conf"
            echo "$line" > "$section_file"
            chmod 600 "$section_file"
        elif [[ -n "$current_section" ]]; then
            echo "$line" >> "$section_file"
        fi
    done < "$RCL_CONF_FILE"
    
    log_info "Split active config into individual backend files under ~/.config/rclone-backends/"
    
    # Encrypt each split config back to GPG
    for name in "${sections[@]}"; do
        local dec_file="$BACKENDS_DIR/${name}.conf"
        local enc_file="$SECURED_DIR/rclone_${name}.gpg"
        
        echo ""
        echo "🔐 Encrypting backend '$name'..."
        if gpg --symmetric --cipher-algo AES256 --pinentry-mode loopback --output "$enc_file" "$dec_file"; then
            log_info "Encrypted to: rclone_${name}.gpg"
            
            # Register in locations.properties automatically if not present
            local mapping_key="rclone_${name}.gpg"
            local mapping_val="~/.config/rclone-backends/${name}.conf"
            local registered=false
            
            if [[ -f "$PROPERTIES_FILE" ]]; then
                if grep -q "^$mapping_key=" "$PROPERTIES_FILE"; then
                    registered=true
                fi
            fi
            
            if [[ "$registered" == "false" ]]; then
                echo "$mapping_key=$mapping_val" >> "$PROPERTIES_FILE"
                log_info "Registered mapping in locations.properties"
            fi
        else
            log_err "Failed to encrypt '$name'."
        fi
    done
}

handle_lock() {
    echo ""
    echo "🔒 Locking configurations (deleting decrypted configs)..."
    
    # Delete decrypted backend configurations
    rm -f "$BACKENDS_DIR"/*.conf
    log_info "Deleted files in ~/.config/rclone-backends/"
    
    # Delete active assembled rclone.conf
    rm -f "$RCL_CONF_FILE"
    log_info "Deleted active config file at: $RCL_CONF_FILE"
}

show_menu() {
    while true; do
        show_status
        echo "⚡ RCLONE CONFIGURATION MANAGER"
        echo "1. Decrypt and Assemble active config"
        echo "2. Split and Encrypt current config"
        echo "3. Lock configurations (Delete decrypted files)"
        echo "4. Exit"
        echo -n "Select action: "
        read -r action
        
        case "$action" in
            1) handle_decrypt_and_assemble ;;
            2) handle_split_and_encrypt ;;
            3) handle_lock ;;
            4) exit 0 ;;
            *) log_warn "Invalid option" ;;
        esac
        echo ""
    done
}

# Entry point
show_menu
