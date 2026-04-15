# Dotfiles — Agent Guide

This is a stow-managed dotfiles repository. When you are operating in this directory, use this guide to understand the structure and to manage skills correctly.

---

## Repository layout

```
dotfiles/
├── .config/          # app configs (Hyprland, kitty, nvim, waybar, rofi, …)
├── workspace/        # shell scripts, tools, sdk, services
│   ├── scripts/      # standalone shell/python scripts
│   ├── tools/        # larger project-style tools
│   ├── .variables.sh # exports $SCRIPTS_PATH, $TOOLS_PATH, $SERVICES_PATH, etc.
│   └── .aliases.sh   # shell aliases (sourced at shell init)
├── skills/           # canonical AI skill definitions (NOT stowed to ~)
│   ├── .agents       # which agents receive skills and at what path
│   └── <skill-name>/
│       └── SKILL.md  # skill definition (YAML frontmatter + markdown body)
├── do-stow.sh        # stow dotfiles + deploy skill symlinks + instruction symlinks
├── do-unstow.sh      # remove all of the above + unstow dotfiles
└── AGENTS.md         # this file — read by agents working inside this repo
```

**Important:** `skills/` is explicitly excluded from stow. It is deployed separately by `do-stow.sh` as symlinks into each configured agent's skill directory.

---

## Path variables (available in every shell)

These are exported by `.bootstrap.sh` → `workspace/.variables.sh` on every shell start:

| Variable | Resolves to |
|---|---|
| `$WORKSPACE_PATH` | `~/workspace` |
| `$SCRIPTS_PATH` | `~/workspace/scripts` |
| `$TOOLS_PATH` | `~/workspace/tools` |
| `$SERVICES_PATH` | `~/workspace/services` |
| `$INSTALL_PATH` | `~/workspace/install` |
| `$SDK_PATH` | `~/workspace/sdk` |

**Always use these variables** when referencing scripts or tools in a SKILL.md — never hardcode paths.

---

## Stow workflow

```bash
# Full setup on a new machine (from the dotfiles dir):
./do-stow.sh

# Teardown:
./do-unstow.sh

# Manual stow — .stow-local-ignore handles all exclusions automatically:
stow -vt ~ .
stow -Dvt ~ .    # unstow

# To resolve conflicts:
stow -vt ~ . --adopt
```

`.stow-local-ignore` excludes: `skills/`, agent guide files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.cursor/`), and stow scripts (`do-stow.sh`, `do-unstow.sh`) from being deployed to `~/`. These files serve their purpose within the repo only.

---

## Skill system

### How skills are deployed

`skills/.agents` lists the target path for each agent:

```
claude   ~/.claude/skills
# codex    ~/.codex/skills
```

`do-stow.sh` reads this file and creates:
```
~/<agent_skills_dir>/<skill_name>  →  <dotfiles>/skills/<skill_name>/
```

Each symlink points to the canonical skill folder in this repo. Adding a new agent: uncomment/add a line in `.agents`, then run `./do-stow.sh`.

### Manually link a single skill (without running do-stow.sh)

```bash
DOTFILES="$(git -C . rev-parse --show-toplevel)"
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  target_path="$(awk '{print $2}' <<< "$line")"
  target_path="${target_path/#\~/$HOME}"
  mkdir -p "$target_path"
  ln -sfn "$DOTFILES/skills/<skill-name>" "$target_path/<skill-name>"
done < "$DOTFILES/skills/.agents"
```

---

## SKILL.md schema

Every skill is a directory with a `SKILL.md` file:

```markdown
---
name: skill-name                   # kebab-case, matches directory name
description: one-line summary      # used by agents to decide relevance
version: 1.0.0                     # semver
triggers:                          # natural-language phrases that activate this skill
  - "phrase that should trigger this"
intent: category                   # code-review | refactor | media | git | system | debug | …
guardrails:                        # safety/scope constraints the agent must enforce
  - Do not X
  - Always confirm before Y
resources:                         # scripts/tools this skill depends on, using path variables
  - $SCRIPTS_PATH/some-script.sh
  - $TOOLS_PATH/some-tool/quick-start.sh
tools:                             # CLI tools required
  - bash
  - gh
interface:
  input:
    param_name: "type — description"
    optional_param: "type? — description (? = optional)"
  output:
    output_name: "type — description"
---

## Markdown body

