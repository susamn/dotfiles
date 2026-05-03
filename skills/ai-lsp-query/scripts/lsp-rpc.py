#!/usr/bin/env python3
"""
lsp-rpc.py — JSON-RPC stdio client for LSP servers.

Handles the full LSP session lifecycle:
  initialize → initialized → didOpen → query → shutdown → exit

Called by language wrapper scripts (lsp-python.sh, lsp-go.sh, lsp-java.sh).
Writes structured JSON to stdout so lsp-query.sh can format it.

Usage:
  python3 lsp-rpc.py \
    --server-cmd "pylsp" \
    --workspace /path/to/project \
    --file /path/to/file.py \
    --query references \
    --symbol "my_function" \
    --line 42 \
    --col 8 \
    [--output json|table] \
    [--timeout 30] \
    [--init-options '{"key": "val"}']
"""

import argparse
import json
import os
import queue
import shlex
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

# ── LSP protocol helpers ───────────────────────────────────────────────────────

def encode_message(payload: dict) -> bytes:
    body = json.dumps(payload, separators=(',', ':')).encode('utf-8')
    header = f"Content-Length: {len(body)}\r\n\r\n".encode('utf-8')
    return header + body


def read_message(stream) -> Optional[dict]:
    """Read one LSP message from a binary stream."""
    headers: Dict[str, str] = {}
    while True:
        line = b""
        while not line.endswith(b"\r\n"):
            ch = stream.read(1)
            if not ch:
                return None
            line += ch
        line = line.strip()
        if not line:
            break
        if b":" in line:
            key, _, val = line.decode('utf-8').partition(': ')
            headers[key.strip()] = val.strip()

    length = int(headers.get('Content-Length', 0))
    if length == 0:
        return None
    body = b""
    while len(body) < length:
        chunk = stream.read(length - len(body))
        if not chunk:
            return None
        body += chunk
    return json.loads(body.decode('utf-8'))


def path_to_uri(path: str) -> str:
    abs_path = os.path.abspath(path)
    # On Windows paths need a leading slash
    if not abs_path.startswith('/'):
        abs_path = '/' + abs_path.replace('\\', '/')
    return f"file://{abs_path}"


def uri_to_path(uri: str) -> str:
    return uri.replace('file://', '')


# ── LSP session ────────────────────────────────────────────────────────────────

