#!/bin/bash

set -euo pipefail

cd ~/.ssh || { echo "❌ Failed to change directory to ~/.ssh"; exit 1; }

# Ensure password prompt works on macOS
export GPG_TTY=$(tty)

# --- Parse arguments ---
ACTION=""
MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="$2"
      shift 2
      ;;
    --mode|-m)
      MODE="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Usage: $0 --action [generate|modify] --mode [private|public]"
      exit 1
      ;;
  esac
done

# Validate inputs
if [[ "$ACTION" != "generate" && "$ACTION" != "modify" ]]; then
  echo "❌ Invalid --action: $ACTION"
  echo "Usage: $0 --action [generate|modify] --mode [private|public]"
  exit 1
fi

if [[ "$MODE" != "private" && "$MODE" != "public" ]]; then
  echo "❌ Invalid --mode: $MODE"
  echo "Usage: $0 --action $ACTION --mode [private|public]"
  exit 1
fi

# Select encrypted source files correctly based on mode
if [[ "$MODE" == "private" ]]; then
  ENC_PRIV="id_ed25519.private.gpg"
  ENC_PUB="id_ed25519.pub.private.gpg"
elif [[ "$MODE" == "public" ]]; then
  ENC_PRIV="id_ed25519.public.gpg"
  ENC_PUB="id_ed25519.pub.public.gpg"
fi


DATESTAMP=$(date +%Y%m%d_%H%M%S)

if [[ "$ACTION" == "generate" ]]; then
  echo "⚠️  Are you sure you want to generate $MODE keys? [yes/no]"
  read -r CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo "❌ Aborted by user."
    exit 1
  fi

  if [[ -f "id_ed25519" && -f "id_ed25519.pub" ]]; then
    echo "✅ Decrypted keys already exist. Skipping generation."
    exit 0
  fi

  echo "🔐 Decrypting '$MODE' keys..."
  gpg --quiet --batch --yes --decrypt --output id_ed25519 < "$ENC_PRIV"
  gpg --quiet --batch --yes --decrypt --output id_ed25519.pub < "$ENC_PUB"

  chmod 600 id_ed25519
  chmod 644 id_ed25519.pub
  echo "✅ Keys written and permissions set."

  if [[ "$MODE" == "private" ]]; then
    echo "🔍 Testing SSH authentication with GitHub..."
    ssh_output=$(ssh -o StrictHostKeyChecking=accept-new -i id_ed25519 -T git@github.com 2>&1)

    if echo "$ssh_output" | grep -q "successfully authenticated"; then
      echo "🎉 SSH authentication to GitHub succeeded!"
    elif echo "$ssh_output" | grep -q "Permission denied (publickey)"; then
      echo "❌ SSH authentication failed: Check if your public key is added to GitHub."
      exit 1
    else
      echo "⚠️ SSH test failed (network or unknown issue):"
      echo "$ssh_output"
      exit 1
    fi
  fi


elif [[ "$ACTION" == "modify" ]]; then
  echo "🔐 Decrypting selected key pair for mode: $MODE"

  PRIV_TMP=$(mktemp)
  PUB_TMP=$(mktemp)

  trap 'rm -f "$PRIV_TMP" "$PUB_TMP"' EXIT

  gpg --quiet --batch --yes --decrypt --output "$PRIV_TMP" < "$ENC_PRIV"
  gpg --quiet --batch --yes --decrypt --output "$PUB_TMP" < "$ENC_PUB"

  echo "🗝️  Selected private key: $ENC_PRIV"
  echo "📋 Choose an action:"
  echo "  1. Change password"
  echo "  2. Generate new public key"
  echo -n "Enter option (1, 2, or both comma-separated like 1,2): "
  read -r CHOICE

  IFS=',' read -ra OPTIONS <<< "$CHOICE"

  for opt in "${OPTIONS[@]}"; do
    case "$opt" in
      1)
        echo "🔐 Changing passphrase..."
        cp "$ENC_PRIV" "${ENC_PRIV}.${DATESTAMP}.backup"
        ssh-keygen -p -f "$PRIV_TMP"
        gpg --symmetric --cipher-algo AES256 --output "$ENC_PRIV" "$PRIV_TMP"
        echo "✅ Password updated and re-encrypted: $ENC_PRIV"
        ;;
      2)
        echo "🔁 Regenerating public key from private key..."
        cp "$ENC_PUB" "${ENC_PUB}.${DATESTAMP}.backup"
        ssh-keygen -y -f "$PRIV_TMP" > "$PUB_TMP"
        gpg --symmetric --cipher-algo AES256 --output "$ENC_PUB" "$PUB_TMP"
        echo "✅ Public key regenerated and re-encrypted: $ENC_PUB"
        ;;
      *)
        echo "⚠️  Invalid option: $opt"
        ;;
    esac
  done

  echo "🧼 Secure cleanup done. No decrypted keys saved to disk."
fi

