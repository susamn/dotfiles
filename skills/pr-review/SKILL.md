---
name: pr-review
description: Generate a structured, LLM-ready PR review prompt from a GitHub pull request — fetches metadata, diff, and file list, injects optional story/ticket context, and writes a review-ready markdown file.
version: 1.0.0
triggers:
  - "review this PR"
  - "review pull request"
  - "generate PR review prompt"
  - "pr review for <url>"
  - "review <github-url>"
intent: code-review
guardrails:
  - Do not post or submit the review anywhere — output to a local file only
  - Do not proceed without a valid GitHub PR URL confirmed by the user
  - Do not include secrets, tokens, or credentials in the generated output
  - Warn if the diff exceeds ~500 KB (LLM context limits)
resources:
  - $SCRIPTS_PATH/pr-review-gen.sh
tools:
  - bash
  - gh
  - jq
interface:
  input:
    pr_url: "string — full GitHub PR URL (e.g. https://github.com/owner/repo/pull/42)"
    story_file: "string? — optional path to a ticket or user story file for context"
  output:
    prompts_dir: "string — path to generated directory containing prompt chunks: /tmp/pr-review/<randomid>/prompts/"
---

## What this skill does

Runs `$SCRIPTS_PATH/pr-review-gen.sh` to extract the PR diff, metadata, and a structured review prompt. 
To handle LLM context limits, the diffs are split into multiple chunks (~100KB each max). The prompt chunks are stored in `/tmp/pr-review/<randomid>/prompts/` (e.g., `p1.txt`, `p2.txt`). 
These are ready to be pasted into any LLM or iterated automatically by the `pr-review-ui` skill.

## Steps

1. Confirm the PR URL with the user if not already provided.
2. Optionally ask for a story/ticket file path for context (`-s <path>`). If not provided, the script prompts interactively or skips.
3. Run:

```bash
bash "$SCRIPTS_PATH/pr-review-gen.sh" [-s <story_file>]
```

4. Present the output prompts directory path (`/tmp/pr-review/<id>/prompts/`) to the user in the chat session.

## Dependencies

- `gh` (GitHub CLI) — must be authenticated (`gh auth status`)
- `jq` — JSON processor

If either is missing, the script exits with a clear error message.

## Output format

The generated files in the directory follow this structure:

```
# PR Review: <title>
## Story / Ticket Context
## PR Description
## Commits
## Changed Files (Entire PR)
## Chunk Information (Files in this chunk)
## Diff
  (chunk of up to ~100KB)
## Review Instructions   ← structured prompt with 9 review dimensions
## Summary template
```

## Notes

- Output prompts are written to `/tmp/pr-review/<random-id>/prompts/` so that they stay isolated from the current workspace.
- The `pr-review-ui` skill explicitly looks for this directory format to automatically process reviews chunk-by-chunk.
- The review prompt covers: Correctness, Code Quality, Security, Performance, Resource Leaks, Concurrency, Test Coverage, Maintainability, and Dependency changes.
