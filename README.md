# dotfiles

Configuration, tooling, and background services for a Linux workstation, deployed
with GNU Stow.

Everything here is symlinked into `$HOME` from one repository, so a machine is
reproducible from a clone plus two commands. The parts that cannot be symlinked —
systemd units in `/etc`, engines in `/usr/local/bin`, package-manager hooks — are
installed from here by [`linux-system-manager`](workspace/tools/linux-system-manager).

---

## Layout

```
~/dotfiles/
├── .config/              # app configs (Hyprland, kitty, nvim, waybar, rofi, mpd, …)
│   ├── rclone-sync-profiles/   # one .conf per background sync or mount
│   └── _secured/               # submodule — GPG-encrypted secrets
├── workspace/            # stowed to ~/workspace
│   ├── aistuff/              # submodule — agent skills + MCP defs (NOT stowed)
│   ├── scripts/              # standalone scripts, aliased (see below)
│   ├── services/             # $SERVICES_PATH — systemd units + engines
│   ├── tools/                # larger tools, each with quick-start.sh
│   ├── install/              # package manifests
│   └── sdk/                  # language caches ($M2_HOME, $GOPATH, …)
├── .github/workflows/    # CI
├── onboard.sh            # first-run bootstrap for a brand-new machine
├── do-stow.sh            # stow + deploy skills + generate agent instructions + sync MCP
├── do-unstow.sh          # reverse of do-stow.sh
├── .stow-local-ignore    # stow's ignore list — REPLACES stow's built-in defaults
└── .ignored              # extra ignore patterns read by do-stow.sh
```

## Setting up a new machine

```bash
git clone --recurse-submodules git@github.com:susamn/dotfiles.git ~/dotfiles
cd ~/dotfiles
./onboard.sh          # OS deps, brew, nvm/node, sdkman/java, pyenv, PATH, packages, zsh, stow
rclc                  # decrypt and assemble ~/.config/rclone/rclone.conf
asm                   # → 54 review, 55 install services
```

`onboard.sh` supports Pop!\_OS/Ubuntu/Debian, Arch, Fedora/RHEL and macOS, and ends
by running `do-stow.sh` and setting the default shell.

> **Order matters: `rclc` before `asm`.** The service installer validates every
> rclone profile against the live backend before activating it. Without
> `rclone.conf` every profile fails validation, nothing is enabled, and you get
> manual instructions rather than an error — it fails quietly.

For everything after the first run, `./do-stow.sh` is the only command needed.

## What `do-stow.sh` does beyond stowing

1. **Stows** the repo into `$HOME`, honouring `.stow-local-ignore` and `.ignored`.
2. **Skills** — symlinks every active skill in `workspace/aistuff/skills/` into
   *every* agent's skills directory. There is no per-agent selection.
3. **Instructions** — *generates* each agent's instruction file (e.g.
   `~/.claude/CLAUDE.md`) from `workspace/aistuff/skills/AGENTS-TEMPLATE.md`.
   These are real files and are **overwritten on every run** — edit the template,
   never the generated file.
4. **MCP** — merges `workspace/aistuff/mcp/mcp-servers.json` into each agent's
   MCP config via `workspace/scripts/agm.sh`.

## Background services

Units and engines live in `workspace/services` (`$SERVICES_PATH`), not inside the
tool that installs them. Run `asm` (linux-system-manager) → **Section 5**:

| key | does |
|---|---|
| 51–53 | status, failures, start/stop/toggle |
| 54 | show what is installed vs available — read-only, no password |
| 55 | install or update selected items |

Adding an rclone sync needs **a profile and nothing else** — the profile name
becomes the systemd instance, so `rclone-sync@music-tracks.service` runs
`rclone-sync.sh music-tracks`. Create one with `asm` → 62, which writes into this
repo and links it into `~/.config`.

Installation is additive and idempotent: re-running never disables or removes
anything. There is deliberately **no uninstall path** — removing a profile leaves
its `/etc` units behind, and its now-dangling stow symlink in `~/.config`, for you
to clean up. The full sequence is in the `dotfiles-management` skill,
`references/music-sync-and-mpd.md` §9.

## Environment variables

Exported in every shell; use these rather than hardcoded paths.

| variable | contents |
|---|---|
| `$WORKSPACE_PATH` | `~/workspace` |
| `$SCRIPTS_PATH` · `$TOOLS_PATH` · `$SERVICES_PATH` | scripts, tools, systemd units |
| `$INSTALL_PATH` · `$SDK_PATH` | package manifests, SDKs |
| `$M2_HOME` · `$GOPATH` · `$CARGO_HOME` · `$NPM_CONFIG_CACHE` · `$PIP_CACHE_DIR` | shared language caches |

Dependency caches are shared deliberately — a build that defaults to `~/.m2`
re-downloads the world and diverges from every other build on the machine.

## Scripts and tools

35 scripts in `workspace/scripts`, most aliased. `als` searches them interactively;
`workspace/.alias_descriptions` documents every alias.

| alias | does |
|---|---|
| `asm` | system manager: boot safety, updates, package timeline, services, BPF |
| `rclc` | assemble/split the GPG-encrypted rclone backends |
| `mpdc` | regenerate `mpd.conf`, manage the MPD daemon, query the library |
| `gsh` · `ghr` · `gch` · `gitb` | git stash / hard-reset / checkout / branch helpers |
| `jwtd` · `gsec` · `ytd` | JWT decode, secure resource generation, media download |
| `ff` · `uff` · `cht` · `pkgs` | fuzzy find, cheatsheets, package listing |

Larger tools live in `workspace/tools`; several expose a `quick-start.sh` entry
point, the rest are run directly or through their own alias.

## Submodules

Seven, so clone with `--recurse-submodules`:

| path | holds |
|---|---|
| `workspace/aistuff` | agent skills and MCP definitions |
| `.config/_secured` | GPG-encrypted secrets |
| `workspace/tools/{helpful-tools-v2,performance-manager,mosaic}` | standalone tools |
| `workspace/tests/test_helper/bats-{support,assert}` | shell test helpers |

Committing a change inside one is two steps — commit in the submodule, then
`git add <path>` here to bump the pointer.

`linux-system-manager` used to be an eighth. It was absorbed as a plain directory;
its 37 commits are preserved on the `lsm-history/*` branches. Those branches hold
the tool's files at *repo root*, so they are reference-only — **do not merge them**
into `main`.

## Agent skills

19 active skills in `workspace/aistuff/skills/`, deployed to claude, codex, gemini,
cursor and copilot. A skill is disabled by renaming its directory to
`<name>.disabled` — that suffix is the only mechanism — then re-running
`do-stow.sh`.

Start from the `dotfiles-management` skill; its `references/` cover service
installation, `personal-services.target` semantics, the music/MPD chain, and
working on `linux-system-manager` itself.

## Conventions

- Never edit a generated file: `~/.claude/CLAUDE.md` and `~/.config/mpd/mpd.conf`
  are both rebuilt from templates and will silently discard your changes.
- Keep configuration in this repo and let stow place it. A real file sitting among
  stow symlinks works today and is missing on the next machine.
- `.stow-local-ignore` replaces stow's built-in ignore list rather than extending
  it, which is why the defaults are repeated there.
