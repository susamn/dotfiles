# linux-system-manager

A distro-agnostic, configuration-driven CLI system manager and package operations timeline monitor for Linux. 

## Features
- **Distro-Agnostic Architecture**: The parent layer (`linux-system-manager.sh`) is written in Python and is completely independent of distribution-specific logic, loading menu paths and options dynamically from JSON configs.
- **Dynamic Capabilities Map**: Capabilities and menu keys (e.g. `1a`, `32`, `51`) are mapped in a distro's `menu.json` file to run native scripts or binaries.
- **Unified Services Dashboard**: Section 4 answers "is anything broken?" in one screen — system service counts, failed units, and the personal/custom units from this repository, still visually segregated but no longer split across two menu sections. Full listings stay one keystroke away behind the dashboard's drill-down.
- **Service Segregation**: Standard system services and timers are reported separately from repository-installed custom/personal services and timers, which keep their own controls (start, stop, enable, disable, logs).
- **Dual-Scope Personal Services**: Personal units span both systemd managers. Units in `services/` are installed system-wide; units in `services/user/` are installed per-user. Each listed unit is tagged `[system]` or `[user]`, and every query and toggle is routed to the manager that actually owns it.
- **Boot Safety Validation**: Automatically checks partition status, kernel images, and bootloader configuration before rebooting (supports automatic sudo escalation).
- **Package Timeline Logger**: Log installs, upgrades, reinstalls, and removals via native package manager hooks.
- **Universal Installer**: Setup custom systemd services and register distro package manager hooks (Pacman, APT, DNF, etc.) with a single installer script.

## Directory Structure
```
linux-system-manager/
├── linux-system-manager.sh      # Main menu runner (distro-agnostic)
├── install.py                   # Service and hooks installer (distro-agnostic)
├── test_*.py                    # Unit, contract, and regression suites
├── SKILL.md                     # Local maintainer & developer guide
├── services/                    # System-scope units → /etc/systemd/system
│   └── user/                    # User-scope units   → ~/.config/systemd/user
└── distros/                     # Distro-specific configuration modules
    └── arch/
        ├── menu.json            # Capabilities menu mapping
        ├── install_hooks.sh     # Hook installer script
        └── *.sh                 # Distro native shell scripts
```

## Getting Started

### 1. Installation

From the menu, **45** (*Personal Service Units — status & install*). It lists
what is already installed before changing anything, and browsing that list costs
no password — escalation happens only once you have selected something to write.

Or non-interactively:

```bash
./install.py --status        # what is installed, no root needed
./install.py --interactive   # choose what to install
sudo ./install.py            # install everything
```

Installation is idempotent and additive: re-running never disables or removes
anything. Units already matching their source are reported as installed and
skipped.

### 2. Run the System Manager
To start the interactive CLI menu:
```bash
./linux-system-manager.sh
```

### 3. Running Tests
To run the full suite:
```bash
python3 -m unittest discover -s . -p 'test_*.py' -v
```

| Suite | Covers |
|---|---|
| `test_sys_manager.py` | Distro detection, menu loading/rendering, action dispatch, installer |
| `test_menu_config.py` | Every `menu.json`: schema, unique action codes, and that each `exec` resolves |
| `test_regressions.py` | Bugs that actually shipped — each verified to fail against the pre-fix code |

Shell scripts are linted separately in CI. To reproduce locally:
```bash
shellcheck --severity=warning --exclude=SC2155 distros/*/*.sh services/*.sh
```

## Personal Services: Scope and Ownership

Personal units span **two systemd managers**, and which one a unit belongs to determines everything about how it is installed, queried, and toggled.

| | `services/` | `services/user/` |
|---|---|---|
| Scope | system | user |
| Installed to | `/etc/systemd/system/` | `~/.config/systemd/user/` |
| Grouped by | `personal-services.target` (`WantedBy=multi-user.target`) | `personal-services.target` (`WantedBy=default.target`) |
| Runs without a login session | yes | no |
| Use for | daemons, boot-time work, anything root-owned | anything needing `$HOME`, a session bus, or per-user credentials |

### The two `personal-services.target` files are not duplicates

They share a unit name because the system and user managers **share no namespace** — `personal-services.target` in one is a completely unrelated unit from the one in the other. They are distinguished by directory, not by name.

> [!WARNING]
> `multi-user.target` does not exist in the user manager. A user unit declaring `WantedBy=multi-user.target` does **not** error — `systemctl --user enable` accepts it, writes the symlink, and the unit then silently never activates. This fails quieter than a crash, so do not "de-duplicate" these two files by deleting one and symlinking the other into both places.

