function _jwtdecode() {
  local usage="_jwtdecode <JSON-WEB-TOKEN>"
  local description="Decodes a json web token (jwt) and prints the header and payload."
  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo $usage
    echo $description
    return 0
  fi

  # Start
  if [[ -z "$1" ]]; then
    echo $usage 
    echo $description 
    return 1
  fi

  echo "$1" | awk -f. '{print $1, $2}' | while read -r header payload; do
  if [[ -z "$header" || -z "$payload" ]]; then
    echo "error: invalid jwt format. expected format: header.payload.signature"
    return 1
  fi

  echo "header:"
  echo "$header" | tr '_-' '/+' | base64 -d 2>/dev/null | jq . || echo "invalid header"

  echo "payload:"
  echo "$payload" | tr '_-' '/+' | base64 -d 2>/dev/null | jq . || echo "invalid payload"
done
}

function _gitb() {
  local usage="Just pass the command without any argument"
  local description="Opens the current Git branch in the remote repository's web interface (GitHub, GitLab, Bitbucket, etc.)."
  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo $usage
    echo $description
    return 0
  fi

  # Start
  # Check if the current directory is a Git repository
  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "This is not a Git repository. Please navigate to a valid Git repository and try again."
    return 1
  fi

  remote=$(git config --get remote.origin.url)
  if [ -z "$remote" ]; then
    echo "No remote origin found. Please set a remote repository."
    return 1
  fi

  url=$(echo "$remote" | sed -E "s#(git@|https://)([^:/]+)[:/]([^ ]+)#https://\2/\3#" | sed "s/\.git$//")
  branch=$(git rev-parse --abbrev-ref HEAD)
  
  if echo "$url" | grep -q "github.com"; then
    final_url="$url/tree/$branch"
  elif echo "$url" | grep -q "gitlab.com"; then
    final_url="$url/-/tree/$branch"
  elif echo "$url" | grep -q "bitbucket.org"; then
    final_url="$url/src/$branch"
  else
    final_url="$url/tree/$branch"
  fi

  echo "$final_url"
  
  if command -v xdg-open > /dev/null; then
    xdg-open "$final_url"
  elif command -v open > /dev/null; then
    open "$final_url"
  elif command -v start > /dev/null; then
    start "$final_url"
  else
    echo "No compatible browser open command found."
  fi
}

