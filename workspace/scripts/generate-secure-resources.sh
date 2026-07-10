#!/usr/bin/env bash

set -euo pipefail

# Ensure password prompt works on macOS/Linux terminal
export GPG_TTY=$(tty 2>/dev/null || echo "")

# --- Utilities ---
log_info() { echo "✅ $1"; }
log_warn() { echo "⚠️  $1"; }
log_err()  { echo "❌ $1"; exit 1; }

create_backup() {
    local file="$1"
    local datestamp=$(date +%Y%m%d_%H%M%S)
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.${datestamp}.backup"
        log_info "Backup created: ${file}.${datestamp}.backup"
    fi
}

# Find the physical directory of this script to resolve the dotfiles root
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
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SECURED_DIR="$DOTFILES_DIR/.config/_secured"
PROPERTIES_FILE="$SECURED_DIR/locations.properties"

if [[ ! -f "$PROPERTIES_FILE" ]]; then
    log_err "Properties file not found at: $PROPERTIES_FILE"
fi

keys=()
targets=()

reload_properties() {
    keys=()
    targets=()
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Strip whitespace
        key=$(echo "$key" | xargs)
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        
        # If no '=' was found on the line, IFS won't split, making value empty
        if [[ -z "$value" ]]; then
            continue
        fi
        value=$(echo "$value" | xargs)
        
        # Expand ~ to $HOME
        value="${value/#\~/$HOME}"
        
        keys+=("$key")
        targets+=("$value")
    done < "$PROPERTIES_FILE"
}

# Initial load
reload_properties

