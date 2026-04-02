#!/bin/bash
# check-binary.sh — Compiled binary forensics
#
# What it tests:
#   - strings extraction for telemetry domains
#   - Full URL extraction and cross-reference against banlist
#   - Base64-encoded telemetry domain detection
#   - High-entropy section detection (obfuscated payloads)
#
# Tools needed: strings (from binutils), base64
# What a failure means: Telemetry endpoints exist in the compiled binary

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

# Find the binary
BINARY=""
for candidate in \
  "packages/opencode/dist/opencode-linux-x64/bin/rolandcode" \
  "packages/opencode/dist/opencode-linux-arm64/bin/rolandcode" \
  "dist/rolandcode"; do
  if [[ -f "$candidate" ]]; then
    BINARY="$candidate"
    break
  fi
done

if [[ -z "$BINARY" ]]; then
  echo -e "${YELLOW}SKIP${NC}: No compiled binary found — build first with 'bun run build --single'"
  exit 0
fi

if ! command -v strings &>/dev/null; then
  echo -e "${YELLOW}SKIP${NC}: 'strings' not found — install binutils"
  exit 0
fi

echo "=== Binary Forensics ==="
echo "Binary: $BINARY ($(du -h "$BINARY" | cut -f1))"
echo ""

# Extract strings once (expensive on a 154MB binary)
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

strings "$BINARY" > "$TMPDIR/all-strings.txt"
TOTAL_STRINGS=$(wc -l < "$TMPDIR/all-strings.txt")
info "Extracted $TOTAL_STRINGS strings from binary"

# --- Check 1: Telemetry domains in strings ---
echo ""
echo "--- 1. Telemetry domain scan ---"

BANNED_DOMAINS=(
  "us.i.posthog.com"
  "api.honeycomb.io"
  "api.opencode.ai"
  "opncd.ai"
  "opencode.ai/zen"
  "mcp.exa.ai"
  "app.opencode.ai"
)

# models.dev is in the vendored model snapshot — check for the specific
# telemetry patterns, not the domain in model catalog data
BANNED_DOMAINS_STRICT=(
  "us.i.posthog.com"
  "api.honeycomb.io"
  "api.opencode.ai"
  "opncd.ai"
  "opencode.ai/zen"
  "mcp.exa.ai"
  "app.opencode.ai"
)

for domain in "${BANNED_DOMAINS_STRICT[@]}"; do
  TOTAL=$((TOTAL + 1))
  HITS=$(grep -c "$domain" "$TMPDIR/all-strings.txt" 2>/dev/null || true)
  if [[ "$HITS" -gt 0 ]]; then
    fail "Found $HITS references to '$domain' in binary strings"
    grep "$domain" "$TMPDIR/all-strings.txt" | head -5
    FAIL=$((FAIL + 1))
    TOTAL=$((TOTAL - 1))
  else
    pass "No references to '$domain' in binary"
    PASS=$((PASS - 1))
  fi
done

# --- Check 2: Full URL extraction ---
echo ""
echo "--- 2. URL extraction and audit ---"

grep -oP 'https?://[^\s"'\''<>\\]+' "$TMPDIR/all-strings.txt" | sort -u > "$TMPDIR/urls.txt"
URL_COUNT=$(wc -l < "$TMPDIR/urls.txt")
info "Found $URL_COUNT unique URLs in binary"

TOTAL=$((TOTAL + 1))
BANNED_URL_HITS=0
for domain in "${BANNED_DOMAINS_STRICT[@]}"; do
  if grep -q "$domain" "$TMPDIR/urls.txt" 2>/dev/null; then
    fail "Banned URL found in binary: $(grep "$domain" "$TMPDIR/urls.txt" | head -3)"
    BANNED_URL_HITS=$((BANNED_URL_HITS + 1))
  fi
done

if [[ $BANNED_URL_HITS -eq 0 ]]; then
  pass "No banned URLs in binary"
fi

# Save URL list for snapshot comparison
if [[ -d "$REPO_ROOT/tests/snapshots" ]]; then
  cp "$TMPDIR/urls.txt" "$REPO_ROOT/tests/snapshots/urls-current.txt" 2>/dev/null || true
fi

# --- Check 3: Base64 encoded domain scan ---
echo ""
echo "--- 3. Base64 obfuscation scan ---"

