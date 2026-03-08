#!/bin/bash
# check-supply-chain.sh — Supply chain integrity audit
#
# What it tests:
#   - Dependency install scripts (preinstall, postinstall, etc.) for suspicious behavior
#   - New dependencies added since last clean snapshot
#
# Tools needed: grep, find
# What a failure means: A dependency runs code during install that phones home

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
if [[ "${NO_COLOR:-}" == "1" || "${1:-}" == "--no-color" ]]; then
  RED="" GREEN="" YELLOW="" NC=""
fi

FAIL=0
PASS=0
WARN=0
TOTAL=0

pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); echo -e "${GREEN}PASS${NC}: $1"; }
fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); echo -e "${RED}FAIL${NC}: $1"; }
warn() { WARN=$((WARN + 1)); echo -e "${YELLOW}WARN${NC}: $1"; }
info() { echo "  INFO: $1"; }

cd "$REPO_ROOT"

echo "=== Supply Chain Audit ==="
echo ""

# Telemetry domains to check install scripts against
BANNED_DOMAINS=(
  "posthog"
  "honeycomb"
  "opencode.ai"
  "opncd.ai"
  "sentry.io"
  "mixpanel"
  "amplitude"
  "segment.io"
)

# --- Check 1: Install script audit ---
echo "--- 1. Install script audit ---"

SCRIPT_HOOKS=("preinstall" "install" "postinstall" "prepare" "prepublish" "prepublishOnly")
SUSPICIOUS=0
TOTAL_SCRIPTS=0

# Find all package.json in node_modules (top-level deps only for speed)
if [[ -d "node_modules" ]]; then
  while IFS= read -r pjson; do
    for hook in "${SCRIPT_HOOKS[@]}"; do
      SCRIPT_CMD=$(grep -o "\"$hook\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$pjson" 2>/dev/null | head -1 || true)
      if [[ -n "$SCRIPT_CMD" ]]; then
        TOTAL_SCRIPTS=$((TOTAL_SCRIPTS + 1))
        PKG_NAME=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$pjson" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"/\1/' || true)
        # Check if the script references banned domains
        for domain in "${BANNED_DOMAINS[@]}"; do
          if echo "$SCRIPT_CMD" | grep -qi "$domain"; then
            fail "Install script in '$PKG_NAME' ($hook) references banned domain: $domain"
            SUSPICIOUS=1
          fi
        done
        # Check for curl/wget in install scripts (potential phone-home)
        if echo "$SCRIPT_CMD" | grep -qiE "curl|wget|node -e.*http|node -e.*fetch"; then
          warn "Install script in '$PKG_NAME' ($hook) makes network calls: $SCRIPT_CMD"
        fi
      fi
    done
  done < <(find node_modules -maxdepth 3 -name "package.json" -not -path "*/node_modules/*/node_modules/*" 2>/dev/null)

  if [[ $SUSPICIOUS -eq 0 ]]; then
    pass "No install scripts reference telemetry domains ($TOTAL_SCRIPTS scripts checked)"
  fi
else
  warn "node_modules not found — run 'bun install' first"
fi

# --- Check 2: Dependency diff from snapshot ---
echo ""
echo "--- 2. New dependency check ---"

SNAPSHOT_DIR="$REPO_ROOT/tests/snapshots"
if [[ -f "$SNAPSHOT_DIR/dep-list.txt" ]]; then
  # Get current top-level deps
  CURRENT_DEPS=$(find node_modules -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | sed 's|node_modules/||')
  SNAPSHOT_DEPS=$(cat "$SNAPSHOT_DIR/dep-list.txt")

  NEW_DEPS=$(comm -23 <(echo "$CURRENT_DEPS") <(echo "$SNAPSHOT_DEPS") 2>/dev/null || true)
  REMOVED_DEPS=$(comm -13 <(echo "$CURRENT_DEPS") <(echo "$SNAPSHOT_DEPS") 2>/dev/null || true)

  if [[ -n "$NEW_DEPS" ]]; then
    warn "New dependencies since last snapshot — review these:"
    echo "$NEW_DEPS" | while read -r dep; do
      echo "  + $dep"
    done
  fi
  if [[ -n "$REMOVED_DEPS" ]]; then
    info "Removed dependencies since last snapshot:"
    echo "$REMOVED_DEPS" | while read -r dep; do
      echo "  - $dep"
    done
  fi
  if [[ -z "$NEW_DEPS" && -z "$REMOVED_DEPS" ]]; then
    pass "Dependency list matches clean snapshot"
  fi
else
  warn "No dependency snapshot found — run tests/snapshots/take-snapshot.sh to create baseline"
fi

# --- Check 3: Husky/lefthook hooks audit ---
echo ""
echo "--- 3. Git hooks audit ---"

TOTAL=$((TOTAL + 1))
HOOK_SUSPICIOUS=0
if [[ -d ".husky" ]]; then
  for hookfile in .husky/*; do
    [[ -f "$hookfile" ]] || continue
    for domain in "${BANNED_DOMAINS[@]}"; do
      if grep -qi "$domain" "$hookfile" 2>/dev/null; then
        fail "Git hook '$hookfile' references banned domain: $domain"
        HOOK_SUSPICIOUS=1
      fi
    done
  done
fi
if [[ $HOOK_SUSPICIOUS -eq 0 ]]; then
  pass "No git hooks reference telemetry domains"
fi

# --- Summary ---
echo ""
echo "=== Supply Chain Audit Results ==="
echo "Total checks: $TOTAL"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Warnings: $WARN"

if [[ $FAIL -ne 0 ]]; then
  echo -e "${RED}SUPPLY CHAIN AUDIT FAILED${NC}"
  exit 1
fi

echo -e "${GREEN}SUPPLY CHAIN AUDIT PASSED${NC}"
exit 0
