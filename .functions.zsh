function _jwtdecode() {
  if [[ -z "$1" ]]; then
    echo "Usage: jwtdecode <JWT_TOKEN>"
    echo "Decodes a JSON Web Token (JWT) and prints the header and payload."
    return 1
  fi

  echo "$1" | awk -F. '{print $1, $2}' | while read -r header payload; do
    if [[ -z "$header" || -z "$payload" ]]; then
      echo "Error: Invalid JWT format. Expected format: header.payload.signature"
      return 1
    fi

    echo "Header:"
    echo "$header" | tr '_-' '/+' | base64 -d 2>/dev/null | jq . || echo "Invalid header"

    echo "Payload:"
    echo "$payload" | tr '_-' '/+' | base64 -d 2>/dev/null | jq . || echo "Invalid payload"
  done
}
