---
name: skill-creator
description: Guide for creating effective skills that extend different agents' capabilities. Use when creating new skills or updating existing skills with specialized knowledge, workflows, or tool integrations.
---

# Skill Creator

Guide for creating effective skills that extend different agents' capabilities.

## About Skills

Skills are modular, self-contained packages that extend different agents' capabilities by providing specialized knowledge, workflows, and tools. Think of them as "onboarding guides" for specific domains.

### What Skills Provide

1. **Specialized workflows** - Multi-step procedures for specific domains
2. **Tool integrations** - Instructions for working with specific file formats or APIs
3. **Domain expertise** - Company-specific knowledge, schemas, business logic
4. **Bundled resources** - Scripts, references, and assets for complex tasks

## Core Principles

### Concise is Key

The context window is a public good. Only add context the agent doesn't already have.

**Default assumption: Agents is already very smart.** Challenge each piece of information: "Does the agent really need this explanation?"

Prefer concise examples over verbose explanations.

### Anatomy of a Skill

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description)
│   └── Markdown instructions
└── Bundled Resources (optional)
    ├── scripts/      - Skill-specific scripts (preferred)
    ├── references/   - Documentation
    └── assets/       - Templates, images
```

## SKILL.md Components

### Frontmatter (YAML)

```yaml
---
name: skill-name
description: What the skill does. Use when [activation trigger].
version: 1.0.0
triggers:
  - "natural language phrase that activates this skill"
intent: code-review | git | system | debug | media | ...
guardrails:
  - Do not X
resources:
  - ./scripts/script-name.sh  # Relative to skill directory
  - $TOOLS_PATH/tool-name     # For global tools
tools:
  - bash
---
```

The `description` is the primary triggering mechanism. Store skill-specific logic in `./scripts/` within the skill folder. Only use `$SCRIPTS_PATH` for truly global, shared utilities. This minimizes the "security blast radius" and makes skills portable.

### Body (Markdown)

Instructions and guidance. Use `<SKILL_PATH>` as a placeholder if you need to reference the absolute path to the skill's directory during execution.

## Bundled Resources

### Scripts (`./scripts/`)

Executable code for tasks requiring deterministic reliability. Store these inside the skill directory for better security and portability.

### References (`references/`)

Documentation loaded as needed into context.

### Assets (`assets/`)

Files used in output (templates, images, fonts).

## Progressive Disclosure

Skills use three-level loading:

1. **Metadata** - Always in context (~100 words)
2. **SKILL.md body** - When skill triggers (<5k words)
3. **Bundled resources** - As needed

Keep SKILL.md under 500 lines. Split content when approaching this limit.

## Skill Creation Process

1. **Understand** - Gather concrete usage examples
2. **Plan** - Identify reusable scripts, references, assets
3. **Initialize** - `mkdir -p ~/dotfiles/skills/<name>`
4. **Edit** - Write `~/dotfiles/skills/<name>/SKILL.md` referencing scripts via `$SCRIPTS_PATH` or `$TOOLS_PATH`.
5. **Register** - Add the new skill to the `## Available skills` table in `~/dotfiles/templates/AGENTS.md.template`.
6. **Deploy** - Run `bash ~/dotfiles/do-stow.sh` — this generates agent-specific instruction files from the template and symlinks the skill into every agent's skills directory.
7. **Commit** - `git add skills/<name>/ templates/AGENTS.md.template && git commit -m "skills: add <name>"`
8. **Iterate** - Improve based on real usage

## What NOT to Include

- README.md
- INSTALLATION_GUIDE.md
- CHANGELOG.md
- User-facing documentation

Skills are for AI agents, not humans. Only include what the agent needs to do the job.