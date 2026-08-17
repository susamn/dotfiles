"""Sync Unix-socket client for op-vault-broker.

Carries no 1Password dependency and injects no auth token: the broker
authorizes callers by the connecting process's own UID (SO_PEERCRED), so
being able to reach the socket as an allowlisted user *is* the credential.
"""

from __future__ import annotations

import json
import socket

DEFAULT_SOCKET_PATH = "/run/op-vault-broker/broker.sock"
DEFAULT_TIMEOUT_SECONDS = 5.0
MAX_RESPONSE_BYTES = 65536


class OpVaultError(Exception):
    """Raised for any failure talking to op-vault-broker, including denied requests."""


class OpVaultClient:
    def __init__(
        self,
        socket_path: str = DEFAULT_SOCKET_PATH,
        timeout: float = DEFAULT_TIMEOUT_SECONDS,
    ) -> None:
        self._socket_path = socket_path
        self._timeout = timeout

    def get(self, item: str, field: str = "password") -> str:
        """Fetch one secret field for `item` from the broker's vault, live."""
        request = {"item": item, "field": field}
        raw = self._roundtrip(request)

        try:
            response = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise OpVaultError(f"malformed response from broker: {exc}") from exc

        if not response.get("ok"):
            raise OpVaultError(response.get("error", "unknown_error"))

        return response["value"]

    def _roundtrip(self, request: dict) -> str:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(self._timeout)
        try:
            sock.connect(self._socket_path)
            sock.sendall((json.dumps(request) + "\n").encode("utf-8"))
            sock.shutdown(socket.SHUT_WR)

            chunks: list[bytes] = []
            total = 0
            while True:
                chunk = sock.recv(4096)
                if not chunk:
                    break
                total += len(chunk)
                if total > MAX_RESPONSE_BYTES:
                    raise OpVaultError("response from broker exceeded size limit")
                chunks.append(chunk)
        except OSError as exc:
            raise OpVaultError(
                f"cannot reach op-vault-broker at {self._socket_path}: {exc}"
            ) from exc
        finally:
            sock.close()

        raw = b"".join(chunks).decode("utf-8").strip()
        if not raw:
            raise OpVaultError("empty response from broker")
        return raw
