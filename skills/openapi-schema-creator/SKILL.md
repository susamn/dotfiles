---
name: openapi-schema-creator
description: >
  Guided, conversational workflow for generating production-quality OpenAPI 3.1.0 schemas. 
  Trigger for designing, generating, or refining REST API contracts, entity models, or service interfaces.
version: 1.0.0
triggers:
  - "create an OpenAPI schema"
  - "design an API for my idea"
  - "generate REST API spec"
  - "I want to build an API for"
  - "help me design an API contract"
intent: api-design
---

# OpenAPI Schema Creator

A structured lifecycle for transforming a raw service idea into a validated, production-ready OpenAPI 3.1.0 contract.

---

## Workflow

### Phase 1 — Idea & Convention Selection
1.  **Idea Intake**: Ask the user to describe the service's domain and goal.
2.  **Naming Convention**: Ask for a preference: `snake_case` (Python/Ruby style) or `camelCase` (JS/TS style). Default to `snake_case` for Python backends.

### Phase 2 — Entity Discovery
Propose a list of entities (nouns) based on the idea. For each, identify:
- **Attributes**: Field names and data types.
- **Relationships**: (e.g., User *has many* Orders).
- **Ownership**: Identify parent/child relationships.

Present the model in a clear Markdown table for confirmation.

### Phase 3 — CRUD & Endpoint Design
For each entity, suggest standard operations:
- `POST /entities` (Create)
- `GET /entities` (List with pagination)
- `GET /entities/{id}` (Read)
- `PUT/PATCH /entities/{id}` (Update)
- `DELETE /entities/{id}` (Delete)

**Ask about**:
- Non-CRUD actions (e.g., `/orders/{id}/cancel`).
- Authentication (Bearer, API Key, OAuth2/OIDC).
- Production hardening: Rate limiting, RFC 7807 problem details, and versioning (/v1/).

### Phase 4 — Schema Generation (OpenAPI 3.1.0)
Generate the **complete YAML schema** in a code block.
- Use `openapi: 3.1.0`.
- Utilize `$ref` for all reusable components.
- Include `info`, `servers`, `tags`, and `components/securitySchemes`.
- Use `example` values and `description` fields for everything.
- Enforce standard error shapes (400, 401, 404, 422, 500).

### Phase 5 — Iterative Refinement
Wait for user feedback. After any edit (adding fields, changing types, etc.), re-output the **full updated schema** so the user always has a single source of truth.

### Phase 6 — Persistence & Next Steps
1.  **Save to File**: Offer to write the final schema to `openapi.yaml` in the project root.
2.  **Tooling Suggestions**: Recommend tools for the next phase:
    - **Mocking**: `prism mock openapi.yaml`
    - **Client Gen**: `openapi-typescript` or `openapi-python-client`
3.  **Handoff**: Remind the user to update the `DEPENDENCY.md` and use the `safe-coder` workflow for implementation.

---

## Output Standards
- **Valid YAML**: Ensure the output passes standard OpenAPI validation.
- **Atomic Responses**: Paginated lists must use an envelope:
  ```yaml
  items:
    type: array
    items: { "$ref": "#/components/schemas/Entity" }
  total: { type: integer }
  page: { type: integer }
  size: { type: integer }
  ```
- **Error Shape**: Prefer [RFC 7807](https://tools.ietf.org/html/rfc7807) (type, title, status, detail, instance).