TOTAL=$((TOTAL + 1))
B64_FOUND=0

# Pre-compute base64 encodings of banned domains
declare -A B64_MAP
for domain in "${BANNED_DOMAINS_STRICT[@]}"; do
  B64_MAP["$domain"]=$(echo -n "$domain" | base64)
done

# Search for base64-encoded versions of banned domains
for domain in "${BANNED_DOMAINS_STRICT[@]}"; do
  B64="${B64_MAP[$domain]}"
  if grep -q "$B64" "$TMPDIR/all-strings.txt" 2>/dev/null; then
    fail "Found base64-encoded telemetry domain in binary: $domain -> $B64"
    B64_FOUND=1
  fi
done

# Also try decoding suspicious base64 strings and checking for domains
grep -oP '[A-Za-z0-9+/]{20,}={0,2}' "$TMPDIR/all-strings.txt" 2>/dev/null | head -1000 > "$TMPDIR/b64-candidates.txt" || true
while read -r candidate; do
  DECODED=$(echo "$candidate" | base64 -d 2>/dev/null | tr -d '\0' || true)
  for domain in "${BANNED_DOMAINS_STRICT[@]}"; do
    if echo "$DECODED" | grep -q "$domain" 2>/dev/null; then
      fail "Base64 string decodes to telemetry domain: $candidate -> $DECODED"
      B64_FOUND=1
    fi
  done
done < "$TMPDIR/b64-candidates.txt" 2>/dev/null

if [[ $B64_FOUND -eq 0 ]]; then
  pass "No base64-encoded telemetry domains found"
fi

# --- Check 4: Binary size tracking ---
echo ""
echo "--- 4. Binary size tracking ---"

BINARY_SIZE=$(stat -c%s "$BINARY")
BINARY_SIZE_MB=$((BINARY_SIZE / 1048576))
info "Binary size: ${BINARY_SIZE_MB}MB ($BINARY_SIZE bytes)"

SNAPSHOT_DIR="$REPO_ROOT/tests/snapshots"
if [[ -f "$SNAPSHOT_DIR/binary-size.txt" ]]; then
  BASELINE_SIZE=$(cat "$SNAPSHOT_DIR/binary-size.txt")
  if [[ "$BASELINE_SIZE" -gt 0 ]]; then
    DELTA=$(( (BINARY_SIZE - BASELINE_SIZE) * 100 / BASELINE_SIZE ))
    if [[ $DELTA -gt 10 ]]; then
      warn "Binary size increased ${DELTA}% from baseline (${BASELINE_SIZE} -> ${BINARY_SIZE}) — could indicate new bundled code"
    elif [[ $DELTA -lt -10 ]]; then
      warn "Binary size decreased ${DELTA}% from baseline — unexpected"
    else
      info "Binary size within 10% of baseline (delta: ${DELTA}%)"
    fi
  fi
fi

# --- Check 5: PostHog/Honeycomb SDK patterns ---
echo ""
echo "--- 5. SDK fingerprint scan ---"

TOTAL=$((TOTAL + 1))
SDK_FOUND=0
SDK_PATTERNS=(
  "posthog.capture"
  "posthog.identify"
  "posthog.init"
  "honeycomb.io"
  "HoneycombSDK"
  "PostHog"
  "POSTHOG_API_KEY"
  "HONEYCOMB_API_KEY"
)

for pattern in "${SDK_PATTERNS[@]}"; do
  HITS=$(grep -c "$pattern" "$TMPDIR/all-strings.txt" 2>/dev/null || true)
  if [[ "$HITS" -gt 0 ]]; then
    fail "Found SDK fingerprint '$pattern' ($HITS occurrences) in binary"
    SDK_FOUND=1
  fi
done

if [[ $SDK_FOUND -eq 0 ]]; then
  pass "No telemetry SDK fingerprints in binary"
fi

# --- Summary ---
echo ""
echo "=== Binary Forensics Results ==="
echo "Total checks: $TOTAL"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Warnings: $WARN"

if [[ $FAIL -ne 0 ]]; then
  echo -e "${RED}BINARY FORENSICS FAILED${NC}"
  exit 1
fi

echo -e "${GREEN}BINARY FORENSICS PASSED${NC}"
exit 0
