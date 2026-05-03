#!/usr/bin/env bash
# =============================================================================
# lsp-python.sh — Python LSP server bootstrap
#
# Selects pylsp or pyright, verifies installation, activates the project
# virtual environment if present, then delegates to lsp-rpc.py.
#
# Called by lsp-query.sh — do not invoke directly.
# Direct usage (for testing):
#   <SKILL-PATH>/scripts/lsp-python.sh \
#     --workspace /path/to/project \
#     --file src/app.py \
#     --query references \
#     --symbol "process_order"
# =============================================================================
set -euo pipefail

CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPC_SCRIPT="${SCRIPT_DIR}/lib/lsp-rpc.py"

# ── Collect args forwarded from lsp-query.sh ─────────────────────────────────
WORKSPACE=""
FILE=""
QUERY=""
SYMBOL=""
LINE_NUM=""
COL_NUM=""
OUTPUT="table"
TIMEOUT=30
INCLUDE_DECL=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --file)      FILE="$2";      shift 2 ;;
    --query)     QUERY="$2";     shift 2 ;;
    --symbol)    SYMBOL="$2";    shift 2 ;;
    --line)      LINE_NUM="$2";  shift 2 ;;
    --col)       COL_NUM="$2";   shift 2 ;;
    --output)    OUTPUT="$2";    shift 2 ;;
    --timeout)   TIMEOUT="$2";   shift 2 ;;
    --include-declaration) INCLUDE_DECL="--include-declaration"; shift ;;
    *)           EXTRA_ARGS+=("$1"); shift ;;
  esac
done

log()  { echo -e "${CYAN}[lsp-python]${RESET} $*" >&2; }
warn() { echo -e "${YELLOW}[lsp-python]${RESET} $*" >&2; }
err()  { echo -e "${RED}[lsp-python]${RESET} $*" >&2; }

# ── Activate virtual environment if present ───────────────────────────────────
activate_venv() {
  local project_dir="$1"
  # Check common venv locations in priority order
  local venv_candidates=(
    "${project_dir}/.venv/bin/activate"
    "${project_dir}/venv/bin/activate"
    "${project_dir}/env/bin/activate"
    "${project_dir}/.env/bin/activate"
  )
  # Also check for Playground venv (Supratim's generic work venv)
  if [[ -n "${VIRTUAL_ENV:-}" ]]; then
    log "Virtual environment already active: $VIRTUAL_ENV"
    return 0
  fi
  for candidate in "${venv_candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      # shellcheck disable=SC1090
      source "$candidate"
      log "Activated venv: $(dirname "$(dirname "$candidate")")"
      return 0
    fi
  done
  warn "No virtual environment found — using system Python. Install pylsp in a venv for isolation."
}

activate_venv "$WORKSPACE"

# ── Select LSP server ─────────────────────────────────────────────────────────
# Preference order: pylsp → pyright → error
SERVER_CMD=""
INIT_OPTIONS="{}"

if command -v pylsp &>/dev/null; then
  SERVER_CMD="pylsp"
  log "Using server: pylsp ($(pylsp --version 2>/dev/null | head -1 || echo 'version unknown'))"

  # pylsp init options: enable the most useful plugins
  INIT_OPTIONS=$(cat <<'JSON'
{
  "pylsp": {
    "plugins": {
      "pyflakes":         {"enabled": true},
      "pycodestyle":      {"enabled": false},
      "autopep8":         {"enabled": false},
      "yapf":             {"enabled": false},
      "rope_autoimport":  {"enabled": false},
      "pylsp_mypy":       {"enabled": false}
    }
  }
}
JSON
)

elif command -v pyright-langserver &>/dev/null; then
  SERVER_CMD="pyright-langserver --stdio"
  log "Using server: pyright-langserver"

elif command -v pyright &>/dev/null; then
  # Some installs put pyright on PATH directly; it doesn't support --stdio
  # in older versions. Try pyright-langserver as a fallback.
  err "Found 'pyright' but not 'pyright-langserver'. Install: npm install -g pyright"
  err "Or install pylsp: pip install python-lsp-server --break-system-packages"
  exit 1

else
  err "No Python LSP server found."
  echo "" >&2
  echo "  Install one of:" >&2
  echo "    pip install python-lsp-server   # pylsp (recommended)" >&2
  echo "    npm install -g pyright          # pyright" >&2
  echo "" >&2
  echo "  For pylsp with extra type-checking:" >&2
  echo "    pip install python-lsp-server pylsp-mypy" >&2
  exit 1
fi

# ── Build rpc args ────────────────────────────────────────────────────────────
RPC_ARGS=(
  --server-cmd   "$SERVER_CMD"
  --workspace    "$WORKSPACE"
  --query        "$QUERY"
  --language-id  "python"
  --output       "$OUTPUT"
  --timeout      "$TIMEOUT"
  --init-options "$INIT_OPTIONS"
)

[[ -n "$FILE"     ]] && RPC_ARGS+=(--file   "$FILE")
[[ -n "$SYMBOL"   ]] && RPC_ARGS+=(--symbol "$SYMBOL")
[[ -n "$LINE_NUM" ]] && RPC_ARGS+=(--line   "$LINE_NUM")
[[ -n "$COL_NUM"  ]] && RPC_ARGS+=(--col    "$COL_NUM")
[[ -n "$INCLUDE_DECL" ]] && RPC_ARGS+=("$INCLUDE_DECL")

# ── Delegate to RPC client ────────────────────────────────────────────────────
exec python3 "$RPC_SCRIPT" "${RPC_ARGS[@]}"