handle_list() {
    echo ""
    echo "--- Configured Secure Resources ---"
    if [[ ${#keys[@]} -eq 0 ]]; then
        echo "No secure resources configured."
        return
    fi
    for i in "${!keys[@]}"; do
        printf "%2d) %s  ->  %s\n" "$((i+1))" "${keys[i]}" "${targets[i]}"
    done
}

handle_decrypt() {
    local idx="$1"
    local key="${keys[idx]}"
    local target="${targets[idx]}"
    local enc_file="$SECURED_DIR/$key"
    
    if [[ -z "$target" ]]; then
        log_err "Target decryption path is empty."
    fi
    
    if [[ -d "$target" ]]; then
        log_err "Target path is a directory: $target"
    fi
    
    if [[ ! -f "$enc_file" ]]; then
        log_err "Encrypted GPG file not found: $enc_file"
    fi
    
    local target_dir
    target_dir="$(dirname "$target")"
    mkdir -p "$target_dir"
    
    if [[ -f "$target" ]]; then
        log_warn "Target file '$target' already exists. Overwrite? [yes/no]"
        read -r confirm
        [[ "$confirm" != "yes" ]] && { echo "❌ Decryption aborted."; return; }
        create_backup "$target"
    fi
    
    log_info "Decrypting '$key' to '$target'..."
    # Use loopback mode to prompt cleanly in terminal standard input
    if gpg --quiet --yes --pinentry-mode loopback --decrypt --output "$target" < "$enc_file"; then
        log_info "Decryption successful!"
        
        # Set proper permissions
        if [[ "$key" == *private* || "$key" == *credentials* ]]; then
            chmod 600 "$target"
        elif [[ "$key" == *pub* || "$key" == *public* ]]; then
            chmod 644 "$target"
        else
            chmod 600 "$target"
        fi
        
        # Post-decryption SSH check
        if [[ "$target" == */.ssh/id_ed25519 ]]; then
            log_info "Testing SSH authentication with GitHub..."
            if ssh -o StrictHostKeyChecking=accept-new -i "$target" -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
                log_info "GitHub authentication succeeded!"
            else
                log_warn "GitHub authentication failed or network issue."
            fi
        fi
    else
        log_err "Decryption failed."
    fi
}

handle_encrypt() {
    echo ""
    echo "--- Encrypt a Plaintext File ---"
    echo -n "Enter the absolute path of the plaintext file to encrypt: "
    read -r source_file
    
    # Expand ~ to $HOME
    source_file="${source_file/#\~/$HOME}"
    
    if [[ ! -f "$source_file" ]]; then
        log_warn "Plaintext file not found at: $source_file"
        return
    fi
    
    # Suggest a default GPG filename based on the source filename
    local default_gpg="$(basename "$source_file").gpg"
    echo -n "Enter the GPG filename to save in .config/_secured/ [default: $default_gpg]: "
    read -r gpg_name
    if [[ -z "$gpg_name" ]]; then
        gpg_name="$default_gpg"
    fi
    
    # Security check: prevent directory traversal
    if [[ "$gpg_name" == */* ]]; then
        log_warn "GPG filename cannot contain slashes (no folders allowed): $gpg_name"
        return
    fi

    echo -n "Enter the target path where this file should be decrypted when restoring (e.g., ~/.ssh/id_ed25519) [default: $source_file]: "
    read -r target_path
    if [[ -z "$target_path" ]]; then
        target_path="$source_file"
    fi
    
    local enc_file="$SECURED_DIR/$gpg_name"
    if [[ -f "$enc_file" ]]; then
        log_warn "Encrypted GPG file '$gpg_name' already exists. Overwrite? [yes/no]"
        read -r confirm
        [[ "$confirm" != "yes" ]] && { echo "❌ Encryption aborted."; return; }
        create_backup "$enc_file"
    fi
    
    log_info "Encrypting '$source_file' to '$enc_file'..."
    # Use loopback mode to securely prompt for passphrase in standard input
    if gpg --symmetric --cipher-algo AES256 --pinentry-mode loopback --output "$enc_file" "$source_file"; then
        log_info "Encryption successful!"
        
        # Update locations.properties with the new mapping
        local temp_prop
        temp_prop=$(mktemp)
        local updated=false
        
        # Process existing properties
        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            local clean_key=$(echo "$key" | xargs)
            # Preserve comments and empty lines
            if [[ -z "$clean_key" || "$clean_key" =~ ^# ]]; then
                echo "$key" >> "$temp_prop"
                continue
            fi
            local clean_val=$(echo "$value" | xargs)
            
            if [[ "$clean_key" == "$gpg_name" ]]; then
                local display_val="${target_path/#$HOME/\~}"
                echo "$clean_key=$display_val" >> "$temp_prop"
                updated=true
            else
                echo "$clean_key=$clean_val" >> "$temp_prop"
            fi
        done < "$PROPERTIES_FILE"
        
        if [[ "$updated" == "false" ]]; then
            local display_val="${target_path/#$HOME/\~}"
            echo "$gpg_name=$display_val" >> "$temp_prop"
        fi
        
        mv "$temp_prop" "$PROPERTIES_FILE"
        chmod 644 "$PROPERTIES_FILE"
        log_info "Updated locations.properties: $gpg_name -> $target_path"
        log_warn "You can now safely delete the plaintext file: $source_file"
        
        # Reload key/target configurations
        reload_properties
    else
        # Cleanup temp file on failure
        [[ -f "${temp_prop:-}" ]] && rm -f "$temp_prop"
        log_err "Encryption failed."
    fi
}

handle_verify() {
    local idx="$1"
    local key="${keys[idx]}"
    local enc_file="$SECURED_DIR/$key"
    
    if [[ ! -f "$enc_file" ]]; then
        log_err "Encrypted GPG file not found: $enc_file"
    fi
    
    echo "🔒 Enter passphrase to verify for '$key':"
    if gpg --quiet --pinentry-mode loopback --decrypt < "$enc_file" > /dev/null; then
        log_info "Passphrase is correct!"
    else
        log_warn "Passphrase is incorrect or decryption failed."
    fi
}

handle_change_passphrase() {
    local idx="$1"
    local key="${keys[idx]}"
    local enc_file="$SECURED_DIR/$key"
    
    if [[ ! -f "$enc_file" ]]; then
        log_err "Encrypted GPG file not found: $enc_file"
    fi
    
    local tmp_plain
    local tmp_cipher
    tmp_plain=$(mktemp)
    tmp_cipher=$(mktemp)
    
    # Ensure cleanup of temp files even on script termination/exit
    trap 'rm -f "$tmp_plain" "$tmp_cipher"' EXIT INT TERM
    
    echo "🔒 Enter current passphrase to decrypt '$key':"
    if ! gpg --quiet --yes --pinentry-mode loopback --decrypt --output "$tmp_plain" < "$enc_file"; then
        log_err "Decryption failed. Passphrase may be incorrect."
    fi
    
    echo ""
    echo "🔐 Enter new passphrase to encrypt '$key':"
    if ! gpg --symmetric --cipher-algo AES256 --pinentry-mode loopback --output "$tmp_cipher" "$tmp_plain"; then
        log_err "Encryption failed."
    fi
    
    # Verify the new cipher file is valid before replacing the old one
    if ! gpg --quiet --pinentry-mode loopback --decrypt < "$tmp_cipher" > /dev/null; then
        log_err "Verification of the new passphrase failed. Reverting changes."
    fi
    
    # Replace the old file
    create_backup "$enc_file"
    rm -f "$enc_file"
    mv "$tmp_cipher" "$enc_file"
    
    # Clean up plaintext temp file
    rm -f "$tmp_plain"
    
    # Reset trap
    trap - EXIT INT TERM
    
    log_info "Passphrase changed successfully for '$key'!"
}

handle_delete() {
    local idx="$1"
    local key="${keys[idx]}"
    local target="${targets[idx]}"
    local enc_file="$SECURED_DIR/$key"
    
    echo "⚠️  Are you sure you want to delete '$key' and its mapping to '$target'? This will physically remove the GPG file. [yes/no]"
    read -r confirm
    [[ "$confirm" != "yes" ]] && { echo "❌ Deletion aborted."; return; }
    
    # 1. Delete the GPG file if it exists
    if [[ -f "$enc_file" ]]; then
        rm -f "$enc_file"
        log_info "Deleted encrypted file: $key"
    else
        log_warn "Encrypted GPG file did not exist at: $enc_file"
    fi
    
    # 2. Update locations.properties to remove the key mapping
    local temp_prop
    temp_prop=$(mktemp)
    while IFS='=' read -r prop_key prop_val || [[ -n "$prop_key" ]]; do
        local clean_key=$(echo "$prop_key" | xargs)
        if [[ -z "$clean_key" || "$clean_key" =~ ^# ]]; then
            echo "$prop_key" >> "$temp_prop"
            continue
        fi
        
        if [[ "$clean_key" != "$key" ]]; then
            echo "$prop_key=$prop_val" >> "$temp_prop"
        fi
    done < "$PROPERTIES_FILE"
    
    mv "$temp_prop" "$PROPERTIES_FILE"
    chmod 644 "$PROPERTIES_FILE"
    log_info "Removed mapping for $key from locations.properties"
    
    # 3. Reload properties
    reload_properties
}

show_main_menu() {
    while true; do
        echo "-----------------------------------"
        echo "🔐 SECURE RESOURCE MANAGER"
        echo "-----------------------------------"
        echo "1. List secure resources"
        echo "2. Decrypt secure resource"
        echo "3. Encrypt secure resource"
        echo "4. Verify GPG passphrase"
        echo "5. Change GPG passphrase"
        echo "6. Delete secure resource"
        echo "7. Exit"
        echo -n "Select action: "
        read -r action
        
        case "$action" in
            1)
                handle_list
                ;;
            2)
                echo ""
                echo "--- Select Resource to Decrypt ---"
                if [[ ${#keys[@]} -eq 0 ]]; then
                    echo "No secure resources configured."
                    continue
                fi
                for i in "${!keys[@]}"; do
                    printf "%2d) %s  ->  %s\n" "$((i+1))" "${keys[i]}" "${targets[i]}"
                done
                echo " q) Back"
                echo -n "Choice: "
                read -r choice
                
                if [[ "$choice" == "q" ]]; then
                    continue
                fi
                
                if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#keys[@]} )); then
                    log_warn "Invalid choice"
                    continue
                fi
                
                handle_decrypt "$((choice-1))"
                ;;
            3)
                handle_encrypt
                ;;
            4)
                echo ""
                echo "--- Select Resource to Verify ---"
                if [[ ${#keys[@]} -eq 0 ]]; then
                    echo "No secure resources configured."
                    continue
                fi
                for i in "${!keys[@]}"; do
                    printf "%2d) %s  ->  %s\n" "$((i+1))" "${keys[i]}" "${targets[i]}"
                done
                echo " q) Back"
                echo -n "Choice: "
                read -r choice
                
                if [[ "$choice" == "q" ]]; then
                    continue
                fi
                
                if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#keys[@]} )); then
                    log_warn "Invalid choice"
                    continue
                fi
                
                handle_verify "$((choice-1))"
                ;;
            5)
                echo ""
                echo "--- Select Resource to Change Passphrase ---"
                if [[ ${#keys[@]} -eq 0 ]]; then
                    echo "No secure resources configured."
                    continue
                fi
                for i in "${!keys[@]}"; do
                    printf "%2d) %s  ->  %s\n" "$((i+1))" "${keys[i]}" "${targets[i]}"
                done
                echo " q) Back"
                echo -n "Choice: "
                read -r choice
                
                if [[ "$choice" == "q" ]]; then
                    continue
                fi
                
                if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#keys[@]} )); then
                    log_warn "Invalid choice"
                    continue
                fi
                
                handle_change_passphrase "$((choice-1))"
                ;;
            6)
                echo ""
                echo "--- Select Resource to Delete ---"
                if [[ ${#keys[@]} -eq 0 ]]; then
                    echo "No secure resources configured."
                    continue
                fi
                for i in "${!keys[@]}"; do
                    printf "%2d) %s  ->  %s\n" "$((i+1))" "${keys[i]}" "${targets[i]}"
                done
                echo " q) Back"
                echo -n "Choice: "
                read -r choice
                
                if [[ "$choice" == "q" ]]; then
                    continue
                fi
                
                if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#keys[@]} )); then
                    log_warn "Invalid choice"
                    continue
                fi
                
                handle_delete "$((choice-1))"
                ;;
            7)
                exit 0
                ;;
            *)
                log_warn "Invalid option"
                ;;
        esac
        echo ""
    done
}

# Entry Point
show_main_menu
