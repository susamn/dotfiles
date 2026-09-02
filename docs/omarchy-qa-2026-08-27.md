# Omarchy Q&A — 2026-08-27

Read-only session. No config or code was modified. This is a running log of
questions asked and concise answers.

---

## Session ground rules

Strictly read-only session: no edits to `~/.config/`, no state-changing
`omarchy` / `hyprctl` commands, no package or system changes. Only safe reads
(`cat`, `omarchy commands`, `omarchy <group> --help`, `omarchy debug --no-sudo
--print`, reading `/usr/share/omarchy/`, `hyprctl` query subcommands).

The only write this session is this Q&A document.

---

## Q: Coming from KDE's software center — what's the best way to get GUI tools in Omarchy? (not manual AUR/pacman)

Omarchy ships **no graphical app store** by design; it's menu/TUI-first.

- **Omarchy Menu -> Install** is the curated "software center": open menu
  (`Super + Alt + Space`), choose Install -> Apps / Web Apps / TUIs /
  Development / Editors / Gaming / Service / Fonts.
- **Fuzzy TUI pickers:**
  ```bash
  omarchy pkg install       # Arch + OPR packages
  omarchy pkg aur install   # AUR packages
  omarchy pkg remove
  ```
- **Web apps / TUIs as desktop apps:**
  ```bash
  omarchy webapp install    # URL -> launchable app
  omarchy tui install       # terminal app -> launcher
  ```
- **Want an actual GUI store?** Not included. Install one yourself: `bauh`
  (closest to KDE Discover; Arch/AUR/Flatpak/Snap), or `octopi` / `pamac-gtk`.
  Flatpak itself is not set up by default.

---

## Q: Best tool to inspect/query databases (MySQL, Postgres, Oracle, SQLite) — terminal and GUI?

Omarchy ships nothing (only the `sqlite` lib). `omarchy install docker dbs`
only runs DB *servers*, not clients. Choose your own:

**GUI**
- `dbeaver` (AUR) — universal, the only good **Oracle** option. Heavy (Java).
- `beekeeper-studio` (AUR) — lighter, nicer UI; MySQL/Postgres/SQLite/SQL Server, no Oracle CE.
- `dbgate-bin` (AUR) — lightweight Electron; MySQL/Postgres/SQLite/Oracle/Mongo.

**Terminal**
- `usql` — one CLI for Postgres, MySQL, **Oracle**, SQLite (`usql oracle://...`).
- `lazysql` — universal TUI browser + query pane (MySQL/Postgres/SQLite, no Oracle).
- Per-engine, best UX: `pgcli` (Postgres), `mycli` (MySQL), `litecli` / `sqlite3` (SQLite).
- `harlequin` — terminal SQL IDE (SQLite/Postgres/DuckDB/MySQL).

Practical combo: `usql` + `pgcli`/`mycli`/`litecli` + DBeaver or Beekeeper for GUI.

---
