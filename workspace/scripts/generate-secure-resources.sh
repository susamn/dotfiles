#!/bin/bash

set -euo pipefail

# Ensure password prompt works on macOS
export GPG_TTY=$(tty)

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

decrypt_file() {
    local src="$1"
    local dest="$2"
    gpg --quiet --batch --yes --decrypt --output "$dest" < "$src"
}

encrypt_file() {
    local src="$1"
    local dest="$2"
    gpg --symmetric --cipher-algo AES256 --output "$dest" "$src"
}

# --- Resource Handlers ---

handle_ssh() {
    echo "--- SSH Key Management ---"
    echo "1. Decrypt Private Keys (id_ed25519.private.gpg)"
    echo "2. Decrypt Public Keys (id_ed25519.public.gpg)"
    echo "3. Modify/Regenerate Keys"
    echo "4. Back"
    echo -n "Select action: "
    read -r action

    case "$action" in
        1|2)
            local mode="private"
            [[ "$action" == "2" ]] && mode="public"
            
            local enc_priv="id_ed25519.${mode}.gpg"
            local enc_pub="id_ed25519.pub.${mode}.gpg"
            
            cd ~/.ssh || log_err "Could not cd to ~/.ssh"
            
            if [[ -f "id_ed25519" && -f "id_ed25519.pub" ]]; then
                log_warn "Decrypted keys already exist. Overwrite? [yes/no]"
                read -r confirm
                [[ "$confirm" != "yes" ]] && return
            fi

            log_info "Decrypting '$mode' keys..."
            decrypt_file "$enc_priv" "id_ed25519"
            decrypt_file "$enc_pub" "id_ed25519.pub"

            chmod 600 id_ed25519
            chmod 644 id_ed25519.pub
            log_info "Keys written to ~/.ssh/"

            if [[ "$mode" == "private" ]]; then
                log_info "Testing SSH authentication with GitHub..."
                if ssh -o StrictHostKeyChecking=accept-new -i id_ed25519 -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
                    log_info "GitHub authentication succeeded!"
                else
                    log_warn "GitHub authentication failed or network issue."
                fi
            fi
            ;;
        3)
            # Porting the 'modify' logic
            log_info "Choose mode to modify (private/public): "
            read -r mode
            [[ "$mode" != "private" && "$mode" != "public" ]] && { log_warn "Invalid mode"; return; }

            local enc_priv="id_ed25519.${mode}.gpg"
            local enc_pub="id_ed25519.pub.${mode}.gpg"

            cd ~/.ssh || log_err "Could not cd to ~/.ssh"
            
            local priv_tmp=$(mktemp)
            local pub_tmp=$(mktemp)
            trap 'rm -f "$priv_tmp" "$pub_tmp"' RETURN EXIT

            decrypt_file "$enc_priv" "$priv_tmp"
            decrypt_file "$enc_pub" "$pub_tmp"

            echo "📋 Actions for $mode keys:"
            echo "  1. Change passphrase"
            echo "  2. Regenerate public key from private"
            echo -n "Enter choice (1, 2, or 1,2): "
            read -r choice

            IFS=',' read -ra options <<< "$choice"
            for opt in "${options[@]}"; do
                case "$opt" in
                    1)
                        create_backup "$enc_priv"
                        ssh-keygen -p -f "$priv_tmp"
                        encrypt_file "$priv_tmp" "$enc_priv"
                        log_info "Passphrase updated."
                        ;;
                    2)
                        create_backup "$enc_pub"
                        ssh-keygen -y -f "$priv_tmp" > "$pub_tmp"
                        encrypt_file "$pub_tmp" "$enc_pub"
                        log_info "Public key regenerated."
                        ;;
                esac
            done
            ;;
        4) return ;;
        *) log_warn "Invalid option" ;;
    esac
}

