#!/bin/bash
# verify-clean.sh — scan OpenCode source for telemetry endpoints
# Exit 0 = clean, Exit 1 = telemetry found
set -euo pipefail

FAIL=0
TOTAL=0
CLEAN=0

echo "=== OpenCode Telemetry Verification ==="
echo ""

# Domains to search for
DOMAINS=(
  "posthog"
  "honeycomb"
  "api.opencode.ai"
  "opncd.ai"
  "models.dev/api"
  "mcp.exa.ai"
  "opencode.ai/zen"
)

# SDK package names
SDKS=(
  "posthog-js"
  "posthog-node"
  "@honeycombio"
  "@opentelemetry"
)

# File extensions to scan
INCLUDE_ARGS=""
for ext in ts tsx js jsx go json yaml yml toml; do
  INCLUDE_ARGS="$INCLUDE_ARGS --include=*.$ext"
done

# Directories to exclude
EXCLUDE_ARGS="--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=vendor --exclude-dir=dist --exclude-dir=build"

echo "--- Domain checks ---"
for pattern in "${DOMAINS[@]}"; do
  TOTAL=$((TOTAL + 1))
  # shellcheck disable=SC2086
  if grep -r "$pattern" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null; then
    echo "FAIL: found telemetry domain: $pattern"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: no references to $pattern"
    CLEAN=$((CLEAN + 1))
  fi
  echo ""
done

echo "--- SDK/package checks ---"
for pattern in "${SDKS[@]}"; do
  TOTAL=$((TOTAL + 1))
  # shellcheck disable=SC2086
  if grep -r "$pattern" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null; then
    echo "FAIL: found telemetry SDK: $pattern"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: no references to $pattern"
    CLEAN=$((CLEAN + 1))
  fi
  echo ""
done

echo "=== Results ==="
echo "Total checks: $TOTAL"
echo "Clean: $CLEAN"
echo "Failed: $FAIL"
echo ""

if [ $FAIL -ne 0 ]; then
  echo "VERIFICATION FAILED — telemetry references remain"
  exit 1
fi

echo "VERIFICATION PASSED — no telemetry references found"
exit 0
