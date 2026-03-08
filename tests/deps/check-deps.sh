#!/bin/bash
# check-deps.sh — Dependency tree audit for telemetry packages
#
# What it tests:
#   - Direct dependencies in package.json for telemetry SDKs
#   - Transitive dependencies (full tree) for telemetry SDKs
#   - Lockfile drift from known-good snapshot
#
# Tools needed: grep, jq (optional)
# What a failure means: A telemetry SDK is in the dependency tree

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

cd "$REPO_ROOT"

echo "=== Dependency Audit ==="
echo ""

# Known telemetry packages
BAD_PACKAGES=(
  "posthog-js"
  "posthog-node"
  "posthog"
  "@honeycombio/"
  "@opentelemetry/"
  "@sentry/"
  "mixpanel"
  "amplitude-js"
  "amplitude"
  "@segment/"
  "rudder-sdk-node"
  "analytics-node"
)

# --- Check 1: Direct dependencies ---
echo "--- 1. Direct dependency check ---"

# Scan all package.json files in the repo (not node_modules)
PACKAGE_FILES=$(find . -name "package.json" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*")

FOUND_BAD=0
for pkg in "${BAD_PACKAGES[@]}"; do
  for pfile in $PACKAGE_FILES; do
    if grep -q "\"$pkg" "$pfile" 2>/dev/null; then
      fail "Found telemetry package '$pkg' in $pfile"
      FOUND_BAD=1
    fi
  done
done

if [[ $FOUND_BAD -eq 0 ]]; then
  pass "No telemetry packages in any package.json"
fi

# --- Check 2: Transitive dependency check ---
echo ""
echo "--- 2. Transitive dependency check ---"

# Check node_modules for telemetry packages
TRANS_FOUND=0
for pkg in "${BAD_PACKAGES[@]}"; do
  # Strip trailing / for directory matching
  PKG_CLEAN="${pkg%/}"
  if [[ -d "node_modules/$PKG_CLEAN" ]]; then
    fail "Telemetry package '$PKG_CLEAN' found in node_modules (transitive dependency)"
    TRANS_FOUND=1
  fi
  # Also check scoped packages
  if [[ "$pkg" == @*/ ]]; then
    SCOPE="${pkg%/}"
    if [[ -d "node_modules/$SCOPE" ]]; then
      SUBPKGS=$(ls "node_modules/$SCOPE" 2>/dev/null || true)
      if [[ -n "$SUBPKGS" ]]; then
        fail "Telemetry scope '$SCOPE' found in node_modules with packages: $SUBPKGS"
        TRANS_FOUND=1
      fi
    fi
  fi
done

if [[ $TRANS_FOUND -eq 0 ]]; then
  pass "No telemetry packages in transitive dependencies"
fi

# --- Check 3: Lockfile drift ---
echo ""
echo "--- 3. Lockfile drift check ---"

SNAPSHOT_DIR="$REPO_ROOT/tests/snapshots"
if [[ -f "$SNAPSHOT_DIR/package.json.clean" ]]; then
  # Compare root package.json deps against snapshot
  DIFF_OUTPUT=$(diff <(grep -E '"dependencies"|"devDependencies"' -A 1000 package.json | head -100) \
                     <(grep -E '"dependencies"|"devDependencies"' -A 1000 "$SNAPSHOT_DIR/package.json.clean" | head -100) 2>/dev/null || true)
  if [[ -n "$DIFF_OUTPUT" ]]; then
    warn "package.json has drifted from clean snapshot — review new dependencies"
    echo "$DIFF_OUTPUT" | head -20
  else
    pass "package.json matches clean snapshot"
  fi
else
  warn "No clean package.json snapshot found — run tests/snapshots/take-snapshot.sh to create baseline"
fi

# --- Summary ---
echo ""
echo "=== Dependency Audit Results ==="
echo "Total checks: $TOTAL"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Warnings: $WARN"

if [[ $FAIL -ne 0 ]]; then
  echo -e "${RED}DEPENDENCY AUDIT FAILED${NC}"
  exit 1
fi

echo -e "${GREEN}DEPENDENCY AUDIT PASSED${NC}"
exit 0