Human- and agent-readable instructions. Include:
- What this skill does (1–2 sentences)
- Step-by-step execution guide using $SCRIPTS_PATH / $TOOLS_PATH variables
- Any dependency or environment requirements
- Expected output format
```

**Rules:**
- Keep skills small and focused. One skill = one workflow.
- Never put large prompt blobs in SKILL.md. The body should be instructions, not a prompt.
- Use `$SCRIPTS_PATH`, `$TOOLS_PATH`, etc. — never hardcode paths.
- Do not create new scripts. Reference existing ones from `workspace/scripts/` or `workspace/tools/`.
- Do not create a `resources/` subdirectory. Scripts are already accessible via the path variables.

---

## How to create a new skill from an existing tool/script/alias

### 1. Identify the source

Check in order:
- `workspace/scripts/` — standalone shell/python scripts
- `workspace/tools/<name>/` — larger tools (look for `quick-start.sh` as the entry point)
- `workspace/.aliases.sh` — aliases that wrap a script or tool

Read the script header and `--help` output to understand its interface.

### 2. Create the skill directory

```bash
mkdir -p skills/<name>
```

### 3. Write SKILL.md

Use the schema above. Set:
- `resources:` — list the script path using `$SCRIPTS_PATH` or `$TOOLS_PATH`
- `triggers:` — what a user would naturally say to invoke this
- `intent:` — semantic category
- `guardrails:` — what the agent must never do
- `interface.input` / `interface.output` — derived from the script's arguments and output

In the markdown body, show execution like:
```bash
bash "$SCRIPTS_PATH/script-name.sh" [flags]
# or for tools:
bash "$TOOLS_PATH/tool-name/quick-start.sh" [flags]
```

### 4. Deploy the symlink for each agent

```bash
# Option A: re-run do-stow.sh (deploys all skills)
./do-stow.sh

# Option B: deploy just the new skill manually
DOTFILES="$(git -C . rev-parse --show-toplevel)"
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  target_path="$(awk '{print $2}' <<< "$line")"
  target_path="${target_path/#\~/$HOME}"
  mkdir -p "$target_path"
  ln -sfn "$DOTFILES/skills/<name>" "$target_path/<name>"
done < "$DOTFILES/skills/.agents"
```

### 5. Commit

```bash
git add skills/<name>/
git add skills/.agents   # only if .agents changed
git commit -m "skills: add <name> skill"
```

---

## How to add a new agent

1. Edit `skills/.agents` — add: `<agent>   <~/.agent/skills/path>`
2. Run `./do-stow.sh` to deploy existing skills to the new agent
3. Commit `skills/.agents`

---

## Existing tools worth converting to skills

These scripts in `workspace/scripts/` are strong candidates:

| Script | Alias | Suggested skill name | Intent |
|---|---|---|---|
| `pr-review-gen.sh` | `grev` | `pr-review` ✅ (done) | code-review |
| `git-stash-manager.sh` | `gsh` | `git-stash` | git |
| `arch-system-manager.sh` | `asm` | `arch-maintenance` | system |
| `ssl-debugger.sh` | — | `ssl-debug` | debug |
| `jwtd.sh` | `jwtd` | `jwt-decode` | debug |
| `video-merger.sh` / `ytd.sh` | `ytd` | `media` | media |
| `generate-ssh-keys.sh` | `gsk` | `ssh-keygen` | system |

Tools in `workspace/tools/`:

| Entry point | Alias | Suggested skill name | Intent |
|---|---|---|---|
| `media-trimmer/quick-start.sh` | `mt` | `media-trim` | media |
| `api-testing-tool/quick-start.sh` | `att` | `api-test` | debug |
| `performance-manager/quick-start.sh` | `pfm` | `perf-monitor` | system |

---

## What NOT to put in a skill

- Entire prompt templates (keep them in a separate file if needed, referenced via `$SCRIPTS_PATH`)
- Hardcoded absolute paths
- Secrets or credentials
- Logic that belongs in the script itself
- New scripts — use what already exists in `workspace/`

---

## Adding a new agent

1. Edit `skills/.agents` — add a line with all three columns:

```
# agent    skills_path          instruction_symlink
gemini     ~/.gemini/skills     ~/.gemini/GEMINI.md
codex      ~/.codex/skills      ~/AGENTS.md
cursor     ~/.cursor/rules      -
```

   - `skills_path` — where skill symlinks are deployed (`~` is expanded to `$HOME`)
   - `instruction_symlink` — **absolute path** where the agent reads its global
     instruction file. `do-stow.sh` creates a symlink there pointing back to
     `AGENTS.md` in this repo. Use `-` if the agent has no global instruction
     file (e.g. Cursor, which reads `.cursor/rules/` per-project only).

2. Run `./do-stow.sh` — it creates the skill symlinks and the instruction symlink.

3. Commit only `skills/.agents`.

**Where instruction symlinks are created (outside this repo):**

| Agent | Instruction file | Scope |
|---|---|---|
| Claude Code | `~/.claude/CLAUDE.md` | read from any working directory |
| Codex | `~/AGENTS.md` | read by walking up from CWD |
| Gemini CLI | `~/.gemini/GEMINI.md` | read from any working directory |
| Cursor | — | per-project only (`.cursor/rules/`) |
