"""Peer-credential authorization: the connecting process's UID is the credential."""

from __future__ import annotations

import socket
import struct

_SO_PEERCRED_FMT = "3i"  # pid_t, uid_t, gid_t


def peer_uid(sock: socket.socket) -> int:
    raw = sock.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize(_SO_PEERCRED_FMT))
    _pid, uid, _gid = struct.unpack(_SO_PEERCRED_FMT, raw)
    return uid


def is_allowed(uid: int, allowed_uids: frozenset[int]) -> bool:
    return uid in allowed_uids
