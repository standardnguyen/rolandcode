#!/bin/bash
# take-snapshot.sh — Create a known-good baseline for differential comparison
#
# Run this after a verified clean build. The snapshot is committed to the repo
# and used by compare-snapshot.sh to detect regressions.
#
# Tools needed: strings (from binutils)
# What a failure means: N/A — this is a data collection script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo "  INFO: $1"; }

cd "$REPO_ROOT"

echo "=== Taking Clean Snapshot ==="
echo ""

# Find binary
BINARY=""
for candidate in \
  "packages/opencode/dist/opencode-linux-x64/bin/rolandcode" \
  "packages/opencode/dist/opencode-linux-arm64/bin/rolandcode"; do
  if [[ -f "$candidate" ]]; then
    BINARY="$candidate"
    break
  fi
done

# Snapshot: root package.json
cp package.json "$SCRIPT_DIR/package.json.clean"
info "Saved package.json.clean"

# Snapshot: opencode package.json
if [[ -f "packages/opencode/package.json" ]]; then
  cp packages/opencode/package.json "$SCRIPT_DIR/opencode-package.json.clean"
  info "Saved opencode-package.json.clean"
fi

# Snapshot: top-level dependency list
if [[ -d "node_modules" ]]; then
  find node_modules -maxdepth 1 -mindepth 1 -type d | sed 's|node_modules/||' | sort > "$SCRIPT_DIR/dep-list.txt"
  DEP_COUNT=$(wc -l < "$SCRIPT_DIR/dep-list.txt")
  info "Saved dep-list.txt ($DEP_COUNT top-level dependencies)"
fi

# Snapshot: binary size
if [[ -n "$BINARY" ]]; then
  stat -c%s "$BINARY" > "$SCRIPT_DIR/binary-size.txt"
  info "Saved binary-size.txt ($(cat "$SCRIPT_DIR/binary-size.txt") bytes)"

  # Snapshot: URLs in binary
  if command -v strings &>/dev/null; then
    strings "$BINARY" | grep -oP 'https?://[^\s"'\''<>\\]+' | sort -u > "$SCRIPT_DIR/urls.txt"
    URL_COUNT=$(wc -l < "$SCRIPT_DIR/urls.txt")
    info "Saved urls.txt ($URL_COUNT unique URLs)"
  fi
else
  echo -e "${YELLOW}WARN${NC}: No binary found — skipping binary snapshots"
fi

echo ""
echo -e "${GREEN}Snapshot complete.${NC} Commit tests/snapshots/ to save the baseline."
echo "Use tests/snapshots/compare-snapshot.sh to diff future builds against this baseline."
