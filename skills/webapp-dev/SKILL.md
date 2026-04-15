---
name: webapp-dev
description: Architectural decision-making for modular web applications. Use this at the start of a project to decide on stack (Vue/Python), testing strategy, OpenAPI schema, and module dependencies.
version: 1.0.0
triggers:
  - "start a new webapp"
  - "design a modular application"
  - "select tech stack for webapp"
  - "create openapi schema for project"
  - "define module dependencies"
intent: architecture
---

# Webapp Architect

This skill guides the transition from a concept to a structured, modular technical design. It enforces an API-first and documentation-first approach.

## The Decision Flow

You must guide the user through these phases sequentially. Track progress in `PROJECT_STATE.md` in the project root.

### Phase 1: Application Type
Decide if the project is:
- **Frontend Only**: SPA/Static site.
- **Fullstack**: Frontend + Backend API (Default).

### Phase 2: Technology Selection
Confirm the stack. Defaults (unless overridden):
- **Frontend**: Vue 3 (Composables, Vite, Tailwind CSS).
- **Backend**: Python (FastAPI/Flask), `httpx` for internal calls, `axios` for frontend.
- **Language**: TypeScript (Frontend), Type-hinted Python (Backend).

### Phase 3: Testing Frameworks
Select the testing tiers:
- **Unit/Integration**: Vitest (Vue), Pytest (Python).
- **Behavioral**: Cucumber/Gherkin (Optional).
- **E2E**: Playwright (Mandatory for UI).

### Phase 4: API-First Design
1. Draft the **OpenAPI Schema** (`openapi.yaml`).
2. Iterate with the user until the schema is **finalized**.
3. Do NOT proceed to implementation until the schema is locked.

### Phase 5: Modularity & Dependencies
1. Identify the logical **Modules** (e.g., `auth`, `billing`, `core`).
2. Create a global `DEPENDENCY.md` defining how these modules interact.
3. Every module must be designed to be worked on independently.

## Project State Management

Maintain a `PROJECT_STATE.md` file with this structure:
```markdown
# Project State: [App Name]
- **Phase**: [Current Phase]
- **Type**: [Fullstack/Frontend]
- **Stack**: [List of selected techs]
- **Modules**: [List of modules]
- **API Status**: [Draft/Finalized]
```

## Transition to Implementation
Once Phase 5 is complete, inform the user that the project is ready for implementation using the `safe-coder` workflow.
