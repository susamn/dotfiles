---
name: skill-manifestor
id: skill-manifestor
description: Manifest a new hierarchy of modular skills following the Late-Binding Hierarchical Skill Framework.
version: 1.0.0
triggers:
  - "manifest a new skill hierarchy"
  - "create skills for [problem]"
  - "use skill-manifestor"
intent: meta-skill
type: action
parent: null
mode_aware: true
---

# Skill Manifestor: Late-Binding Hierarchical Skill Framework

This skill is the architect for the Late-Binding Hierarchical Skill Framework. It is used to design and manifest new skill hierarchies from a root parent level down to implementation-specific children.

## [LIBRARY_MODE]
**Trigger:** "Manifest a new skill hierarchy" or "Create skills for [Problem]."

When triggered, the Agent acts as an **Architectural Blueprint** to construct a new ecosystem of modular skills.

### 1. Discovery Phase
The Agent MUST ask the following questions before generating any files:
1. "What is the core domain or problem this hierarchy addresses?"
2. "What is the designated **namespace** for this skill group? (e.g., 'webapp', 'cloud', 'cli')"
3. "Can you provide a brief description of the project/namespace goals?" (Used to auto-identify child modules like `[namespace]-testing`, `[namespace]-store`, etc.)
4. "Review the suggested logical layers: [List inferred children based on description]. Do you want to add or remove any?"

### 2. Namespace & Naming Protocol
- **Folder Pattern:** Every skill MUST have its own directory named `[skill-id]` inside the flat `skills/` root.
- **File Pattern:** The core logic MUST be in a file named `SKILL.md` within that directory (e.g., `skills/[skill-id]/SKILL.md`).
- **Root Parent ID:** MUST be named `[namespace]-parent`.
- **Children IDs:** MUST follow the pattern `[namespace]-[category]` or `[namespace]-[category]-[sub-category]` for deeper specialization.

### 3. Metadata Injection
Every generated skill MUST include the following YAML frontmatter in its `SKILL.md`:
```yaml
name: [skill-id]
id: [skill-id]
version: 1.0.0
type: [context | action | validation]
parent: [upstream-id or null]
mode_aware: true
```

### 4. Logic Scaffolding (Implementation)
Each `SKILL.md` MUST contain two distinct sections: `## [TOOL_MODE]` and `## [LIBRARY_MODE]`.

### 5. Physical Manifestation (Delegation)
Once the hierarchy design is finalized, the Agent MUST use **skill:skill-creator** to handle:
- Directory creation (`mkdir -p skills/[skill-id]`).
- `SKILL.md` file generation with the finalized content.
- Deployment via `./do-stow.sh` to make the skills available across all agents.

#### A. The Root Parent (`[namespace]-parent`)
This `SKILL.md` MUST contain the **Global Laws** for the domain, including:

1. **Modular Mandate:** The project must remain strictly modular. Logic must be encapsulated within designated module directories.
2. **Standard Documentation (Per Module):**
   - `CONTEXT.md`: Explicitly defines the module's primary responsibility and scope.
   - `TODO.md`: A live task list. Items must be ticked off only upon completion and verification.
3. **Global Coordination Files:**
   - `ARCHITECTURE.md`: Contains the project architecture, requirements, and high-level design.
   - `DEPENDENCY.md`: Clearly defines inter-module dependencies. **Rule:** This file must be symlinked into every child module to ensure local context of the larger system.
4. **Verification & Safety:**
   - **Test-Always Rule:** Run tests after every change.
   - **Test-Preservation:** NEVER delete test cases without explicit notification and justification.
5. **Execution Strategy:**
   - **Atomic Changes:** Work on one small item from the `TODO.md` at a time.
   - **Minimal PRs:** Never pack too many unrelated changes into a single PR/Commit.
6. **The "Contract First" Rule:** Interface/API definitions must precede implementation.
7. **Agentic Call Stack Constraints:**
  - **Lookup Depth Limit:** 3 parent-lookups maximum.
  - **Namespace Isolation:** Purge skill context after the task is finished.
  - **The "Halt" Rule:** If a referenced skill is missing, STOP and ask.

8. **Web Domain Mandate (OpenAPI):**
   - For any web-based project, an **OpenAPI Schema** MUST be used as the source of truth to bind backend and frontend.
   - The schema acts as the "Contract" allowing transport and client layers to be developed and tested independently.

#### B. Specialized & Nested Children
These `SKILL.md` files focus on specific layers (e.g., `webapp-testing`) or sub-specializations (e.g., `webapp-testing-bdd`):
- **Upward Reference:** Link to the immediate parent via `parent:` metadata and `skill:[parent-id]` in text for global laws.
- **Inheritance Chain:** A sub-category child (e.g., `webapp-testing-bdd`) MUST refer to its category parent (`webapp-testing`), which in turn refers to the root parent (`webapp-parent`).
- **Mode-Specific Logic:** Tool mode for auditing/linting that specific layer; Library mode for blueprinting/generating code for that layer.

#### C. The Vulnerability Child (`[namespace]-vulnerability`)
If applicable to the domain, this skill MUST be included to handle security integrity:
- **Tool Mode:** Provide heuristics and automated checks for domain-specific vulnerabilities (e.g., SQLi for `webapp`, IAM misconfigurations for `cloud`, buffer overflows for `system`).
- **Library Mode:** Provide "Security by Design" templates and guardrails to be injected into new modules.

---

## [TOOL_MODE]
**Trigger:** "Audit the [namespace] skills" or "Validate [Project] against skill framework."

### 1. Skill Library Audit
When triggered for skills, the Agent acts as a **Recursive Auditor** for the skill library itself:
1. **Physical Audit:** Verify all skills follow the `skills/[skill-id]/SKILL.md` pattern.
2. **Metadata Validation:** Ensure every `SKILL.md` has a valid YAML header with correct parent pointers.
3. **Logic Separation:** Confirm the presence of both `[TOOL_MODE]` and `[LIBRARY_MODE]` blocks.
4. **Resolution Check:** Verify that `skill:<name>` references correctly point to existing `SKILL.md` files.

### 2. Project Adherence Audit
When triggered for a codebase, the Agent enforces the **Global Laws** defined in the hierarchy:
1. **Modular Consistency:** Scan for logic leaked outside of designated module folders.
2. **Documentation Check:** Flag any module missing `CONTEXT.md` or `TODO.md`.
3. **Coordination Scan:** Verify presence of `ARCHITECTURE.md` and `DEPENDENCY.md` (and check for symlinking in modules).
4. **Execution Audit:** Check recent commits/PRs for "Atomic Change" adherence. If a PR contains changes across unrelated modules or too many TODO items, flag as a "Framework Violation."
5. **Contract Verification:** For web domains, ensure an `OpenAPI` schema exists and is being utilized as the source of truth.
6. **Halt Enforcement:** If a project-level audit requires a missing specialized skill (e.g., `skill:webapp-vulnerability`), STOP and request it.

---

## Late-Binding Resolution Protocol (`skill:<name>`)
To resolve a logic gap, the Agent MUST:
1. Identify the `skill:` prefix.
2. Use the `read_file` tool to fetch `skills/[name]/SKILL.md`.
3. Merge the relevant `[MODE]` block into the current reasoning context.
4. Apply **Precedence:** Specific-Over-General (Child > Parent) and Latest-Over-Legacy.
