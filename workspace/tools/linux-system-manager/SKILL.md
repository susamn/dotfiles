---
name: linux-system-manager-maintainer
description: Maintain, enhance, and extend the system-agnostic linux-system-manager toolset. Use this skill when adding new features, modifying distro menus, replicating functionality across all distros, managing systemd services, or running tests.
version: 1.1.0
triggers:
  - "how to add a new feature to linux-system-manager"
  - "add distro-agnostic capability"
  - "replicate functionality to all distros"
  - "manage linux-system-manager project"
intent: system
config_dir: ./config
created_at: 2026-07-06
updated_at: 2026-07-06
---

# Linux-System-Manager Project Maintainer & Developer Guide

This local skill governs the design, maintenance, and expansion of the `linux-system-manager` project.

---

## 1. Project Philosophy & Core Architecture

The `linux-system-manager` toolset is a **stateless, configuration-driven system management pipeline**. It is designed around complete isolation between presentation and implementation:

- **Parent Orchestrator (`linux-system-manager.sh`):** Distro-blind. Handles terminal clearance, interactive menus, OS detection (`/etc/os-release`), dynamic JSON menu parsing, and process execution context.
- **Distribution Modules (`distros/<distro_id>/`):** Self-contained. Declare their capabilities in `menu.json` and implement execution logic in distro-native scripts/binaries.
- **Privilege Boundary:** The parent orchestrator and main menu run as a regular user. Distro-specific scripts must call `sudo` internally if they perform privileged actions (like checking systemd configs or writing backups).

---

## 2. Directory Layout Reference

```
linux-system-manager/
├── linux-system-manager.sh      # Main menu runner (distro-agnostic)
├── install.py                   # Service and hooks installer (distro-agnostic)
├── test_sys_manager.py          # Unit test suite
├── SKILL.md                     # Local maintainer & developer guide
├── services/                    # System-scope units → /etc/systemd/system
│   ├── sys-manager-cleanup.service
│   ├── personal-services.target #   WantedBy=multi-user.target
│   └── user/                    # User-scope units → ~/.config/systemd/user
│       └── personal-services.target  # WantedBy=default.target
├── distros/                     # Distro-specific logic folders
│   ├── arch/
│   │   ├── menu.json            # Capabilities menu mapping
│   │   ├── install_hooks.sh     # Hooks copy script
│   │   └── *.sh                 # Inspection & management scripts
│   └── <new-distro>/
│       ├── menu.json
│       ├── install_hooks.sh
│       └── ...
└── SKILL.md                     # This maintainer guide
```

---

## 3. Workflow: Replicating a New Feature Across All Distros

To add a new option or section (e.g., "Disk Space Analyzer" or "Logs Monitor") and make it available across all supported distributions, use this sequence:

### Step 1: Scan for Available Distributions
Run a command or inspect the file system to list directories in `distros/`:
```bash
ls -d distros/*/ | grep -v "common/"
```

### Step 2: Update `menu.json` in Each Distro Directory
Under each directory found (e.g. `distros/arch/`, `distros/debian/`), edit `menu.json` to insert the new option under the correct section.
- **Example:**
```json
{
  "key": "8",
  "label": "Disk Space Analysis",
  "exec": "analyze_disk.sh"
}
```

### Step 3: Implement the Distro-Specific Execution Scripts
Write the script for each distro.
- In `distros/arch/analyze_disk.sh`, you might use `pacman` cache size analysis combined with standard `df` commands.
- In `distros/debian/analyze_disk.sh`, you might use `apt` clean/cache checks.
*Ensure all scripts are made executable:*
```bash
chmod +x distros/*/analyze_disk.sh
```

## 4. Workflow: Adding & Managing Custom (Personal) Systemd Services

To deploy and manage custom background utility services (e.g., a backup cleanup timer or sync daemon) and segregate them from standard system services:

1. **Pick the scope first, then the directory**:
   - `services/` — **system scope**. Installed to `/etc/systemd/system/`, grouped by the system manager's `personal-services.target` (`WantedBy=multi-user.target`). Use for units that must run without anyone logged in.
   - `services/user/` — **user scope**. Installed to `~/.config/systemd/user/`, grouped by the user manager's `personal-services.target` (`WantedBy=default.target`). Use for anything needing `$HOME`, a login session, a per-user rclone config, or the session D-Bus.

   > [!IMPORTANT]
   > The two `personal-services.target` files share a unit name but are **not** duplicates — systemd's system and user managers share no namespace. `multi-user.target` does not exist in the user manager, so a user unit declaring `WantedBy=multi-user.target` does not error: `systemctl --user enable` accepts it and the unit then **silently never activates**. Never resolve the "duplication" by deleting one.

