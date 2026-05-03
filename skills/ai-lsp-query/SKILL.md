---
name: ai-lsp-query
description: >
  Semantic code intelligence via LSP servers. Answers structured questions about
  a codebase — references, definitions, type info, call hierarchies, symbol
  listings, and diagnostics — using the same AST-backed data an IDE uses.
  Composable: any other skill can call lsp-query.sh to get semantic context
  before generating or validating code.
version: 1.0.0
triggers:
  - "find all references to"
  - "who calls this function"
  - "what type is this"
  - "go to definition"
  - "find implementations of"
  - "list symbols in file"
  - "lsp query"
  - "semantic code search"
intent: execution
helpers:
  - path: "<SKILL_PATH>/scripts/lsp-query.sh"
    purpose: >
      Main dispatcher. Detects language from file extension or --lang flag,
      validates prerequisites, delegates to the language-specific wrapper.
      This is the only script other skills need to call.
  - path: "<SKILL_PATH>/scripts/lsp-python.sh"
    purpose: >
      Python LSP bootstrap. Activates project venv (or Playground venv),
      selects pylsp or pyright, passes init options to disable noisy plugins.
  - path: "<SKILL_PATH>/scripts/lsp-go.sh"
    purpose: >
      Go LSP bootstrap. Locates go.mod root, configures gopls with staticcheck
      and inlay hints, respects GOPATH/GOROOT from environment.
  - path: "<SKILL_PATH>/scripts/lsp-java.sh"
    purpose: >
      Java LSP stub (jdtls). Not yet wired — outputs a clear message with
      interim alternatives and the implementation roadmap.
  - path: "<SKILL_PATH>/scripts/lib/lsp-rpc.py"
    purpose: >
      Core JSON-RPC engine. Owns the LSP protocol: initialize handshake,
      textDocument/didOpen, all query types, response parsing, output formatting.
      Called by language wrappers — not invoked directly.
guardrails:
  - "Always chmod +x all scripts under <SKILL_PATH>/scripts/ before first use."
  - "Use --output json when the result will be consumed by another script or skill — not for human display."
  - "LSP servers index the workspace on startup — expect 1–5s latency for Python/Go, up to 90s for Java (jdtls first run)."
  - "lsp-query.sh uses the git root as the workspace by default. Override with --workspace if the project root differs."
  - "For positional queries (hover, references, etc.) prefer --symbol over --line/--col — symbol search is more robust to file edits."
  - "Never run lsp-query.sh on generated files (build/, target/, dist/, __pycache__/) — results will be noisy and unreliable."
  - "Java support is a stub. Use the interim alternatives printed by lsp-java.sh until jdtls is wired."
supported_languages:
  python:
    server: pylsp (preferred) | pyright-langserver
    install: "pip install python-lsp-server"
    status: implemented
  go:
    server: gopls
    install: "go install golang.org/x/tools/gopls@latest"
    status: implemented
  java:
    server: jdtls (Eclipse JDT Language Server)
    install: "brew install jdtls  OR  manual download from github.com/eclipse-jdtls/eclipse.jdt.ls"
    status: stub — tracked for next iteration
tools:
  - bash
interface:
  input:
    file:      "string — path to the source file (relative to workspace)"
    query:     "string — hover | definition | references | implementations | symbols | workspace-symbols | call-hierarchy | diagnostics"
    symbol:    "string — symbol name to locate (used to resolve line/col if not provided)"
    lang:      "string — python | go | java (auto-detected from file extension if omitted)"
    workspace: "string — project root (default: git root)"
    output:    "string — table (default, human-readable) | json (machine-readable)"
  output:
    result:    "structured findings — locations, symbol list, type info, diagnostics"
    status:    "string — outcome"
---
## AI LSP Query — Semantic Code Intelligence

---

### Setup

```bash
chmod +x <SKILL-PATH>/scripts/lsp-query.sh
chmod +x <SKILL-PATH>/scripts/lsp-*.sh

# Install servers for the languages you need:
pip install python-lsp-server            # Python
go install golang.org/x/tools/gopls@latest  # Go
# Java: see lsp-java.sh stub for status
```

---

### Query Reference

| Query | What it answers | Requires position? |
|---|---|---|
| `hover` | Type signature and doc comment at a symbol | Yes |
| `definition` | Where a symbol is declared | Yes |
| `references` | Every call site / usage across the workspace | Yes |
| `implementations` | All concrete implementations of an interface or abstract | Yes |
| `symbols` | Every symbol declared in a single file | No |
| `workspace-symbols` | Symbol search across the entire project | No (uses --symbol as search term) |
| `call-hierarchy` | Who calls this function (callers) + what it calls (callees) | Yes |
| `diagnostics` | Errors and warnings the server reports for a file | No |

---

### Usage Examples

