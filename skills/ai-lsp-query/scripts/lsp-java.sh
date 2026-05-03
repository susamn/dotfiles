#!/usr/bin/env bash
# =============================================================================
# lsp-java.sh — Java LSP server bootstrap (jdtls — Eclipse JDT Language Server)
#
# STATUS: STUB — not yet wired to lsp-rpc.py.
#
# jdtls is significantly more complex to bootstrap than pylsp or gopls:
#   1. Requires a JVM (17+ for jdtls 1.x).
#   2. Needs a per-workspace data directory for its index.
#   3. First-run indexing can take 30–90 seconds on large projects.
#   4. Must be told about the build tool (Maven/Gradle) to resolve the classpath.
#   5. Uses a non-standard initialization sequence with workspace/executeCommand
#      calls to configure project facets.
#
# Implementation plan (tracked for next iteration):
#   Phase A — Basic wiring
#     • Locate jdtls installation (JDTLS_HOME env or sdkman candidate).
#     • Build the JVM launch command with equinox launcher JAR.
#     • Create a workspace-specific data dir ($HOME/.cache/jdtls/<workspace-hash>).
#     • Wire to lsp-rpc.py with a longer --timeout (120s) for first-run indexing.
#
#   Phase B — Build tool integration
#     • Detect Maven vs Gradle.
#     • Pass classpath resolution bundles to jdtls init options.
#     • Handle multi-module projects (jdtls needs each module registered).
#
#   Phase C — Index warm-up caching
#     • Detect if the workspace data dir is stale (pom.xml / build.gradle changed).
#     • Pre-warm the index as a background process before queries are fired.
#
# Prerequisites when implemented:
#   • Java 17+  (check: java -version)
#   • jdtls installed via:
#       sdkman:  (not directly available — install manually or via brew)
#       manual:  https://github.com/eclipse-jdtls/eclipse.jdt.ls/releases
#       brew:    brew install jdtls
#   • Set JDTLS_HOME to the extracted jdtls directory.
#
# Called by lsp-query.sh — do not invoke directly.
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'

err()  { echo -e "${RED}[lsp-java]${RESET} $*" >&2; }
warn() { echo -e "${YELLOW}[lsp-java]${RESET} $*" >&2; }
log()  { echo -e "${CYAN}[lsp-java]${RESET} $*" >&2; }

# ── Early stub notice ─────────────────────────────────────────────────────────
warn "lsp-java.sh is not yet implemented."
warn "Java LSP support (jdtls) is tracked for the next iteration of ai-lsp-query."
echo "" >&2
echo "  What you can do now for Java semantic queries:" >&2
echo "" >&2
echo "  1. Symbol search across a Maven project:" >&2
echo "     ./mvnw dependency:tree -Dincludes=<groupId>:<artifactId>" >&2
echo "" >&2
echo "  2. Find all usages of a class/method (grep-based, not semantic):" >&2
echo "     grep -rn 'MethodName' src/ --include='*.java'" >&2
echo "" >&2
echo "  3. For full semantic queries today, use IntelliJ's CLI (if available):" >&2
echo "     idea.sh inspect <project> <profile> <output>" >&2
echo "" >&2
echo "  Track implementation progress: see Phase A/B/C in lsp-java.sh header." >&2

exit 1
