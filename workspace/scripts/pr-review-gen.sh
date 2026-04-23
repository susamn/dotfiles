#!/usr/bin/env bash
# pr-review-gen.sh — Generate an LLM-ready PR review prompt
# Usage: pr-review-gen.sh [-s <story_file>]

set -euo pipefail

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[info]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[done]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[warn]${RESET}  $*"; }
die()     { echo -e "${RED}${BOLD}[error]${RESET} $*" >&2; exit 1; }

# ── dependency check ──────────────────────────────────────────────────────────
command -v gh  >/dev/null 2>&1 || die "'gh' (GitHub CLI) is not installed. https://cli.github.com"
command -v jq  >/dev/null 2>&1 || die "'jq' is not installed. brew/apt install jq"

# ── argument parsing ──────────────────────────────────────────────────────────
STORY_FILE=""
while getopts ":s:" opt; do
  case $opt in
    s) STORY_FILE="$OPTARG" ;;
    \?) die "Unknown flag: -$OPTARG" ;;
    :)  die "-$OPTARG requires an argument (path to story file)" ;;
  esac
done

# ── get PR URL ────────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}       PR Review Prompt Generator                ${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo
read -rp "$(echo -e "${CYAN}Enter PR URL:${RESET} ")" PR_URL

[[ -z "$PR_URL" ]] && die "PR URL cannot be empty."

# ── parse owner/repo and PR number from URL ───────────────────────────────────
# Handles: https://github.com/owner/repo/pull/123
#          github.com/owner/repo/pull/123
PR_URL_CLEAN="${PR_URL#https://}"
PR_URL_CLEAN="${PR_URL_CLEAN#http://}"

