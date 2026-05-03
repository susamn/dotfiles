#!/usr/bin/env bash
# =============================================================================
# lsp-query.sh — LSP query dispatcher
#
# Entry point for all LSP queries. Detects language from file extension or
# explicit --lang flag, validates prerequisites, delegates to the language-
# specific wrapper, and formats the output.
#
# Usage:
#   <SKILL-PATH>/scripts/lsp-query.sh [OPTIONS]
#
# Options:
#   -l, --lang     <language>   Force language: python|go|java (auto-detected if omitted)
#   -f, --file     <path>       Target source file
#   -q, --query    <type>       Query type (see below)
#   -s, --symbol   <name>       Symbol name (used to locate position in file)
#       --line     <n>          0-based line number (overrides --symbol)
#       --col      <n>          0-based column number (overrides --symbol)
#   -w, --workspace <path>      Project root (default: git root or current dir)
#   -o, --output   <fmt>        Output format: table (default) | json
#       --timeout  <sec>        Per-request timeout (default: 30)
#       --include-declaration   Include the declaration in references results
#   -h, --help                  Show this help
#
# Query types:
#   hover              — Type info / documentation at symbol position
#   definition         — Jump-to-definition locations
#   references         — All usages of a symbol across the workspace
#   implementations    — All concrete implementations of an interface/abstract
#   symbols            — All symbols declared in a file
#   workspace-symbols  — Symbol search across the entire workspace
#   call-hierarchy     — Who calls this symbol (callers) and what it calls (callees)
#   diagnostics        — Errors and warnings for a file
#
# Examples:
#   <SKILL-PATH>/scripts/lsp-query.sh -f src/app.py -q references -s "process_order"
#   <SKILL-PATH>/scripts/lsp-query.sh -f internal/service.go -q hover --line 55 --col 12
#   <SKILL-PATH>/scripts/lsp-query.sh -f src/app.py -q symbols -o json
#   <SKILL-PATH>/scripts/lsp-query.sh -q workspace-symbols -s "UserRepository" --lang java
#   <SKILL-PATH>/scripts/lsp-query.sh -f src/models.py -q diagnostics
# =============================================================================
set -euo pipefail

CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
GREEN='\033[0;32m'; BOLD='\033[1m'; RESET='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
RPC_SCRIPT="${LIB_DIR}/lsp-rpc.py"

# ── Defaults ──────────────────────────────────────────────────────────────────
LANG=""
FILE=""
QUERY=""
SYMBOL=""
LINE_NUM=""
COL_NUM=""
WORKSPACE=""
OUTPUT="table"
TIMEOUT=30
INCLUDE_DECL=""

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    -l|--lang)       LANG="$2";      shift 2 ;;
    -f|--file)       FILE="$2";      shift 2 ;;
    -q|--query)      QUERY="$2";     shift 2 ;;
    -s|--symbol)     SYMBOL="$2";    shift 2 ;;
    --line)          LINE_NUM="$2";  shift 2 ;;
    --col)           COL_NUM="$2";   shift 2 ;;
    -w|--workspace)  WORKSPACE="$2"; shift 2 ;;
    -o|--output)     OUTPUT="$2";    shift 2 ;;
    --timeout)       TIMEOUT="$2";   shift 2 ;;
    --include-declaration) INCLUDE_DECL="--include-declaration"; shift ;;
    -h|--help)       grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)               echo -e "${RED}Unknown option: $1${RESET}"; exit 1 ;;
  esac
done

log()  { echo -e "${CYAN}[lsp-query]${RESET} $*" >&2; }
warn() { echo -e "${YELLOW}[lsp-query]${RESET} $*" >&2; }
err()  { echo -e "${RED}[lsp-query]${RESET} $*" >&2; }

# ── Validate required args ─────────────────────────────────────────────────────
if [[ -z "$QUERY" ]]; then
  err "--query is required."
  echo "  Valid: hover | definition | references | implementations | symbols | workspace-symbols | call-hierarchy | diagnostics"
  exit 1
fi

# ── Resolve workspace ─────────────────────────────────────────────────────────
if [[ -z "$WORKSPACE" ]]; then
  # Try git root first, fall back to current dir
  WORKSPACE=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
fi
WORKSPACE=$(realpath "$WORKSPACE")

# ── Resolve file path ─────────────────────────────────────────────────────────
if [[ -n "$FILE" && ! "$FILE" = /* ]]; then
  FILE="${WORKSPACE}/${FILE}"
fi

if [[ -n "$FILE" && ! -f "$FILE" ]]; then
  err "File not found: $FILE"
  exit 1
fi

# ── Language detection ────────────────────────────────────────────────────────
detect_language() {
  local file="$1"
  local ext="${file##*.}"
  case "$ext" in
    py)                       echo "python" ;;
    go)                       echo "go" ;;
    java|kt|kts)              echo "java" ;;
    ts|tsx)                   echo "typescript" ;;
    js|jsx|mjs|cjs)           echo "javascript" ;;
    rs)                       echo "rust" ;;
    *)                        echo "" ;;
  esac
}

if [[ -z "$LANG" ]]; then
  if [[ -n "$FILE" ]]; then
    LANG=$(detect_language "$FILE")
  fi
  if [[ -z "$LANG" ]]; then
    err "Cannot detect language. Specify --lang python|go|java|typescript|rust"
    exit 1
  fi
fi

log "Language: ${BOLD}${LANG}${RESET}  Query: ${BOLD}${QUERY}${RESET}"

# ── Check lsp-rpc.py exists ───────────────────────────────────────────────────
if [[ ! -f "$RPC_SCRIPT" ]]; then
  err "lsp-rpc.py not found at: $RPC_SCRIPT"
  exit 1
fi

# ── Check Python 3 available ──────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  err "python3 is required but not found in PATH."
  exit 1
fi

# ── Delegate to language wrapper ──────────────────────────────────────────────
WRAPPER="${SCRIPT_DIR}/lsp-${LANG}.sh"

if [[ ! -f "$WRAPPER" ]]; then
  err "No wrapper found for language '${LANG}' at: $WRAPPER"
  echo "  Supported: python, go, java" >&2
  exit 1
fi

if [[ ! -x "$WRAPPER" ]]; then
  chmod +x "$WRAPPER"
fi

# Build common args to pass to the wrapper
COMMON_ARGS=(
  --workspace "$WORKSPACE"
  --query     "$QUERY"
  --output    "$OUTPUT"
  --timeout   "$TIMEOUT"
)

[[ -n "$FILE"     ]] && COMMON_ARGS+=(--file   "$FILE")
[[ -n "$SYMBOL"   ]] && COMMON_ARGS+=(--symbol "$SYMBOL")
[[ -n "$LINE_NUM" ]] && COMMON_ARGS+=(--line   "$LINE_NUM")
[[ -n "$COL_NUM"  ]] && COMMON_ARGS+=(--col    "$COL_NUM")
[[ -n "$INCLUDE_DECL" ]] && COMMON_ARGS+=("$INCLUDE_DECL")

exec "$WRAPPER" "${COMMON_ARGS[@]}"
