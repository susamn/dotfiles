# op-vault-broker — Architecture

## Problem

Give local tools and scripts access to secrets stored in one specific 1Password
vault, without ever letting a calling process hold a 1Password credential
itself. Two consumers:

- `opv` — a CLI, requires root (`sudo opv ...`).
- `opvaultclient` — a Python library other apps embed; the caller's own OS
  identity is its authentication, nothing is baked into the library.

Neither consumer talks to 1Password directly. Both talk to a local broker
service, which is the only thing that holds 1Password credentials.

## Components

```
caller (opv CLI, as root)  ─┐
                             ├─→ Unix domain socket ─→ op-vault-broker (daemon) ─→ 1Password Cloud API
caller (embedding app)     ─┘        /run/op-vault-broker/broker.sock      (onepassword-sdk)
```

- **`broker/`** (`op_vault_broker`) — the daemon. Only component with a
  1Password dependency (`onepassword-sdk`) and network egress.
- **`client-lib/`** (`opvaultclient`) — a stdlib-only sync socket client.
  Installable independently; carries zero 1Password dependency, so embedding
  it in another app never exposes 1Password credentials to that app.
- **`cli/opv`** — a thin wrapper around `opvaultclient`, gated on
  `os.geteuid() == 0`.

## 1Password access: one vault, by construction

The broker authenticates to 1Password using a **Service Account token that is
itself scoped to exactly one vault** in the 1Password admin console. This is
the "single directory/project" restriction the whole system exists to
enforce — it is not application logic that could have a bug, it is a
capability 1Password's API refuses to exceed. The broker's config also
records the vault name for logging/sanity-checking, but the real boundary is
the token's own scope.

Every secret fetch is a live call to `client.secrets.resolve("op://<vault>/<item>/<field>")`.
The broker **never caches or persists a resolved secret value** — "realtime
password at runtime" is a hard requirement, not just a phrase: each request
is a fresh network round-trip to 1Password.

## Encrypted at rest: the Service Account token

The only long-lived secret this system stores on disk is the 1Password
Service Account token, and it is never stored in plaintext:

- `install.sh` calls `systemd-creds encrypt` to turn the plaintext token into
  `/etc/credstore.encrypted/op-vault-broker.token`, bound to this host's
  TPM2/machine key. The plaintext copy is discarded immediately after.
- The unit uses `LoadCredentialEncrypted=op-token:op-vault-broker.token`.
  systemd decrypts it at process start into a private, mode-0400 tmpfs
  credential directory (`$CREDENTIALS_DIRECTORY/op-token`) that only this
  unit's processes can read — never written to a regular, persistent
  filesystem path in plaintext.
- The broker reads that file once at startup and passes the token directly
  to `Client.authenticate(auth=token, ...)`. It is held in memory only.

Resolved secret *values* are never written to disk at all — they exist only
in-memory for the duration of a single request/response.

## Transport & authorization: Unix socket + SO_PEERCRED

The broker listens on `/run/op-vault-broker/broker.sock` (an asyncio Unix
server). The socket file itself is left connectable by any local process —
filesystem permissions are not the authorization boundary here. Instead, on
every accepted connection the broker reads the peer's credentials via
`SO_PEERCRED` (pid, uid, gid) and checks the uid against an explicit
allowlist in `/etc/op-vault-broker/config.toml`. A UID not on the allowlist
gets `{"ok": false, "error": "forbidden"}` and the connection is closed
without ever touching 1Password.

This is "authentication provided by the caller": the library injects no
token and performs no handshake. The caller's own process identity *is* the
credential — an embedding app must already be running as an allowlisted
Linux user, which is a decision the operator (not the library) makes when
provisioning that app's system user and adding it to the allowlist.

`sudo opv ...` works out of the box because `uid=0` is always on the
allowlist.

## Wire protocol

Newline-delimited JSON, one request/response pair per connection:

```
→ {"item": "<item-name-or-id>", "field": "password"}
← {"ok": true, "value": "<secret>"}
← {"ok": false, "error": "forbidden" | "not_found" | "resolve_failed" | "bad_request"}
```

Internal exceptions from the 1Password SDK are logged server-side (to the
journal, via `personal-services.target`) with the requesting uid/pid/item —
never with the resolved value — and surfaced to the caller only as the
generic `resolve_failed` code, so failure details never leak over the
socket.

## Process hardening

`op-vault-broker.service` runs under `DynamicUser=yes` (no static system
user, no home, no shell) with `ProtectSystem=strict`, dropped capabilities,
`RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6` (needs outbound TCP/DNS
for the 1Password API, nothing else), and is attached to
`personal-services.target` per this repo's systemd-service-creator
convention.

## Explicitly out of scope

- No secret caching, no local secret store beyond the encrypted token.
- No per-app token issuance — auth is OS-identity-based only (by design
  choice; see the caller-auth decision above).
- No TLS between broker and 1Password: that's handled entirely inside the
  official `onepassword-sdk`.
