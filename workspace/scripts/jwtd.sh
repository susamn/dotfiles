usage="_jwtdecode <JSON-WEB-TOKEN>"
description="Decodes a json web token (jwt) and prints the header and payload."
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo $usage
  echo $description
  exit 0
fi

  # Start
  if [[ -z "$1" ]]; then
    echo $usage 
    echo $description 
    exit 1
  fi

  echo "$1" | awk -f. '{print $1, $2}' | while read -r header payload; do
  if [[ -z "$header" || -z "$payload" ]]; then
    echo "error: invalid jwt format. expected format: header.payload.signature"
    exit 1
  fi

  echo "header:"
  echo "$header" | tr '_-' '/+' | base64 -d 2>/dev/null | jq . || echo "invalid header"

  echo "payload:"
  echo "$payload" | tr '_-' '/+' | base64 -d 2>/dev/null | jq . || echo "invalid payload"
done
