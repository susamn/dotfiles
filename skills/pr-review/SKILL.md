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
    review_file: "string — path to generated markdown file: <repo>_pr<number>_review.md"
---

## What this skill does

Runs `$SCRIPTS_PATH/pr-review-gen.sh` to produce a self-contained markdown file containing the PR diff, metadata, and a structured review prompt. The resulting file is ready to paste into any LLM for a thorough code review.

## Steps

1. Confirm the PR URL with the user if not already provided.
2. Optionally ask for a story/ticket file path for context (`-s <path>`). If not provided, the script prompts interactively or skips.
3. Run:

```bash
bash "$SCRIPTS_PATH/pr-review-gen.sh" [-s <story_file>]
```

4. Report the output filename and line count to the user.

## Dependencies

- `gh` (GitHub CLI) — must be authenticated (`gh auth status`)
- `jq` — JSON processor

If either is missing, the script exits with a clear error message.

## Output format

The generated file follows this structure:

```
# PR Review: <title>
## Story / Ticket Context
## PR Description
## Commits
## Changed Files
## Diff
## Review Instructions   ← structured prompt with 9 review dimensions
## Summary template
```

## Notes

- Output file is written to the **current working directory** where the agent invoked the script.
- Large diffs (>500 KB) trigger a warning; consider splitting the PR in that case.
- The review prompt covers: Correctness, Code Quality, Security, Performance, Resource Leaks, Concurrency, Test Coverage, Maintainability, and Dependency changes.