handle_aws() {
    echo "--- AWS Credential Management ---"
    echo "1. Decrypt AWS Credentials (~/.aws/*.gpg -> plaintext)"
    echo "2. Encrypt AWS Credentials (plaintext -> ~/.aws/*.gpg)"
    echo "3. Change GPG Passphrase"
    echo "4. Back"
    echo -n "Select action: "
    read -r action

    local files=("credentials" "config")
    local aws_dir="$HOME/.aws"
    mkdir -p "$aws_dir"
    cd "$aws_dir" || log_err "Could not cd to $aws_dir"

    case "$action" in
        1)
            for f in "${files[@]}"; do
                if [[ -f "$f.gpg" ]]; then
                    log_info "Decrypting $f.gpg..."
                    decrypt_file "$f.gpg" "$f"
                    chmod 600 "$f"
                else
                    log_warn "$f.gpg not found, skipping."
                fi
            done
            ;;
        2)
            for f in "${files[@]}"; do
                if [[ -f "$f" ]]; then
                    log_info "Encrypting $f..."
                    create_backup "$f.gpg"
                    encrypt_file "$f" "$f.gpg"
                    log_info "Encrypted to $f.gpg. You can now delete the plaintext $f."
                else
                    log_warn "$f not found, skipping."
                fi
            done
            ;;
        3)
            for f in "${files[@]}"; do
                if [[ -f "$f.gpg" ]]; then
                    log_info "Changing passphrase for $f.gpg..."
                    local tmp=$(mktemp)
                    trap 'rm -f "$tmp"' RETURN EXIT
                    decrypt_file "$f.gpg" "$tmp"
                    create_backup "$f.gpg"
                    encrypt_file "$tmp" "$f.gpg"
                    log_info "Passphrase updated for $f.gpg"
                fi
            done
            ;;
        4) return ;;
        *) log_warn "Invalid option" ;;
    esac
}

handle_hosts() {
    echo "--- Local Host Mapping Management ---"
    echo "1. Decrypt Hosts (~/.local_hosts.gpg -> plaintext)"
    echo "2. Encrypt Hosts (plaintext -> ~/.local_hosts.gpg)"
    echo "3. Change GPG Passphrase"
    echo "4. Back"
    echo -n "Select action: "
    read -r action

    local file="$HOME/.local_hosts"
    local enc_file="$file.gpg"

    case "$action" in
        1)
            if [[ -f "$enc_file" ]]; then
                log_info "Decrypting $enc_file..."
                decrypt_file "$enc_file" "$file"
                chmod 600 "$file"
            else
                log_err "$enc_file not found."
            fi
            ;;
        2)
            if [[ -f "$file" ]]; then
                log_info "Encrypting $file..."
                create_backup "$enc_file"
                encrypt_file "$file" "$enc_file"
                log_info "Encrypted to $enc_file. You can now delete the plaintext $file."
            else
                log_err "$file not found."
            fi
            ;;
        3)
            if [[ -f "$enc_file" ]]; then
                log_info "Changing passphrase for $enc_file..."
                local tmp=$(mktemp)
                trap 'rm -f "$tmp"' RETURN EXIT
                decrypt_file "$enc_file" "$tmp"
                create_backup "$enc_file"
                encrypt_file "$tmp" "$enc_file"
                log_info "Passphrase updated for $enc_file"
            else
                log_err "$enc_file not found."
            fi
            ;;
        4) return ;;
        *) log_warn "Invalid option" ;;
    esac
}

# --- Main Menu ---

show_main_menu() {
    while true; do
        echo "-----------------------------------"
        echo "🔐 SECURE RESOURCE MANAGER"
        echo "-----------------------------------"
        echo "1. SSH Keys"
        echo "2. AWS Credentials"
        echo "3. Host Mappings"
        echo "4. Exit"
        echo -n "Select resource: "
        read -r choice

        case "$choice" in
            1) handle_ssh ;;
            2) handle_aws ;;
            3) handle_hosts ;;
            4) exit 0 ;;
            *) log_warn "Invalid option" ;;
        esac
    done
}

# Entry Point
if [[ $# -eq 0 ]]; then
    show_main_menu
else
    # Future: handle CLI flags here if needed
    log_err "Usage: $0 (Interactive mode only for now)"
fi