```bash
# Find all call sites of a function across the project
<SKILL-PATH>/scripts/lsp-query.sh \
  -f src/orders/service.py \
  -q references \
  -s "process_order"

# Get type info at a specific position (0-based line/col)
<SKILL-PATH>/scripts/lsp-query.sh \
  -f internal/handler/order.go \
  -q hover \
  --line 54 --col 12

# Jump-to-definition — where is this declared?
<SKILL-PATH>/scripts/lsp-query.sh \
  -f src/api/routes.py \
  -q definition \
  -s "OrderRepository"

# Full call hierarchy — callers and callees
<SKILL-PATH>/scripts/lsp-query.sh \
  -f internal/service/payment.go \
  -q call-hierarchy \
  -s "Charge"

# List all symbols in a file (functions, classes, methods)
<SKILL-PATH>/scripts/lsp-query.sh \
  -f src/models/order.py \
  -q symbols

# Search workspace for a type name
<SKILL-PATH>/scripts/lsp-query.sh \
  -q workspace-symbols \
  -s "UserRepository" \
  --lang python

# Get all errors/warnings for a file
<SKILL-PATH>/scripts/lsp-query.sh \
  -f src/service/checkout.py \
  -q diagnostics

# Machine-readable JSON output for consumption by another script
<SKILL-PATH>/scripts/lsp-query.sh \
  -f src/orders/service.py \
  -q references \
  -s "process_order" \
  --output json | jq '.locations[]'
```

---

### Integration with Other Skills

`ai-lsp-query` is designed to be called by other skills that need semantic
context before generating or modifying code. The `--output json` flag makes
it pipeable.

**Example: verify a generated method signature matches the actual interface**
```bash
# Get the interface's symbol list as JSON
SYMBOLS=$(
  <SKILL-PATH>/scripts/lsp-query.sh \
    -f src/repository.py \
    -q symbols \
    --output json
)

# Extract method names and pass to a validator
echo "$SYMBOLS" | jq -r '.symbols[] | select(.kind == "Method") | .name'
```

**Example: find all callers before refactoring a function**
```bash
<SKILL-PATH>/scripts/lsp-query.sh \
  -f src/payment/gateway.py \
  -q call-hierarchy \
  -s "charge_card" \
  --output json \
  | jq '.callers[] | "\(.name) at \(.location)"'
```

**Example: check a file for errors after AI-generated edits**
```bash
<SKILL-PATH>/scripts/lsp-query.sh \
  -f src/api/orders.py \
  -q diagnostics \
  --output json \
  | jq '.diagnostics[] | select(.severity == "ERROR")'
```

---

### Language Status & Server Requirements

#### Python — `pylsp` (implemented)
```bash
# Minimal
pip install python-lsp-server

# With type checking
pip install python-lsp-server pylsp-mypy

# Verify
pylsp --version
```

The wrapper auto-activates the project's `.venv`, `venv`, or `env` directory.
Falls back to the active virtual environment (`$VIRTUAL_ENV`), then system Python.

#### Go — `gopls` (implemented)
```bash
go install golang.org/x/tools/gopls@latest
export PATH=$PATH:$(go env GOPATH)/bin

# Verify
gopls version
```

The wrapper resolves the `go.mod` root automatically — you don't need to set
`--workspace` manually for Go projects.

#### Java — `jdtls` (stub — next iteration)
```bash
# When implemented, prerequisites will be:
brew install jdtls   # macOS
# or manual download: github.com/eclipse-jdtls/eclipse.jdt.ls/releases

export JDTLS_HOME=/path/to/jdtls
```

Until implemented, `lsp-java.sh` exits with a clear message listing interim
alternatives (Maven dependency tree, grep-based symbol search, IntelliJ CLI).
See the Phase A/B/C implementation plan inside `lsp-java.sh`.

---

### Architecture

```
lsp-query.sh  (dispatcher)
     │
     ├── lsp-python.sh   ─── activates venv, selects pylsp/pyright
     ├── lsp-go.sh       ─── resolves go.mod root, configures gopls
     └── lsp-java.sh     ─── stub (jdtls — next iteration)
              │
              └──► lib/lsp-rpc.py   (JSON-RPC engine)
                        │
                        ├── LspSession     — process lifecycle, stdio framing
                        ├── Query methods  — hover, references, definition, ...
                        └── Formatters     — table (human) | json (machine)
```

`lsp-rpc.py` is language-agnostic. Adding a new language requires only a new
`lsp-<lang>.sh` wrapper that sets `--server-cmd` and `--language-id` correctly.
The protocol handling, query dispatch, and output formatting are inherited for free.

---

### Adding a New Language

Create `<SKILL-PATH>/scripts/lsp-<lang>.sh`:

```bash
#!/usr/bin/env bash
# Minimal new language wrapper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RPC_SCRIPT="${SCRIPT_DIR}/lib/lsp-rpc.py"

# 1. Parse forwarded args (copy the arg-parsing block from lsp-go.sh)
# 2. Check the LSP server binary exists
# 3. Set SERVER_CMD and INIT_OPTIONS for this language
# 4. Call:

exec python3 "$RPC_SCRIPT" \
  --server-cmd  "$SERVER_CMD" \
  --workspace   "$WORKSPACE" \
  --file        "$FILE" \
  --query       "$QUERY" \
  --language-id "<lang-id>" \
  --output      "$OUTPUT" \
  --timeout     "$TIMEOUT" \
  --init-options "$INIT_OPTIONS"
```

Then register the extension in `lsp-query.sh`'s `detect_language()` function:
```bash
myext) echo "mylang" ;;
```
