#!/usr/bin/env bash
set -e

CONFIG_FILE="$HOME/dotfiles/pyenv/virtualenvs.yaml"
REQS_DIR="$HOME/dotfiles/pyenv/requirements"

if ! command -v yq &> /dev/null; then
  echo "yq is required but not installed. Get it from https://github.com/mikefarah/yq"
  exit 1
fi

envs=$(yq e 'keys | .[]' "$CONFIG_FILE")
for env in $envs; do
  py_version=$(yq e ".\"$env\".python" "$CONFIG_FILE")
  req_file=$(yq e ".\"$env\".requirements" "$CONFIG_FILE")

  if ! pyenv versions --bare | grep -qx "$py_version"; then
    echo "Python version $py_version not installed. Run install_python_versions.sh first."
    continue
  fi

  if ! pyenv virtualenvs --bare | grep -qx "$env"; then
    pyenv virtualenv "$py_version" "$env"
  fi

  pyenv activate "$env"
  pip install -r "$REQS_DIR/$req_file"
  pyenv deactivate
done

