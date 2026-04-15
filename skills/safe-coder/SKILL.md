---
name: safe-coder
description: Strict, high-integrity execution for all development tasks. Enforces a documentation-driven workflow (CONTEXT, DEPENDENCY, TODO), modular development, test-first methodology, and mandatory security audits.
version: 1.0.0
triggers:
  - "implement feature"
  - "fix bug"
  - "refactor code"
  - "work on module"
  - "add new test"
  - "safe-coder"
intent: execution
guardrails:
  - Never delete existing test cases.
  - One change per PR (strictly one TODO item at a time).
  - Do not commit changes until tests pass and CVE audit is complete.
---

# Safe Coder

This skill enforces a disciplined engineering lifecycle for all code changes. It ensures that every change is intentional, documented, and verified.

## Mandatory Execution Loop

Before making ANY code change, you must follow this sequence:

### 1. Load Context
Read these files in order to understand the module and its place in the system:
1.  **`module/CONTEXT.md`**: Understand the logic and rationale.
2.  **`DEPENDENCY.md`**: Understand how this module interacts with others.
3.  **`module/TODO.md`**: Identify the specific task to execute.

### 2. Atomic Change (Small PR)
- Select exactly **ONE** item from `TODO.md`.
- Each change must be surgical. If a task is too large, split it into smaller TODO items first.
- If you create a new module, use the templates in `assets/` to create its `CONTEXT.md` and `TODO.md`.

### 3. Test-First Implementation
- For every change, you MUST create or update test cases.
- **NEVER** delete existing tests; only add or modify them if the requirements have changed.

### 4. Validation & Security Audit
Before completing the task:
1.  **Run Tests**: Execute the project's test suite (e.g., `pytest`, `npm test`, `vitest`).
2.  **CVE Audit**: Check dependencies for active vulnerabilities:
    - **JS/TS**: `npm audit` or `yarn audit`.
    - **Python**: `pip-audit` or `safety check`.
    - **Other**: Use the standard ecosystem tool for the language.
3.  **Audit Result**: Report any active CVEs to the user immediately.

## Scaffolding New Modules
When creating a new module, you must initialize it with:
- `CONTEXT.md`: Using the `context-template.md` asset.
- `TODO.md`: Using the `todo-template.md` asset.
- `tests/`: A dedicated test directory.
