#!/usr/bin/env bash
# =============================================================================
# lsp-go.sh — Go LSP server bootstrap (gopls)
#
# Verifies gopls is installed, resolves the Go module root as the workspace,
# sets GOPATH/GOROOT from environment if available, then delegates to lsp-rpc.py.
#
# Called by lsp-query.sh — do not invoke directly.
# Direct usage (for testing):
#   <SKILL-PATH>/scripts/lsp-go.sh \
#     --workspace /path/to/project \
#     --file internal/service/order.go \
#     --query references \
#     --symbol "CreateOrder"
# =============================================================================
set -euo pipefail

CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPC_SCRIPT="${SCRIPT_DIR}/lib/lsp-rpc.py"

# ── Collect forwarded args ────────────────────────────────────────────────────
WORKSPACE=""
FILE=""
QUERY=""
SYMBOL=""
LINE_NUM=""
COL_NUM=""
OUTPUT="table"
TIMEOUT=30
INCLUDE_DECL=""

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
    *)           shift ;;
  esac
done

log()  { echo -e "${CYAN}[lsp-go]${RESET} $*" >&2; }
warn() { echo -e "${YELLOW}[lsp-go]${RESET} $*" >&2; }
err()  { echo -e "${RED}[lsp-go]${RESET} $*" >&2; }

# ── gopls check ───────────────────────────────────────────────────────────────
if ! command -v gopls &>/dev/null; then
  err "gopls not found."
  echo "" >&2
  echo "  Install:" >&2
  echo "    go install golang.org/x/tools/gopls@latest" >&2
  echo "" >&2
  echo "  Ensure \$GOPATH/bin is in your PATH:" >&2
  echo "    export PATH=\$PATH:\$(go env GOPATH)/bin" >&2
  exit 1
fi

GOPLS_VERSION=$(gopls version 2>/dev/null | head -1 || echo "unknown")
log "Using server: gopls  (${GOPLS_VERSION})"

# ── Resolve Go module root ────────────────────────────────────────────────────
# gopls works best when the workspace is the directory containing go.mod.
# Walk up from the provided workspace to find go.mod.
resolve_module_root() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "${dir}/go.mod" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  echo "$1"   # fallback: use the provided workspace
}

MODULE_ROOT=$(resolve_module_root "$WORKSPACE")
if [[ "$MODULE_ROOT" != "$WORKSPACE" ]]; then
  warn "go.mod found at: $MODULE_ROOT — using it as workspace root for gopls."
  WORKSPACE="$MODULE_ROOT"
fi

# ── gopls env config ──────────────────────────────────────────────────────────
# gopls accepts env variables for build configuration.
# Respect GOPATH / GOROOT if set in the caller's environment.
INIT_OPTIONS="{}"

GOPLS_ENV="{}"
ENV_PARTS=()
[[ -n "${GOPATH:-}"  ]] && ENV_PARTS+=("\"GOPATH\":\"${GOPATH}\"")
[[ -n "${GOROOT:-}"  ]] && ENV_PARTS+=("\"GOROOT\":\"${GOROOT}\"")
[[ -n "${GOFLAGS:-}" ]] && ENV_PARTS+=("\"GOFLAGS\":\"${GOFLAGS}\"")

if [[ "${#ENV_PARTS[@]}" -gt 0 ]]; then
  GOPLS_ENV="{$(IFS=','; echo "${ENV_PARTS[*]}")}"
fi

INIT_OPTIONS=$(cat <<JSON
{
  "gopls": {
    "env":       ${GOPLS_ENV},
    "analyses":  {
      "unusedparams":  true,
      "shadow":        true,
      "nilness":       true,
      "unusedwrite":   true
    },
    "staticcheck": true,
    "hints": {
      "parameterNames":         true,
      "assignVariableTypes":    true,
      "compositeLiteralFields": true,
      "compositeLiteralTypes":  true,
      "constantValues":         true,
      "functionTypeParameters": true,
      "rangeVariableTypes":     true
    }
  }
}
JSON
)

# ── Build rpc args ────────────────────────────────────────────────────────────
RPC_ARGS=(
  --server-cmd   "gopls serve"
  --workspace    "$WORKSPACE"
  --query        "$QUERY"
  --language-id  "go"
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