class LspSession:
    def __init__(self, server_cmd: str, workspace: str,
                 timeout: int = 30, init_options: Optional[dict] = None):
        self.workspace = os.path.abspath(workspace)
        self.timeout = timeout
        self.init_options = init_options or {}
        self._req_id = 0
        self._pending: Dict[int, Any] = {}
        self._response_queue: queue.Queue = queue.Queue()
        self._server: Optional[subprocess.Popen] = None
        self._reader_thread: Optional[threading.Thread] = None
        self._stderr_thread: Optional[threading.Thread] = None
        self._stderr_lines: List[str] = []
        self._running = False

        cmd = shlex.split(server_cmd)
        self._server = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=self.workspace,
        )
        self._running = True
        self._reader_thread = threading.Thread(target=self._reader, daemon=True)
        self._reader_thread.start()
        self._stderr_thread = threading.Thread(target=self._stderr_reader, daemon=True)
        self._stderr_thread.start()

    def _reader(self):
        while self._running:
            try:
                msg = read_message(self._server.stdout)
                if msg is None:
                    break
                self._response_queue.put(msg)
            except Exception:
                break

    def _stderr_reader(self):
        for line in self._server.stderr:
            self._stderr_lines.append(line.decode('utf-8', errors='replace').rstrip())

    def _next_id(self) -> int:
        self._req_id += 1
        return self._req_id

    def _send(self, msg: dict):
        self._server.stdin.write(encode_message(msg))
        self._server.stdin.flush()

    def _send_notification(self, method: str, params: dict):
        self._send({"jsonrpc": "2.0", "method": method, "params": params})

    def _send_request(self, method: str, params: dict) -> int:
        req_id = self._next_id()
        self._send({"jsonrpc": "2.0", "id": req_id, "method": method, "params": params})
        return req_id

    def _wait_response(self, req_id: int) -> Optional[dict]:
        deadline = time.time() + self.timeout
        while time.time() < deadline:
            try:
                msg = self._response_queue.get(timeout=0.5)
                # Notifications and progress messages — discard
                if 'id' not in msg:
                    continue
                if msg.get('id') == req_id:
                    return msg
                # Not our response — put back (another thread could be waiting,
                # but we're single-threaded here so just re-queue)
                self._response_queue.put(msg)
                time.sleep(0.05)
            except queue.Empty:
                continue
        return None

    # ── LSP lifecycle ──────────────────────────────────────────────────────────

    def initialize(self) -> bool:
        req_id = self._send_request("initialize", {
            "processId": os.getpid(),
            "rootUri": path_to_uri(self.workspace),
            "workspaceFolders": [{"uri": path_to_uri(self.workspace), "name": os.path.basename(self.workspace)}],
            "capabilities": {
                "textDocument": {
                    "hover":               {"contentFormat": ["plaintext", "markdown"]},
                    "definition":          {"linkSupport": True},
                    "references":          {},
                    "implementation":      {"linkSupport": True},
                    "callHierarchy":       {},
                    "documentSymbol":      {"hierarchicalDocumentSymbolSupport": True},
                    "publishDiagnostics":  {"relatedInformation": True},
                },
                "workspace": {
                    "symbol": {},
                },
            },
            "initializationOptions": self.init_options,
        })

        resp = self._wait_response(req_id)
        if resp is None or 'error' in resp:
            return False

        self._send_notification("initialized", {})
        # Give server a moment to finish indexing basic state
        time.sleep(0.3)
        return True

    def open_file(self, file_path: str, language_id: str):
        content = Path(file_path).read_text(errors='replace')
        self._send_notification("textDocument/didOpen", {
            "textDocument": {
                "uri":        path_to_uri(file_path),
                "languageId": language_id,
                "version":    1,
                "text":       content,
            }
        })
        # Give the server time to parse/index the file
        time.sleep(0.5)

    def shutdown(self):
        self._running = False
        try:
            req_id = self._send_request("shutdown", {})
            self._wait_response(req_id)
            self._send_notification("exit", {})
        except Exception:
            pass
        finally:
            try:
                self._server.terminate()
                self._server.wait(timeout=3)
            except Exception:
                self._server.kill()

    # ── Query methods ──────────────────────────────────────────────────────────

    def hover(self, file_path: str, line: int, col: int) -> Optional[dict]:
        req_id = self._send_request("textDocument/hover", {
            "textDocument": {"uri": path_to_uri(file_path)},
            "position":     {"line": line, "character": col},
        })
        return self._wait_response(req_id)

    def definition(self, file_path: str, line: int, col: int) -> Optional[dict]:
        req_id = self._send_request("textDocument/definition", {
            "textDocument": {"uri": path_to_uri(file_path)},
            "position":     {"line": line, "character": col},
        })
        return self._wait_response(req_id)

    def references(self, file_path: str, line: int, col: int,
                   include_declaration: bool = False) -> Optional[dict]:
        req_id = self._send_request("textDocument/references", {
            "textDocument": {"uri": path_to_uri(file_path)},
            "position":     {"line": line, "character": col},
            "context":      {"includeDeclaration": include_declaration},
        })
        return self._wait_response(req_id)

    def implementations(self, file_path: str, line: int, col: int) -> Optional[dict]:
        req_id = self._send_request("textDocument/implementation", {
            "textDocument": {"uri": path_to_uri(file_path)},
            "position":     {"line": line, "character": col},
        })
        return self._wait_response(req_id)

    def document_symbols(self, file_path: str) -> Optional[dict]:
        req_id = self._send_request("textDocument/documentSymbol", {
            "textDocument": {"uri": path_to_uri(file_path)},
        })
        return self._wait_response(req_id)

    def workspace_symbols(self, query: str) -> Optional[dict]:
        req_id = self._send_request("workspace/symbol", {"query": query})
        return self._wait_response(req_id)

    def call_hierarchy_prepare(self, file_path: str, line: int, col: int) -> Optional[dict]:
        req_id = self._send_request("textDocument/prepareCallHierarchy", {
            "textDocument": {"uri": path_to_uri(file_path)},
            "position":     {"line": line, "character": col},
        })
        return self._wait_response(req_id)

    def call_hierarchy_incoming(self, item: dict) -> Optional[dict]:
        req_id = self._send_request("callHierarchy/incomingCalls", {"item": item})
        return self._wait_response(req_id)

    def call_hierarchy_outgoing(self, item: dict) -> Optional[dict]:
        req_id = self._send_request("callHierarchy/outgoingCalls", {"item": item})
        return self._wait_response(req_id)

    def diagnostics(self, file_path: str, wait_ms: int = 2000) -> List[dict]:
        """
        Diagnostics are pushed by the server via textDocument/publishDiagnostics
        notifications — we can't request them directly. Open the file and drain
        notifications for `wait_ms` milliseconds to collect them.
        """
        collected: List[dict] = []
        uri = path_to_uri(file_path)
        deadline = time.time() + wait_ms / 1000.0
        while time.time() < deadline:
            try:
                msg = self._response_queue.get(timeout=0.1)
                if msg.get('method') == 'textDocument/publishDiagnostics':
                    params = msg.get('params', {})
                    if params.get('uri') == uri:
                        collected.extend(params.get('diagnostics', []))
            except queue.Empty:
                pass
        return collected


