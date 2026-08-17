"""Wire format: one newline-delimited JSON request, one newline-delimited JSON response."""

from __future__ import annotations

import json

MAX_LINE_BYTES = 65536
DEFAULT_FIELD = "password"


class BadRequest(Exception):
    pass


def parse_request(line: bytes) -> tuple[str, str]:
    try:
        payload = json.loads(line.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise BadRequest(f"invalid JSON: {exc}") from exc

    if not isinstance(payload, dict):
        raise BadRequest("request must be a JSON object")

    item = payload.get("item")
    if not isinstance(item, str) or not item:
        raise BadRequest("'item' must be a non-empty string")

    field = payload.get("field", DEFAULT_FIELD)
    if not isinstance(field, str) or not field:
        raise BadRequest("'field' must be a non-empty string")

    return item, field


def ok_response(value: str) -> bytes:
    return (json.dumps({"ok": True, "value": value}) + "\n").encode("utf-8")


def error_response(error: str) -> bytes:
    return (json.dumps({"ok": False, "error": error}) + "\n").encode("utf-8")
