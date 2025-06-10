#!/bin/bash

set -e

cd ~/.ssh || { echo "❌ Failed to change directory to ~/.ssh"; exit 1; }

# --- Parse arguments ---
MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode|-m)
      MODE="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "Usage: $0 --mode [private|public]"
      exit 1
      ;;
  esac
done

if [[ "$MODE" != "private" && "$MODE" != "public" ]]; then
  echo "❌ Invalid mode: '$MODE'"
  echo "Usage: $0 --mode [private|public]"
  exit 1
fi

# --- Confirmation prompt ---
echo "⚠️  Are you sure you want to generate $MODE keys? [yes/no]"
read -r CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "❌ Aborted by user."
  exit 1
fi

# --- Check if target keys already exist ---
if [[ -f "id_ed25519" && -f "id_ed25519.pub" ]]; then
  echo "✅ Decrypted keys already exist as 'id_ed25519' and 'id_ed25519.pub'. Skipping decryption."
  exit 0
fi

# --- Select encrypted source files ---
if [[ "$MODE" == "private" ]]; then
  ENC_PRIV="id_ed25519.private.gpg"
  ENC_PUB="id_ed25519.pub.private.gpg"
else
  ENC_PRIV="id_ed25519.public.gpg"
  ENC_PUB="id_ed25519.pub.public.gpg"
fi

# --- Decrypt ---
echo "🔐 Decrypting '$MODE' keys into 'id_ed25519' and 'id_ed25519.pub'..."

gpg --quiet --batch --yes --decrypt --output id_ed25519 < "$ENC_PRIV" || { echo "❌ Failed to decrypt $ENC_PRIV"; exit 1; }
gpg --quiet --batch --yes --decrypt --output id_ed25519.pub < "$ENC_PUB" || { echo "❌ Failed to decrypt $ENC_PUB"; exit 1; }

chmod 600 id_ed25519
chmod 644 id_ed25519.pub

echo "✅ Keys decrypted and permissions set."

# --- GitHub SSH test (only in private mode) ---
if [[ "$MODE" == "private" ]]; then
  echo "🔍 Testing SSH authentication with GitHub..."

  ssh_output=$(ssh -o StrictHostKeyChecking=accept-new -i id_ed25519 -T git@github.com 2>&1)

  if echo "$ssh_output" | grep -q "successfully authenticated"; then
    echo "🎉 SSH authentication to GitHub succeeded!"
  elif echo "$ssh_output" | grep -q "Permission denied (publickey)"; then
    echo "❌ SSH authentication failed: Permission denied. Check if your public key is added to GitHub."
    exit 1
  else
    echo "⚠️ SSH test failed (possibly network or other issue)."
    echo "Details:"
    echo "$ssh_output"
    exit 1
  fi
fi