# ── Symbol position resolver ───────────────────────────────────────────────────

def find_symbol_position(file_path: str, symbol: str) -> Optional[tuple]:
    """
    Scan the file for the first occurrence of `symbol` and return (line, col).
    Lines and columns are 0-based (LSP convention).
    Falls back to None if not found.
    """
    try:
        lines = Path(file_path).read_text(errors='replace').splitlines()
        for i, line in enumerate(lines):
            col = line.find(symbol)
            if col != -1:
                # Try to land on the symbol itself, not a longer containing word
                before = line[col - 1] if col > 0 else ' '
                after  = line[col + len(symbol)] if col + len(symbol) < len(line) else ' '
                if not (before.isalnum() or before == '_') and \
                   not (after.isalnum()  or after  == '_'):
                    return (i, col)
        # Second pass — relaxed match (symbol appears as substring)
        for i, line in enumerate(lines):
            col = line.find(symbol)
            if col != -1:
                return (i, col)
    except Exception:
        pass
    return None


# ── Output formatters ──────────────────────────────────────────────────────────

SYMBOL_KIND_MAP = {
    1: "File", 2: "Module", 3: "Namespace", 4: "Package", 5: "Class",
    6: "Method", 7: "Property", 8: "Field", 9: "Constructor", 10: "Enum",
    11: "Interface", 12: "Function", 13: "Variable", 14: "Constant",
    15: "String", 16: "Number", 17: "Boolean", 18: "Array", 19: "Object",
    20: "Key", 21: "Null", 22: "EnumMember", 23: "Struct", 24: "Event",
    25: "Operator", 26: "TypeParameter",
}

def format_location(loc: dict, workspace: str) -> str:
    uri  = loc.get('uri', '')
    path = uri_to_path(uri).replace(workspace, '').lstrip('/')
    r    = loc.get('range', {}).get('start', {})
    return f"{path}:{r.get('line', 0) + 1}:{r.get('character', 0) + 1}"


def format_hover(result: dict) -> dict:
    if not result:
        return {"type": "hover", "content": None}
    contents = result.get('result', {})
    if isinstance(contents, dict):
        value = contents.get('value', '') or contents.get('contents', {}).get('value', '')
    elif isinstance(contents, list):
        value = '\n'.join(
            c.get('value', c) if isinstance(c, dict) else str(c)
            for c in contents
        )
    else:
        value = str(contents) if contents else None
    return {"type": "hover", "content": value}


def format_locations(result: dict, query_type: str, workspace: str) -> dict:
    raw = result.get('result') or []
    if isinstance(raw, dict):
        raw = [raw]
    locations = [format_location(loc, workspace) for loc in raw if loc]
    return {"type": query_type, "count": len(locations), "locations": locations}


def format_symbols(result: dict, workspace: str) -> dict:
    raw = result.get('result') or []
    symbols = []
    for s in raw:
        loc = s.get('location', s.get('selectionRange', {}))
        kind_int = s.get('kind', 0)
        entry = {
            "name":      s.get('name', ''),
            "kind":      SYMBOL_KIND_MAP.get(kind_int, str(kind_int)),
            "container": s.get('containerName', ''),
            "location":  format_location(loc, workspace) if isinstance(loc, dict) and 'uri' in loc else '',
        }
        symbols.append(entry)
    return {"type": "symbols", "count": len(symbols), "symbols": symbols}


