"""Thin wrapper around the official 1Password SDK, scoped to one vault."""

from __future__ import annotations

import logging

from onepassword.client import Client

logger = logging.getLogger(__name__)


class SecretNotFound(Exception):
    pass


class OnePasswordVault:
    def __init__(self, token: str, vault: str, integration_name: str, integration_version: str) -> None:
        self._token = token
        self._vault = vault
        self._integration_name = integration_name
        self._integration_version = integration_version
        self._client: Client | None = None

    async def _get_client(self) -> Client:
        if self._client is None:
            self._client = await Client.authenticate(
                auth=self._token,
                integration_name=self._integration_name,
                integration_version=self._integration_version,
            )
        return self._client

    async def resolve(self, item: str, field: str) -> str:
        client = await self._get_client()
        reference = f"op://{self._vault}/{item}/{field}"
        try:
            return await client.secrets.resolve(reference)
        except Exception as exc:
            logger.warning("resolve failed for item=%r field=%r: %s", item, field, exc)
            raise SecretNotFound(str(exc)) from exc
