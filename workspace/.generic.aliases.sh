alias m="mkdir"
# helper function
set_alias_if_exists() {
  local alias_name="$1"
  local cmd="$2"

  if command -v "$cmd" >/dev/null 2>&1; then
    alias "$alias_name"="$cmd"
  fi
}

# aliases
set_alias_if_exists g git
set_alias_if_exists p python
set_alias_if_exists j java
set_alias_if_exists c curl
set_alias_if_exists w wget
set_alias_if_exists n node
set_alias_if_exists v vim
set_alias_if_exists t tmux
set_alias_if_exists tf terraform
set_alias_if_exists k kubernetes