def format_call_hierarchy(incoming_resp: Optional[dict],
                           outgoing_resp: Optional[dict],
                           workspace: str) -> dict:
    callers  = []
    callees  = []

    if incoming_resp and incoming_resp.get('result'):
        for item in incoming_resp['result']:
            caller = item.get('from', {})
            callers.append({
                "name":     caller.get('name', ''),
                "kind":     SYMBOL_KIND_MAP.get(caller.get('kind', 0), ''),
                "location": format_location(caller.get('uri') and caller or
                            {'uri': caller.get('uri', ''), 'range': caller.get('range', {})}, workspace),
            })

    if outgoing_resp and outgoing_resp.get('result'):
        for item in outgoing_resp['result']:
            callee = item.get('to', {})
            callees.append({
                "name":     callee.get('name', ''),
                "kind":     SYMBOL_KIND_MAP.get(callee.get('kind', 0), ''),
                "location": format_location(callee.get('uri') and callee or
                            {'uri': callee.get('uri', ''), 'range': callee.get('range', {})}, workspace),
            })

    return {
        "type":    "call-hierarchy",
        "callers": callers,
        "callees": callees,
    }


def format_diagnostics(diags: List[dict]) -> dict:
    severity_map = {1: "ERROR", 2: "WARNING", 3: "INFORMATION", 4: "HINT"}
    formatted = []
    for d in diags:
        r = d.get('range', {}).get('start', {})
        formatted.append({
            "severity": severity_map.get(d.get('severity', 1), 'ERROR'),
            "line":     r.get('line', 0) + 1,
            "col":      r.get('character', 0) + 1,
            "message":  d.get('message', ''),
            "code":     d.get('code', ''),
        })
    formatted.sort(key=lambda x: (x['line'], x['col']))
    return {"type": "diagnostics", "count": len(formatted), "diagnostics": formatted}