IFS='/' read -ra URL_PARTS <<< "$PR_URL_CLEAN"
# Expected: github.com / owner / repo / pull / 123
if [[ ${#URL_PARTS[@]} -lt 5 || "${URL_PARTS[3]}" != "pull" ]]; then
  die "Could not parse PR URL. Expected format: https://github.com/owner/repo/pull/NUMBER"
fi

OWNER="${URL_PARTS[1]}"
REPO="${URL_PARTS[2]}"
PR_NUMBER="${URL_PARTS[4]}"
REPO_SLUG="${OWNER}/${REPO}"

info "Fetching PR #${PR_NUMBER} from ${REPO_SLUG} …"

# ── fetch PR metadata ─────────────────────────────────────────────────────────
PR_JSON=$(gh pr view "$PR_URL" \
  --json number,title,body,author,baseRefName,headRefName,\
additions,deletions,changedFiles,labels,milestone,reviews,commits \
  2>/dev/null) || die "Failed to fetch PR metadata. Check the URL and your 'gh auth status'."

PR_TITLE=$(jq -r '.title'              <<< "$PR_JSON")
PR_BODY=$(jq  -r '.body // "*(no description)*"' <<< "$PR_JSON")
PR_AUTHOR=$(jq -r '.author.login'      <<< "$PR_JSON")
BASE_BRANCH=$(jq -r '.baseRefName'     <<< "$PR_JSON")
HEAD_BRANCH=$(jq -r '.headRefName'     <<< "$PR_JSON")
ADDITIONS=$(jq -r '.additions'         <<< "$PR_JSON")
DELETIONS=$(jq -r '.deletions'         <<< "$PR_JSON")
CHANGED_FILES=$(jq -r '.changedFiles'  <<< "$PR_JSON")
LABELS=$(jq -r '[.labels[].name] | join(", ")' <<< "$PR_JSON")
COMMITS=$(jq -r '[.commits[].messageHeadline] | map("  - " + .) | join("\n")' <<< "$PR_JSON")

# ── fetch diff ────────────────────────────────────────────────────────────────
info "Fetching PR diff …"
PR_DIFF=$(gh pr diff "$PR_URL" 2>/dev/null) \
  || die "Failed to fetch diff. Ensure you have read access to the repo."

# ── fetch file list ───────────────────────────────────────────────────────────
FILES_JSON=$(gh pr view "$PR_URL" --json files 2>/dev/null || echo '{"files":[]}')
FILE_LIST=$(jq -r '.files[] | "  - \(.path)  [\(.additions)+  \(.deletions)-]"' <<< "$FILES_JSON")

# ── get story ────────────────────────────────────────────────────────────────
echo
if [[ -n "$STORY_FILE" ]]; then
  [[ -f "$STORY_FILE" ]] || die "Story file not found: $STORY_FILE"
  STORY=$(< "$STORY_FILE")
  info "Story loaded from: $STORY_FILE"
else
  echo -e "${CYAN}${BOLD}Paste the user story / ticket description below.${RESET}"
  echo -e "${YELLOW}(Press ${BOLD}Ctrl+D${RESET}${YELLOW} on a new line when done)${RESET}"
  echo
  STORY=$(cat) || true
fi

[[ -z "$STORY" ]] && warn "No story provided — the prompt will skip story context."

# ── chunk diffs and assembly ──────────────────────────────────────────────────
RANDOM_ID=$(head -c 4 /dev/urandom | xxd -p | head -n 1 2>/dev/null || echo "$RANDOM$RANDOM")
OUTPUT_DIR="/tmp/pr-review/${RANDOM_ID}/prompts"
mkdir -p "$OUTPUT_DIR"

info "Generating review prompts in chunks → ${OUTPUT_DIR}/"

MAX_CHUNK_SIZE=${MAX_CHUNK_SIZE:-102400}

awk -v outdir="$OUTPUT_DIR" -v max_size="$MAX_CHUNK_SIZE" '
BEGIN {
    chunk_id = 1
    current_size = 0
    current_diff = ""
}
/^diff --git / {
    if (current_size > 0 && (current_size + length($0) > max_size)) {
        fname = outdir "/chunk_" chunk_id ".diff"
        print current_diff > fname
        close(fname)
        
        chunk_id++
        current_size = 0
        current_diff = ""
    }
}
{
    current_diff = current_diff $0 "\n"
    current_size += length($0) + 1
}
END {
    if (current_size > 0) {
        fname = outdir "/chunk_" chunk_id ".diff"
        print current_diff > fname
        close(fname)
    }
}
' <<< "$PR_DIFF"

HEADER=$(cat <<PROMPT
# PR Review: ${PR_TITLE}

**Repo:** \`${REPO_SLUG}\`  **PR:** #${PR_NUMBER}  **Author:** @${PR_AUTHOR}
**Branch:** \`${HEAD_BRANCH}\` → \`${BASE_BRANCH}\`
**Changes:** +${ADDITIONS} / -${DELETIONS} across ${CHANGED_FILES} file(s)
${LABELS:+**Labels:** ${LABELS}}

---

## Story / Ticket Context

$(if [[ -n "$STORY" ]]; then echo "$STORY"; else echo "_No story provided._"; fi)

---

## PR Description

${PR_BODY}

---

## Commits

${COMMITS:-  *(none listed)*}

---

## Changed Files (Entire PR)

${FILE_LIST:-  *(unavailable)*}

---

## Chunk Information

PROMPT
)

INSTRUCTIONS=$(cat <<PROMPT

---

## Review Instructions

You are a senior software engineer conducting a thorough code review.
Analyse the diff and context above, then produce a **structured review** using the format below.

**Rules:**
- Be precise and concise — no filler, no fluff.
- Every comment must reference the specific file and line range where possible (e.g. \`src/Foo.java:42-58\`).
- If a section has no findings, write "✅ No issues found."

---

### 1. Correctness & Logic
- Does the implementation match the story/ticket intent?
- Are there edge cases, off-by-one errors, or missing null/empty checks?
- Are error/exception paths handled properly?

### 2. Code Quality & Best Practices
- Naming clarity (variables, methods, classes).
- Single Responsibility, DRY violations, unnecessary complexity.
- Dead code, commented-out code, or debug statements left in.
- Magic numbers or strings that should be constants.

### 3. Security & Vulnerabilities
- Injection risks (SQL, command, path traversal).
- Hardcoded secrets, tokens, or credentials.
- Unsafe deserialization, insecure defaults, missing auth/authz checks.
- Input validation — are external inputs sanitised before use?

### 4. Performance & Resource Utilisation
- N+1 queries, missing indexes, unnecessary full-table scans.
- Inefficient loops or repeated expensive operations.
- Blocking I/O on non-async paths; large in-memory collections.
- Unnecessary object creation or boxing.

### 5. Resource Leak & Cleanup
- Are all streams, connections, file handles, and locks properly closed?
- Missing \`try-with-resources\`, \`defer\`, or \`finally\` blocks.
- Goroutine / thread leaks; uncancelled contexts.

### 6. Concurrency & Thread Safety
- Shared mutable state without synchronisation.
- Race conditions, improper use of \`volatile\`, incorrect \`synchronized\` scope.
- Deadlock potential (lock ordering, nested locks).

### 7. Test Coverage
- Are there unit/integration tests for the new or changed logic?
- Do tests cover happy path **and** failure/edge cases?
- Are test assertions meaningful (not just "no exception thrown")?
- Is test data representative and free of hardcoded environment assumptions?

### 8. Maintainability & Observability
- Is the code adequately commented where non-obvious?
- Are new log statements at the right level (DEBUG/INFO/WARN/ERROR)?
- Are metrics, traces, or events emitted for observability?
- Will a future developer understand the *why* behind this change?

### 9. Dependency & API Changes
- New dependencies: are they well-maintained, licence-compatible, and not bloated?
- Breaking changes to public APIs, contracts, or shared interfaces?
- Migration / backward-compatibility concerns (DB schema, config keys, serialised formats)?

---

## Summary

After your line-by-line findings, provide:

**Must Fix** (blocks merge):
- List critical issues only.

**Should Fix** (important but not blocking):
- List significant improvements.

**Suggestions** (optional / nice-to-have):
- Minor style or future-proofing ideas.

**Overall Verdict:** \`APPROVE\` | \`REQUEST CHANGES\` | \`NEEDS DISCUSSION\`
PROMPT
)

CHUNK_ID=1
TOTAL_CHUNKS=$(find "$OUTPUT_DIR" -maxdepth 1 -name "chunk_*.diff" | wc -l | xargs)

if [[ "$TOTAL_CHUNKS" == "0" ]]; then
  warn "No diffs found."
fi

while [[ -f "${OUTPUT_DIR}/chunk_${CHUNK_ID}.diff" ]]; do
    PROMPT_FILE="${OUTPUT_DIR}/p${CHUNK_ID}.txt"
    echo "$HEADER" > "$PROMPT_FILE"
    
    echo "This is chunk **${CHUNK_ID} of ${TOTAL_CHUNKS}**." >> "$PROMPT_FILE"
    echo "Files included in this chunk:" >> "$PROMPT_FILE"
    
    grep -Eo 'diff --git a/.* b/.*' "${OUTPUT_DIR}/chunk_${CHUNK_ID}.diff" | sed 's|^diff --git a/||' | sed 's| b/.*||' | while IFS= read -r f; do
         echo "- \`$f\`" >> "$PROMPT_FILE"
    done
    echo "" >> "$PROMPT_FILE"
    
    echo "## Diff" >> "$PROMPT_FILE"
    echo "" >> "$PROMPT_FILE"
    echo "\`\`\`diff" >> "$PROMPT_FILE"
    cat "${OUTPUT_DIR}/chunk_${CHUNK_ID}.diff" >> "$PROMPT_FILE"
    echo "\`\`\`" >> "$PROMPT_FILE"
    
    echo "$INSTRUCTIONS" >> "$PROMPT_FILE"
    
    rm "${OUTPUT_DIR}/chunk_${CHUNK_ID}.diff"
    ((CHUNK_ID++))
done

# ── done ─────────────────────────────────────────────────────────────────────
echo
success "Prompts saved to directory: ${BOLD}${OUTPUT_DIR}${RESET}"
echo -e "  ${YELLOW}Total Chunks:${RESET} ${TOTAL_CHUNKS}"
echo