The tool queries `personal-services.target` in both managers, tags every listed unit `[system]` or `[user]`, and routes each query and state change to the manager that owns it. Notably, state changes use `sudo systemctl` for system units and plain `systemctl --user` for user units — `sudo systemctl --user` would address *root's* user manager, enabling the unit for the wrong account while reporting success.

### Deploying units from an external manager

`install.py` copies `services/user/*` into the invoking user's `~/.config/systemd/user/`, chowns the files back to that user, and reloads their manager via `sudo -u <user>` with `XDG_RUNTIME_DIR` set — never as root.

If a destination path is **already a symlink resolving to this repository's source file**, the installer leaves it alone and reports it as externally managed. This lets a dotfiles manager own the deployment while this repository stays the single source of truth for the content:

```
linux-system-manager/services/user/personal-services.target   ← canonical file
                    ▲
                    │  symlink, checked into the dotfiles repo
dotfiles/.config/systemd/user/personal-services.target
                    ▲
                    │  symlink, created by the dotfiles manager (e.g. GNU Stow)
~/.config/systemd/user/personal-services.target               ← what systemd reads
```

The unit content is versioned here exactly once; the dotfiles repo carries only an ~80-byte link recording *where* it should land. Editing the canonical file is enough — no copy needs re-syncing.

## Menu Layout

Sections are numbered; each entry is reached by `<section><key>` — `41`, `1a`, `7c`.

| | Section | Notable entries |
|---|---|---|
| 1 | Boot Management | checks, backups, GRUB/Timeshift inspection |
| 2 | Update Management | pre-upgrade checks, package analysis, full workflow |
| 3 | Package Timeline | full / recent / searchable install history |
| 4 | Services, Timers & Scripts | **41** dashboard, **42** manage personal units, **43** timers + cron, **44** local scripts, **45** install personal units |
| 5 | Cloud Sync Management | rclone profiles, logs |
| 6 | Network Discovery & Diagnostics | **61** network auditor, **62** nmcli toolset |
| 7 | BPF Tools | readiness, setup, traces |

Each section may declare its own `"icon"` in `menu.json`; the orchestrator falls
back to a built-in per-number default only when it does not.

### Section 4 entries and the views behind them

Section 4 is a merge of what used to be two sections — *Services & Scripts* and
*Personal Services & Timers* — because both answered the same question and most
of their twelve entries were a single `systemctl` listing each. Nothing was
dropped: every view still exists, and every one is still addressable directly.

| Menu entry | Runs | Composed of |
|---|---|---|
| **41** Services Dashboard | `services_scripts.sh --dashboard` | system counts · `--failed` · `--active-personal` · `--failed-personal`, then a drill-down offering `--active`, `--enabled`, `--recent-changes` |
| **42** Manage Personal Services | `--manage-personal` | unchanged |
| **43** Scheduled Tasks | `--scheduled` | `--timers` · `--cron` |
| **44** User Scripts & Tools | `--user-scripts` | unchanged |
| **45** Personal Service Units | `install_services.sh --interactive` | surveys unprivileged, then installs only what you pick |

The individual flags are not deprecated — they are the units the composites are
built from, and remain the right thing to call from a script or a shell:

```bash
distros/arch/services_scripts.sh --failed-personal
```

The dashboard's drill-down prompt is skipped when stdin is not a terminal, so
`--dashboard` stays usable in a pipeline.

### Section 62 — the nmcli toolset

`nmcli_toolset.sh` is an index of network-diagnostic commands, grouped into eight
categories (interfaces, profiles, IP configuration, Wi-Fi, DNS, connectivity and
routing, firewall and ports, NetworkManager service).

**Every action prints the exact command before running it.** That is the point of
the section: the output is available from a dozen other places, but the
invocation is the part worth learning, and printing it means the next run does
not need the menu. The string shown is the string executed — a command taking a
device, profile, or host resolves its argument *before* display, so what appears
is never a template.

Actions are read-only diagnostics unless labelled `[modifies system]`. Anything
needing root carries a visible `sudo` rather than escalating silently.

The menu adapts to the machine: firewall backends are listed only if present
(`nft`, `iptables`, `ufw`, `firewall-cmd`), and path tracing picks whichever of
`mtr`, `traceroute` or `tracepath` exists, saying so plainly when none do.

## Extending to New Distros
Refer to the project maintainer guide at [SKILL.md](SKILL.md) for step-by-step instructions on adding support for new Linux distributions and modifying capabilities.

## License
Licensed under the MIT License. See [LICENSE](LICENSE) for details.
