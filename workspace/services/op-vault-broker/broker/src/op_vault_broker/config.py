"""Loads the broker's config.toml and its systemd-decrypted service account token."""

from __future__ import annotations

import os
import tomllib
from dataclasses import dataclass
from pathlib import Path

DEFAULT_CONFIG_PATH = "/etc/op-vault-broker/config.toml"
DEFAULT_SOCKET_PATH = "/run/op-vault-broker/broker.sock"
CREDENTIAL_ID = "op-token"


class ConfigError(Exception):
    pass


@dataclass(frozen=True)
class Config:
    vault: str
    integration_name: str
    integration_version: str
    socket_path: str
    allowed_uids: frozenset[int]
    token: str


def _config_path() -> Path:
    configuration_dir = os.environ.get("CONFIGURATION_DIRECTORY")
    if configuration_dir:
        return Path(configuration_dir) / "config.toml"
    return Path(DEFAULT_CONFIG_PATH)


def _token_path() -> Path:
    credentials_dir = os.environ.get("CREDENTIALS_DIRECTORY")
    if not credentials_dir:
        raise ConfigError(
            "CREDENTIALS_DIRECTORY is not set; run this under the "
            "op-vault-broker.service unit (LoadCredentialEncrypted=op-token:...)"
        )
    return Path(credentials_dir) / CREDENTIAL_ID


def load_config() -> Config:
    path = _config_path()
    try:
        raw = tomllib.loads(path.read_text())
    except FileNotFoundError as exc:
        raise ConfigError(f"config file not found: {path}") from exc
    except tomllib.TOMLDecodeError as exc:
        raise ConfigError(f"malformed config file {path}: {exc}") from exc

    try:
        vault = raw["vault"]
        callers = raw["allowed_callers"]
    except KeyError as exc:
        raise ConfigError(f"missing required key in {path}: {exc}") from exc

    try:
        allowed_uids = frozenset(int(caller["uid"]) for caller in callers)
    except (KeyError, TypeError, ValueError) as exc:
        raise ConfigError(f"malformed [[allowed_callers]] entries in {path}: {exc}") from exc

    if not allowed_uids:
        raise ConfigError(f"{path} defines no allowed_callers; broker would reject everyone")

    socket_path = raw.get("socket_path", DEFAULT_SOCKET_PATH)
    integration_name = raw.get("integration_name", "op-vault-broker")
    integration_version = raw.get("integration_version", "1.0.0")

    token_path = _token_path()
    try:
        token = token_path.read_text().strip()
    except FileNotFoundError as exc:
        raise ConfigError(f"service account token credential not found: {token_path}") from exc

    if not token:
        raise ConfigError(f"service account token credential is empty: {token_path}")

    return Config(
        vault=vault,
        integration_name=integration_name,
        integration_version=integration_version,
        socket_path=socket_path,
        allowed_uids=allowed_uids,
        token=token,
    )
