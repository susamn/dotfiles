from __future__ import annotations

import asyncio
import contextlib
import logging
import os

from . import protocol
from .auth import is_allowed, peer_uid
from .config import Config
from .op_client import OnePasswordVault, SecretNotFound

logger = logging.getLogger(__name__)


class Broker:
    def __init__(self, config: Config) -> None:
        self._config = config
        self._vault = OnePasswordVault(
            token=config.token,
            vault=config.vault,
            integration_name=config.integration_name,
            integration_version=config.integration_version,
        )

    async def serve_forever(self) -> None:
        socket_path = self._config.socket_path
        if os.path.exists(socket_path):
            os.unlink(socket_path)

        server = await asyncio.start_unix_server(self._handle_connection, path=socket_path)
        os.chmod(socket_path, 0o666)  # filesystem perms only gate connect(); SO_PEERCRED gates access
        logger.info("op-vault-broker listening on %s (vault=%r)", socket_path, self._config.vault)

        try:
            async with server:
                await server.serve_forever()
        finally:
            if os.path.exists(socket_path):
                os.unlink(socket_path)

    async def _handle_connection(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        peer = writer.get_extra_info("peername") or "unknown"

        try:
            raw_sock = writer.get_extra_info("socket")
            uid = peer_uid(raw_sock)

            if not is_allowed(uid, self._config.allowed_uids):
                logger.warning("rejected connection from uid=%s (not on allowlist)", uid)
                writer.write(protocol.error_response("forbidden"))
                await writer.drain()
                return

            try:
                line = await asyncio.wait_for(
                    reader.readline(), timeout=5.0
                )
            except asyncio.TimeoutError:
                writer.write(protocol.error_response("bad_request"))
                await writer.drain()
                return

            if not line or len(line) > protocol.MAX_LINE_BYTES:
                writer.write(protocol.error_response("bad_request"))
                await writer.drain()
                return

            try:
                item, field = protocol.parse_request(line)
            except protocol.BadRequest as exc:
                logger.info("bad request from uid=%s: %s", uid, exc)
                writer.write(protocol.error_response("bad_request"))
                await writer.drain()
                return

            logger.info("uid=%s requested item=%r field=%r", uid, item, field)
            try:
                value = await self._vault.resolve(item, field)
            except SecretNotFound:
                writer.write(protocol.error_response("resolve_failed"))
                await writer.drain()
                return

            writer.write(protocol.ok_response(value))
            await writer.drain()
        except Exception:
            logger.exception("unhandled error serving connection from %s", peer)
            with contextlib.suppress(Exception):
                writer.write(protocol.error_response("resolve_failed"))
                await writer.drain()
        finally:
            # Drain any request bytes the client already sent but we never
            # read (e.g. the forbidden/timeout early-returns above never
            # call readline()). Without this, closing with unread input
            # pending makes the kernel send RST instead of a clean close,
            # which surfaces to the client as ConnectionResetError instead
            # of the error response we just wrote.
            with contextlib.suppress(Exception):
                await asyncio.wait_for(reader.read(), timeout=0.5)
            writer.close()
            with contextlib.suppress(Exception):
                await writer.wait_closed()
