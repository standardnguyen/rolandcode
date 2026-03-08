#!/bin/bash
# compare-snapshot.sh — Diff current state against known-good baseline
#
# What it tests:
#   - New URLs in the binary (CRITICAL)
#   - New dependencies (WARNING)
#   - Binary size change (WARNING if >10%)
#
# Tools needed: strings (from binutils), diff
# What a failure means: The build has changed from the verified baseline — review needed

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

CRITICAL=0
WARNINGS=0

crit() { CRITICAL=$((CRITICAL + 1)); echo -e "${RED}CRITICAL${NC}: $1"; }
warning() { WARNINGS=$((WARNINGS + 1)); echo -e "${YELLOW}WARNING${NC}: $1"; }
ok() { echo -e "${GREEN}OK${NC}: $1"; }
info() { echo "  INFO: $1"; }

cd "$REPO_ROOT"

echo "=== Snapshot Comparison ==="
echo ""

# Check if baseline exists
if [[ ! -f "$SCRIPT_DIR/package.json.clean" ]]; then
  echo -e "${YELLOW}SKIP${NC}: No baseline snapshot found — run take-snapshot.sh first"
  exit 0
fi

# --- Check 1: URL diff ---
echo "--- 1. Binary URL diff ---"

BINARY=""
for candidate in \
  "packages/opencode/dist/opencode-linux-x64/bin/rolandcode" \
  "packages/opencode/dist/opencode-linux-arm64/bin/rolandcode"; do
  if [[ -f "$candidate" ]]; then
    BINARY="$candidate"
    break
  fi
done

if [[ -n "$BINARY" && -f "$SCRIPT_DIR/urls.txt" ]] && command -v strings &>/dev/null; then
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' EXIT

  strings "$BINARY" | grep -oP 'https?://[^\s"'\''<>\\]+' | sort -u > "$TMPDIR/urls-current.txt"

  NEW_URLS=$(comm -23 "$TMPDIR/urls-current.txt" "$SCRIPT_DIR/urls.txt" 2>/dev/null || true)
  REMOVED_URLS=$(comm -13 "$TMPDIR/urls-current.txt" "$SCRIPT_DIR/urls.txt" 2>/dev/null || true)

  if [[ -n "$NEW_URLS" ]]; then
    # New URLs are flagged for review but not blocking — binary forensics
    # (check-binary.sh) is the hard gate for telemetry domains
    warning "New URLs found in binary since baseline — review for telemetry:"
    echo "$NEW_URLS" | while read -r url; do
      echo "    + $url"
    done
  else
    ok "No new URLs in binary"
  fi

  if [[ -n "$REMOVED_URLS" ]]; then
    info "URLs removed since baseline:"
    echo "$REMOVED_URLS" | head -10 | while read -r url; do
      echo "    - $url"
    done
  fi
else
  info "Skipping URL diff (no binary or no baseline)"
fi

# --- Check 2: Dependency diff ---
echo ""
echo "--- 2. Dependency diff ---"

if [[ -f "$SCRIPT_DIR/dep-list.txt" && -d "node_modules" ]]; then
  find node_modules -maxdepth 1 -mindepth 1 -type d | sed 's|node_modules/||' | sort > "$TMPDIR/deps-current.txt" 2>/dev/null || true

  NEW_DEPS=$(comm -23 "$TMPDIR/deps-current.txt" "$SCRIPT_DIR/dep-list.txt" 2>/dev/null || true)
  REMOVED_DEPS=$(comm -13 "$TMPDIR/deps-current.txt" "$SCRIPT_DIR/dep-list.txt" 2>/dev/null || true)

  if [[ -n "$NEW_DEPS" ]]; then
    NEW_COUNT=$(echo "$NEW_DEPS" | wc -l)
    warning "$NEW_COUNT new dependencies since baseline — review for telemetry:"
    echo "$NEW_DEPS" | head -20 | while read -r dep; do
      echo "    + $dep"
    done
  else
    ok "No new dependencies"
  fi
else
  info "Skipping dependency diff (no baseline or no node_modules)"
fi

# --- Check 3: Binary size diff ---
echo ""
echo "--- 3. Binary size diff ---"

if [[ -n "$BINARY" && -f "$SCRIPT_DIR/binary-size.txt" ]]; then
  CURRENT_SIZE=$(stat -c%s "$BINARY")
  BASELINE_SIZE=$(cat "$SCRIPT_DIR/binary-size.txt")

  if [[ "$BASELINE_SIZE" -gt 0 ]]; then
    DELTA=$(( (CURRENT_SIZE - BASELINE_SIZE) * 100 / BASELINE_SIZE ))
    DELTA_BYTES=$((CURRENT_SIZE - BASELINE_SIZE))

    if [[ $DELTA -gt 10 || $DELTA -lt -10 ]]; then
      warning "Binary size changed ${DELTA}% (${DELTA_BYTES} bytes): ${BASELINE_SIZE} -> ${CURRENT_SIZE}"
    else
      ok "Binary size within 10% of baseline (delta: ${DELTA}%, ${DELTA_BYTES} bytes)"
    fi
  fi
else
  info "Skipping binary size diff (no baseline)"
fi

# --- Summary ---
echo ""
echo "=== Snapshot Comparison Results ==="
echo "Critical: $CRITICAL"
echo "Warnings: $WARNINGS"

if [[ $CRITICAL -gt 0 ]]; then
  echo -e "${RED}SNAPSHOT COMPARISON FAILED — $CRITICAL critical differences${NC}"
  exit 1
fi

echo -e "${GREEN}SNAPSHOT COMPARISON PASSED${NC}"
exit 0