2. **Installation**: Run `install.py` (which escalates via `sudo` automatically). It copies `services/*.{service,timer,target}` to `/etc/systemd/system/`, then copies `services/user/*.{service,timer,target}` to the *invoking* user's `~/.config/systemd/user/` (chowned back to them, reloaded via `sudo -u <user>` with `XDG_RUNTIME_DIR` set — never as root, whose user manager is a different instance). A destination that is already a symlink resolving to the repo source is left alone, so an external deployer (stow) keeps ownership.
3. **Menu Segregation**:
   - Standard system services are monitored and inspected under **Section 4 (Services & Scripts)**.
   - Local/personal services from this repository are segregated and monitored under **Section 5 (Personal Services & Timers)**.
   - Distro-specific logic (e.g. `services_scripts.sh`) detects these services by querying `personal-services.target` in **both** managers and scanning both source directories, then checks status, failures, and toggle state via `systemctl`.
   - **Every unit carries its scope.** `collect_personal_units` emits `"<scope><TAB><unit>"` records, and all downstream calls route through `lsm_systemctl <scope> …` / `lsm_systemctl_admin <scope> …`. Adding a new `systemctl` call in a personal-services code path without that wrapper is a bug — `test_regressions.py` fails the build on it.
   - `lsm_systemctl_admin` uses `sudo` for system scope and **plain `systemctl --user`** for user scope. `sudo systemctl --user` addresses *root's* user manager, so the unit would be enabled for the wrong account while appearing to succeed.
4. **Template Units Support (e.g., `rclone-sync@.service`, `rclone-mount@.service`)**:
   - Systemd templates in `services/` require instance names (e.g. `rclone-mount@obsidian-mount.service`) to run.
   - **Crucial Rule:** In template unit files, always use the raw `%i` (lowercase) specifier in `ExecStart` and descriptions instead of `%I` (uppercase). Systemd path-unescapes `%I`, translating dashes (`-`) to slashes (`/`), which will break configuration file resolution if profile names contain dashes.
   - When managing templates under Section 5 (`services_scripts.sh`), the script automatically queries systemd for active or configured instances of that template (using `systemctl list-units` and `systemctl list-unit-files`) and lets the user choose which instance to manage.

---

## 5. Workflow: Hook Registration & Package Triggers

When package operations occur, native hook systems should notify our scripts:
- **Arch Linux:** `install_hooks.sh` copies hooks under `distros/arch/hooks/` to `/etc/pacman.d/hooks/`.
- **Debian/Ubuntu (APT):** Create `distros/debian/hooks/` and write an APT configuration trigger file (e.g., `99sysmanager`) to be copied to `/etc/apt/apt.conf.d/` by `install_hooks.sh`.
- **Fedora/RHEL (DNF):** Write a DNF plugin or trigger command inside the Fedora hooks section.

---

## 6. Testing & Quality Gate

Every change to the orchestrator or installer script **MUST** be verified by running the unit test suite:
```bash
python3 test_sys_manager.py
```

### Writing New Tests
If you modify `linux-system-manager.sh` or `install.py`:
1. Open `test_sys_manager.py`.
2. Add a new test method to `TestSysManager` or `TestInstaller` utilizing standard `unittest.mock` mockings.
3. Confirm all tests pass locally and in the GitHub Actions runner environment.

> [!NOTE]
> Because `linux-system-manager.sh` uses a `.sh` file extension to look like standard shell utilities but contains Python code, standard Python `import` statements or `importlib` specs will fail. You must load and compile the source dynamically in test setups:
> ```python
> import types
> sys_manager = types.ModuleType("sys_manager")
> sys_manager.__file__ = "linux-system-manager.sh"
> with open(sys_manager.__file__, 'r') as f:
>     source_code = f.read()
> code_obj = compile(source_code, sys_manager.__file__, 'exec')
> exec(code_obj, sys_manager.__dict__)
> ```

---

## 7. Standalone Commit & Submodule Workflow

The `linux-system-manager` repository is a standalone Git repository embedded inside a parent configuration/dotfiles repository. To maintain history cleanly:

### Commit Format
Follow the **Conventional Commits** standard (without any AI branding or credit signatures). Keep commits small, logical, and focused:
- `feat`: Adding new scripts, features, or installer functionality (e.g. `feat: add Arch Linux boot check scripts`).
- `feat(services)`: Changes scoped to personal/system services.
- `chore`: Renaming files, updating `.gitignore` or metadata configurations.
- `test`: Adding or updating test cases.
- `docs`: Updating `README.md` or `SKILL.md`.

### Propagating Submodule Commits
When committing updates:
1. **Commit locally in `linux-system-manager/`**:
   ```bash
   cd linux-system-manager/
   git add <modified-files>
   git commit -m "feat/chore/test: description"
   ```
2. **Commit the gitlink pointer in the parent repository**:
   ```bash
   cd ..
   git add linux-system-manager
   git commit -m "chore(sys-manager): update submodule reference"
   ```

---

## 8. Developer Guardrails
- **Zero Third-Party Packages:** Never import packages outside the Python standard library in `linux-system-manager.sh`, `install.py`, or `test_sys_manager.py`.
- **Stateless Operation:** Never write user settings or operation logs inside the project source tree. Use `~/.local/state/` or `/var/log/` for distro logs.
- **Fail Gracefully:** Never allow python `subprocess` exceptions to crash the main menu loop. Always catch execution failures and log them to standard error.
- **Self-Escalation Pattern**: Any distro-specific script requiring root must self-escalate on launch:
  ```bash
  if [[ $EUID -ne 0 ]]; then
      echo "This script requires root privileges. Re-running with sudo..."
      exec sudo "$0" "$@"
  fi
  ```
