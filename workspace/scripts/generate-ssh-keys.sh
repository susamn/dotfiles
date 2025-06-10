#!/bin/bash

cd ~/.ssh || { echo "❌ Failed to change directory to ~/.ssh"; exit 1; }

# Check if both private and public key files already exist
if [[ -f id_ed25519 && -f id_ed25519.pub ]]; then
  echo "✅ SSH keys already exist. Skipping decryption."
else
  echo "🔐 Decrypting SSH keys..."

  # Decrypt private key
  gpg --quiet --batch --yes --decrypt --output id_ed25519 < id_ed25519.gpg || { echo "❌ Failed to decrypt id_ed25519"; exit 1; }

  # Decrypt public key
  gpg --quiet --batch --yes --decrypt --output id_ed25519.pub < id_ed25519.pub.gpg || { echo "❌ Failed to decrypt id_ed25519.pub"; exit 1; }

  # Set proper permissions
  chmod 600 id_ed25519
  chmod 644 id_ed25519.pub

  echo "✅ SSH keys decrypted and permissions set."
fi

# Check SSH authentication with GitHub
echo "🔍 Testing SSH authentication with GitHub..."

# Capture SSH output (suppress known_hosts prompt with StrictHostKeyChecking=no)
ssh_output=$(ssh -o StrictHostKeyChecking=accept-new -i ~/.ssh/id_ed25519 -T git@github.com 2>&1)

# Handle different outcomes
if echo "$ssh_output" | grep -q "successfully authenticated"; then
  echo "🎉 SSH authentication to GitHub succeeded!"
elif echo "$ssh_output" | grep -q "Permission denied (publickey)"; then
  echo "❌ SSH authentication failed: Permission denied. Check if your public key is added to GitHub."
  exit 1
else
  echo "⚠️ SSH test failed due to a possible network, proxy, or other issue."
  echo "Details:"
  echo "$ssh_output"
  exit 1
fi

