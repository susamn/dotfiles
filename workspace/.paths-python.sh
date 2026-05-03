# 1. THE CERTIFICATE FOUNDATION
# Update this path to your local CA bundle file (PEM format)
export LOCAL_CA_BUNDLE=

# 2. THE VERSION REGISTRY (Fill these as you install new Pythons)
# Example: export PYTHON312_HOME="/opt/homebrew/opt/python@3.12"
export PYTHON311_HOME=""
export PYTHON312_HOME=""
export PYTHON313_HOME=""

export PIP_CACHE_DIR=$WORKSPACE_PATH/sdk/repositories/pip

mkdir -p $PIP_CACHE_DIR

export PATH=$PATH:$PIP_CACHE_DIR

# 3. THE GENERATOR (Creates py312, p312, pip312, etc.)
PATHS_PY_GEN_SCRIPT="$WORKSPACE_PATH/.paths-python-generated.aliases.sh"

if [ ! -f "$PATHS_PY_GEN_SCRIPT" ] || [ "$WORKSPACE_PATH/.paths-python.sh" -nt "$PATHS_PY_GEN_SCRIPT" ]; then
    bash -c '
      GEN_FILE="$1"
      echo "# Auto-generated Python aliases from .paths-python.sh" > "$GEN_FILE"
      
      # Cert injection string
      CERT_ENV="REQUESTS_CA_BUNDLE=\"$LOCAL_CA_BUNDLE\" SSL_CERT_FILE=\"$LOCAL_CA_BUNDLE\" PIP_CERT=\"$LOCAL_CA_BUNDLE\""

      _setup_python_aliases() {
          local pv="$1"
          local phome_var="PYTHON${pv}_HOME"
          eval "local phome_val=\$$phome_var"
          
          if [ -n "$phome_val" ] && [ -d "$phome_val" ]; then
              local py_bin="$phome_val/bin/python${pv:0:1}.${pv:1}"
              [ ! -x "$py_bin" ] && py_bin="$phome_val/bin/python"
              
              if [ -x "$py_bin" ]; then
                  echo "alias py${pv}=\"$CERT_ENV $py_bin\"" >> "$GEN_FILE"
                  echo "alias p${pv}=\"$CERT_ENV $py_bin\"" >> "$GEN_FILE"
                  echo "alias pip${pv}=\"$CERT_ENV $phome_val/bin/pip\"" >> "$GEN_FILE"
                  echo "alias venv${pv}=\"\"$py_bin\" -m venv\"" >> "$GEN_FILE"
              fi
          fi
      }

      for v in $(env | grep -Eo "^PYTHON[0-9]+_HOME=" | grep -Eo "[0-9]+"); do
          _setup_python_aliases "$v"
      done
    ' _ "$PATHS_PY_GEN_SCRIPT"
fi

if [ -f "$PATHS_PY_GEN_SCRIPT" ]; then
    source "$PATHS_PY_GEN_SCRIPT"
fi

# 4. THE SMART "NESTED-FOLDER" FUNCTIONS
# Searches upward for .venv or venv and runs with cert injection
_find_python_context() {
    local dir="$PWD"
    while [[ "$dir" != "/" && "$dir" != "$HOME" ]]; do
        if [ -x "$dir/.venv/bin/$1" ]; then
            echo "$dir/.venv/bin/$1"
            return 0
        elif [ -x "$dir/venv/bin/$1" ]; then
            echo "$dir/venv/bin/$1"
            return 0
        fi
        dir="${dir%/*}"
        [ -z "$dir" ] && break
    done
    return 1
}

py() {
    local bin
    bin=$(_find_python_context "python")
    if [ -n "$bin" ]; then
        REQUESTS_CA_BUNDLE="$LOCAL_CA_BUNDLE" SSL_CERT_FILE="$LOCAL_CA_BUNDLE" PIP_CERT="$LOCAL_CA_BUNDLE" "$bin" "$@"
    else
        REQUESTS_CA_BUNDLE="$LOCAL_CA_BUNDLE" SSL_CERT_FILE="$LOCAL_CA_BUNDLE" PIP_CERT="$LOCAL_CA_BUNDLE" python3 "$@"
    fi
}

pyp() {
    local bin
    bin=$(_find_python_context "pip")
    if [ -n "$bin" ]; then
        REQUESTS_CA_BUNDLE="$LOCAL_CA_BUNDLE" SSL_CERT_FILE="$LOCAL_CA_BUNDLE" PIP_CERT="$LOCAL_CA_BUNDLE" "$bin" "$@"
    else
        REQUESTS_CA_BUNDLE="$LOCAL_CA_BUNDLE" SSL_CERT_FILE="$LOCAL_CA_BUNDLE" PIP_CERT="$LOCAL_CA_BUNDLE" pip3 "$@"
    fi
}
