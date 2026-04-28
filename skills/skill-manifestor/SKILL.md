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
2. "What are the logical layers required? (e.g., Foundation, Architecture, Security, Testing, or specific implementation modules)"
3. "What is the designated **namespace** for this skill group? (e.g., 'code', 'cloud', 'frontend')"

### 2. Namespace & Naming Protocol
- **Folder Pattern:** Every skill MUST have its own directory named `[skill-id]` inside the flat `skills/` root.
- **File Pattern:** The core logic MUST be in a file named `SKILL.md` within that directory (e.g., `skills/[skill-id]/SKILL.md`).
- **Root Parent ID:** MUST be named `[namespace]-parent`.
- **Children IDs:** MUST follow the pattern `[namespace]-[category]-[sub-category]`.

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
This `SKILL.md` MUST contain the **Global Rules** for the domain, including:
- **Consistency Laws:** Directory patterns, naming conventions, and dependency rules.
- **The "Contract First" Rule:** Interface definitions must precede implementation.
- **Downward Discovery:** References to child skills using `skill:[id]`.
- **Agentic Call Stack Constraints:**
  - **Lookup Depth Limit:** 3 parent-lookups maximum.
  - **Namespace Isolation:** Purge skill context after the specific task is finished.
  - **The "Halt" Rule:** If a referenced skill is missing, STOP and ask for the file. DO NOT hallucinate rules.

#### B. The Specialized Children
These `SKILL.md` files focus on specific layers (Architecture, Security, etc.):
- **Upward Reference:** Link to the parent via `parent:` metadata and `skill:[parent-id]` in text for global laws.
- **Mode-Specific Logic:** Tool mode for auditing/linting that specific layer; Library mode for blueprinting/generating code for that layer.

---

## [TOOL_MODE]
**Trigger:** "Audit the [namespace] skills" or "Validate skill framework adherence."

When triggered, the Agent acts as a **Recursive Auditor** for the skill library itself.

1. **Physical Audit:** Verify all skills follow the `skills/[skill-id]/SKILL.md` pattern.
2. **Metadata Validation:** Ensure every `SKILL.md` has a valid YAML header with correct parent pointers.
3. **Logic Separation:** Confirm the presence of both `[TOOL_MODE]` and `[LIBRARY_MODE]` blocks.
4. **Resolution Check:** Verify that `skill:<name>` references correctly point to existing `SKILL.md` files in the registry.
5. **Halt Enforcement:** If any skill references a non-existent ID, flag it as a "Critical Dependency Violation" and do not attempt to infer the missing logic.

---

## Late-Binding Resolution Protocol (`skill:<name>`)
To resolve a logic gap, the Agent MUST:
1. Identify the `skill:` prefix.
2. Use the `read_file` tool to fetch `skills/[name]/SKILL.md`.
3. Merge the relevant `[MODE]` block into the current reasoning context.
4. Apply **Precedence:** Specific-Over-General (Child > Parent) and Latest-Over-Legacy.