def render_table(data: dict):
    """Pretty-print structured result as a human-readable table."""
    t = data.get('type', '')

    if t == 'hover':
        content = data.get('content') or '(no hover information)'
        print("\n── Hover ──────────────────────────────────────")
        print(content)
        print()

    elif t in ('references', 'definition', 'implementations'):
        label = t.capitalize()
        locs  = data.get('locations', [])
        print(f"\n── {label} ({data.get('count', 0)}) ──────────────────────────────────────")
        if not locs:
            print("  (none found)")
        for loc in locs:
            print(f"  {loc}")
        print()

    elif t == 'symbols':
        syms = data.get('symbols', [])
        print(f"\n── Symbols ({data.get('count', 0)}) ──────────────────────────────────────")
        print(f"  {'Name':<40} {'Kind':<16} {'Location'}")
        print(f"  {'─'*40} {'─'*16} {'─'*40}")
        for s in syms:
            container = f"[{s['container']}] " if s['container'] else ""
            print(f"  {container + s['name']:<40} {s['kind']:<16} {s['location']}")
        print()

    elif t == 'call-hierarchy':
        callers = data.get('callers', [])
        callees = data.get('callees', [])
        print("\n── Call Hierarchy ──────────────────────────────────────")
        print(f"  Callers ({len(callers)}):")
        if not callers:
            print("    (none)")
        for c in callers:
            print(f"    ← {c['name']} [{c['kind']}]  {c['location']}")
        print(f"\n  Callees ({len(callees)}):")
        if not callees:
            print("    (none)")
        for c in callees:
            print(f"    → {c['name']} [{c['kind']}]  {c['location']}")
        print()

    elif t == 'diagnostics':
        diags = data.get('diagnostics', [])
        print(f"\n── Diagnostics ({data.get('count', 0)}) ──────────────────────────────────────")
        if not diags:
            print("  ✓ No diagnostics.")
        for d in diags:
            sev = d['severity']
            icon = '✗' if sev == 'ERROR' else '⚠' if sev == 'WARNING' else 'ℹ'
            print(f"  {icon} [{sev}] line {d['line']}:{d['col']} — {d['message']}")
            if d['code']:
                print(f"      code: {d['code']}")
        print()

    else:
        print(json.dumps(data, indent=2))


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='LSP JSON-RPC client')
    parser.add_argument('--server-cmd',    required=True,  help='LSP server command (e.g. pylsp)')
    parser.add_argument('--workspace',     required=True,  help='Project root directory')
    parser.add_argument('--file',          required=False, help='Target source file')
    parser.add_argument('--query',         required=True,
                        choices=['hover', 'definition', 'references', 'implementations',
                                 'symbols', 'workspace-symbols', 'call-hierarchy',
                                 'diagnostics'],
                        help='Query type')
    parser.add_argument('--symbol',        help='Symbol name to look up')
    parser.add_argument('--line',          type=int, default=None,
                        help='0-based line number (overrides --symbol search)')
    parser.add_argument('--col',           type=int, default=None,
                        help='0-based column number (overrides --symbol search)')
    parser.add_argument('--language-id',   default='',    help='LSP language ID (python, go, java, ...)')
    parser.add_argument('--output',        choices=['json', 'table'], default='table')
    parser.add_argument('--timeout',       type=int, default=30, help='Per-request timeout (seconds)')
    parser.add_argument('--init-options',  default='{}',  help='JSON init options passed to the server')
    parser.add_argument('--include-declaration', action='store_true',
                        help='Include the declaration itself in references results')
    args = parser.parse_args()

    # Validate file-dependent queries
    file_queries = {'hover', 'definition', 'references', 'implementations',
                    'symbols', 'call-hierarchy', 'diagnostics'}
    if args.query in file_queries and not args.file:
        print(json.dumps({"error": f"--file is required for query '{args.query}'"}))
        sys.exit(1)

    if args.file and not os.path.isfile(args.file):
        print(json.dumps({"error": f"File not found: {args.file}"}))
        sys.exit(1)

    # Resolve position
    line, col = args.line, args.col
    if line is None and args.symbol and args.file:
        pos = find_symbol_position(args.file, args.symbol)
        if pos is None:
            print(json.dumps({"error": f"Symbol '{args.symbol}' not found in {args.file}"}))
            sys.exit(1)
        line, col = pos

    if line is None and args.query not in {'symbols', 'workspace-symbols', 'diagnostics'}:
        print(json.dumps({"error": "Provide --symbol or --line/--col for positional queries"}))
        sys.exit(1)

    try:
        init_options = json.loads(args.init_options)
    except json.JSONDecodeError:
        init_options = {}

    # Start session
    session = LspSession(
        server_cmd=args.server_cmd,
        workspace=args.workspace,
        timeout=args.timeout,
        init_options=init_options,
    )

    result = {"error": "unknown error"}
    try:
        if not session.initialize():
            print(json.dumps({"error": "LSP server initialize handshake failed"}))
            sys.exit(1)

        if args.file:
            session.open_file(args.file, args.language_id)

        workspace = os.path.abspath(args.workspace)

        # ── Dispatch query ─────────────────────────────────────────────────
        if args.query == 'hover':
            resp = session.hover(args.file, line, col)
            result = format_hover(resp)

        elif args.query == 'definition':
            resp = session.definition(args.file, line, col)
            result = format_locations(resp, 'definition', workspace)

        elif args.query == 'references':
            resp = session.references(args.file, line, col,
                                      include_declaration=args.include_declaration)
            result = format_locations(resp, 'references', workspace)

        elif args.query == 'implementations':
            resp = session.implementations(args.file, line, col)
            result = format_locations(resp, 'implementations', workspace)

        elif args.query == 'symbols':
            resp = session.document_symbols(args.file)
            result = format_symbols(resp, workspace)

        elif args.query == 'workspace-symbols':
            symbol_query = args.symbol or ''
            resp = session.workspace_symbols(symbol_query)
            result = format_symbols(resp, workspace)

        elif args.query == 'call-hierarchy':
            prep = session.call_hierarchy_prepare(args.file, line, col)
            items = (prep or {}).get('result') or []
            if not items:
                result = {"type": "call-hierarchy", "callers": [], "callees": [],
                          "note": "Server returned no call hierarchy items for this position"}
            else:
                item = items[0]
                incoming = session.call_hierarchy_incoming(item)
                outgoing = session.call_hierarchy_outgoing(item)
                result = format_call_hierarchy(incoming, outgoing, workspace)

        elif args.query == 'diagnostics':
            diags = session.diagnostics(args.file, wait_ms=args.timeout * 1000 // 3)
            result = format_diagnostics(diags)

    finally:
        session.shutdown()

    if args.output == 'json':
        print(json.dumps(result, indent=2))
    else:
        render_table(result)


if __name__ == '__main__':
    main()
