# Agent Context

This file gives you context about the user's environment and available tooling.
It is managed by the user's dotfiles repo — you do not need to be inside that repo
to use the skills and scripts described here.

---

## Environment variables

These are exported in every shell session and must be used when referencing scripts
or tools — never hardcode absolute paths.

| Variable | Path |
|---|---|
| `$WORKSPACE_PATH` | `~/workspace` |
| `$SCRIPTS_PATH` | `~/workspace/scripts` |
| `$TOOLS_PATH` | `~/workspace/tools` |
| `$SERVICES_PATH` | `~/workspace/services` |
| `$INSTALL_PATH` | `~/workspace/install` |
| `$SDK_PATH` | `~/workspace/sdk` |

---

## Available skills

Skills are loaded from your agent's skills directory. Each skill wraps an existing
script or tool. Invoke them when the user's request matches a trigger phrase.

| Skill | Intent | Trigger examples |
|---|---|---|
| `pr-review` | code-review | "review this PR", "generate PR review prompt" |
| `webapp-dev` | architecture | "start a new webapp", "design a modular application" |
| `safe-coder` | execution | "implement feature", "work on module", "safe-coder" |
| `openapi-schema-creator` | api-design | "create an OpenAPI schema", "design an API" |

More skills will appear here as they are added to the dotfiles.

---

## Available scripts

Located at `$SCRIPTS_PATH`. Invoke with `bash "$SCRIPTS_PATH/<script>"`.

| Script | Alias | What it does |
|---|---|---|
| `pr-review-gen.sh` | `grev` | Generate a structured LLM-ready PR review prompt from a GitHub PR |
| `git-stash-manager.sh` | `gsh` | Interactive git stash manager |
| `git-hard-reset.sh` | `ghr` | Hard reset current branch with safety prompts |
| `gch.sh` | `gch` | Interactive git checkout across branches |
| `gitb.sh` | `gitb` | Git branch utilities |
| `arch-system-manager.sh` | `asm` | Arch Linux system manager (update, boot safety, timeline) |
| `ssl-debugger.sh` | — | Debug SSL/TLS certificates |
| `jwtd.sh` | `jwtd` | Decode and inspect JWT tokens |
| `generate-ssh-keys.sh` | `gsk` | Generate SSH key pairs |
| `ytd.sh` | `ytd` | Download YouTube videos/audio via yt-dlp |
| `video-merger.sh` | — | Merge video files |
| `als.sh` | `als` | Search/browse shell aliases interactively |
| `ffo.sh` | `ff` | Fuzzy file finder (fd + fzf) |
| `uff.sh` | `uff` | Fuzzy file finder with preview |
| `pkg-listing.sh` | `pkgs` | List installed packages |
| `cht.sh` | `cht` | Cheatsheet lookup |

## Available tools

Located at `$TOOLS_PATH`. Each tool has a `quick-start.sh` entry point.

| Tool | Alias | What it does |
|---|---|---|
| `media-trimmer/` | `mt` | Web UI for trimming audio/video files |
| `api-testing-tool/` | `att` | API testing tool |
| `performance-manager/` | `pfm` | System performance monitor |
| `helpful-tools-v2/` | `ht2` | Collection of helpful utilities |
| `file-explorer/` | — | Remote file explorer (SFTP) |

---

---

## Dotfiles management

> **Only relevant when you are explicitly helping the user manage their dotfiles**
> (i.e. the user has asked you to add a skill, modify the stow setup, or work inside
> `~/dotfiles/`). If you are helping with any other task, ignore this section.

### Repository layout

```
~/dotfiles/
├── .config/          # app configs (Hyprland, kitty, nvim, waybar, rofi, …)
├── workspace/        # scripts, tools, sdk, services (stowed to ~/workspace/)
├── skills/           # canonical skill definitions — NOT stowed to ~
│   ├── .agents       # agent deployment config (skills path + instruction file)
│   └── <skill-name>/
│       └── SKILL.md
├── do-stow.sh        # stow dotfiles + deploy skill and instruction symlinks
├── do-unstow.sh      # reverse of do-stow.sh
└── AGENTS.md         # this file
```

`skills/` is excluded from stow. `do-stow.sh` deploys skill symlinks to each
agent's skills directory and creates instruction file symlinks (e.g.
`~/.claude/CLAUDE.md`) outside the repo.

### Stow commands

```bash
./do-stow.sh          # full setup
./do-unstow.sh        # full teardown
stow -vt ~ .          # manual stow (.stow-local-ignore handles exclusions)
stow -Dvt ~ .         # manual unstow
stow -vt ~ . --adopt  # resolve conflicts
```

### SKILL.md schema

```yaml
---
name: skill-name
description: one-line summary
version: 1.0.0
triggers:
  - "natural language phrase"
intent: code-review | git | system | debug | media | …
guardrails:
  - Do not X
resources:
  - $SCRIPTS_PATH/script-name.sh
tools:
  - bash
interface:
  input:
    param: "type — description"
  output:
    result: "type — description"
---
Markdown body: step-by-step instructions for the agent.
```

### How to create a skill from an existing script

Skills in this repo are **cross-agent compatible**. When you create a skill here and run `./do-stow.sh`, it is automatically deployed to all agents listed in `skills/.agents` (e.g., Gemini, Claude, Cursor).

1. `mkdir -p skills/<name>`
2. Write `skills/<name>/SKILL.md` — reference the script as `$SCRIPTS_PATH/<script>.sh`
3. Deploy: `./do-stow.sh`
   - This script reads `skills/.agents` and creates symlinks for all skills in every agent's rules directory.
4. `git add skills/<name>/ && git commit -m "skills: add <name>"`

Do not create new scripts inside skill directories. Always reference existing scripts via `$SCRIPTS_PATH` or `$TOOLS_PATH` to maintain a single source of truth.

### Adding a new agent

Edit `skills/.agents` (three columns: name, skills path, instruction file path):

```
gemini   ~/.gemini/skills   ~/.gemini/GEMINI.md
cursor   ~/.cursor/rules    -
```

Then run `./do-stow.sh` and commit `skills/.agents`.
