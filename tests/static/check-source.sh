#!/bin/bash
# check-source.sh — Static analysis of source code for telemetry references
#
# What it tests:
#   - Known telemetry domains in source files
#   - Telemetry SDK imports
#   - Known-bad environment variables
#   - Dynamic URL construction patterns
#   - Dynamic code execution (eval, new Function)
#   - Timer/scheduler patterns near network calls
#   - Worker/subprocess spawning
#
# Tools needed: grep (GNU)
# What a failure means: Telemetry code exists in source that should have been stripped

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Color support
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

# File extensions to scan
INCLUDE_ARGS=""
for ext in ts tsx js jsx go json yaml yml toml; do
  INCLUDE_ARGS="$INCLUDE_ARGS --include=*.$ext"
done

# Exclude non-source directories and build artifacts
EXCLUDE_ARGS="--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=vendor --exclude-dir=dist --exclude-dir=build --exclude-dir=tests --exclude=models-snapshot.ts --exclude=models-api.json"

echo "=== Static Analysis ==="
echo ""

# --- Check 1: Domain grep ---
echo "--- 1. Domain grep ---"

DOMAINS=(
  "posthog"
  "honeycomb"
  "api.opencode.ai"
  "opncd.ai"
  "models.dev"
  "mcp.exa.ai"
  "opencode.ai/zen"
  "app.opencode.ai"
)

for domain in "${DOMAINS[@]}"; do
  TOTAL=$((TOTAL + 1))
  # shellcheck disable=SC2086
  if grep -rn "$domain" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | grep -v "README.md" | grep -v "CHANGELOG.md" | grep -v "LICENSE"; then
    fail "Found telemetry domain: $domain"
    FAIL=$((FAIL + 1))
    TOTAL=$((TOTAL - 1))  # undo double-count
  else
    pass "No references to $domain"
    PASS=$((PASS - 1))  # undo double-count
  fi
done

# --- Check 2: Import/require audit ---
echo ""
echo "--- 2. Import/require audit ---"

BAD_PACKAGES=(
  "posthog"
  "@posthog/"
  "posthog-js"
  "posthog-node"
  "@honeycombio/"
  "@opentelemetry/"
  "@sentry/"
  "mixpanel"
  "amplitude"
  "@segment/"
  "rudderstack"
  "analytics-node"
)

for pkg in "${BAD_PACKAGES[@]}"; do
  TOTAL=$((TOTAL + 1))
  # shellcheck disable=SC2086
  if grep -rn "from ['\"]${pkg}" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | grep -v "README.md"; then
    fail "Found telemetry import: $pkg"
    FAIL=$((FAIL + 1))
    TOTAL=$((TOTAL - 1))
  elif grep -rn "require(['\"]${pkg}" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | grep -v "README.md"; then
    fail "Found telemetry require: $pkg"
    FAIL=$((FAIL + 1))
    TOTAL=$((TOTAL - 1))
  else
    pass "No imports of $pkg"
    PASS=$((PASS - 1))
  fi
done

# --- Check 3: Environment variable audit ---
echo ""
echo "--- 3. Known-bad environment variables ---"

BAD_ENV_VARS=(
  "POSTHOG_API_KEY"
  "POSTHOG_HOST"
  "HONEYCOMB_API_KEY"
  "HONEYCOMB_DATASET"
  "SENTRY_DSN"
  "MIXPANEL_TOKEN"
  "AMPLITUDE_API_KEY"
  "SEGMENT_WRITE_KEY"
)

for var in "${BAD_ENV_VARS[@]}"; do
  TOTAL=$((TOTAL + 1))
  # shellcheck disable=SC2086
  if grep -rn "$var" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null; then
    fail "Found telemetry env var reference: $var"
    FAIL=$((FAIL + 1))
    TOTAL=$((TOTAL - 1))
  else
    pass "No references to $var"
    PASS=$((PASS - 1))
  fi
done

# --- Check 4: Base64 obfuscation in source ---
echo ""
echo "--- 4. Base64-encoded telemetry detection ---"

TOTAL=$((TOTAL + 1))
B64_FOUND=0

# Pre-compute base64 encodings of banned domains
BANNED_FULL_DOMAINS=(
  "us.i.posthog.com"
  "api.honeycomb.io"
  "api.opencode.ai"
  "opncd.ai"
  "opencode.ai"
  "mcp.exa.ai"
  "app.opencode.ai"
)

for domain in "${BANNED_FULL_DOMAINS[@]}"; do
  B64=$(echo -n "$domain" | base64)
  # shellcheck disable=SC2086
  if grep -rn "$B64" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | grep -v "README.md"; then
    fail "Found base64-encoded telemetry domain in source: $domain -> $B64"
    B64_FOUND=1
  fi
done

# Also check for atob/Buffer.from patterns that decode to something suspicious
# shellcheck disable=SC2086
ATOB_CALLS=$(grep -rn 'atob\s*(' $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | grep -v "README.md" | grep -v "node_modules" || true)
if [[ -n "$ATOB_CALLS" ]]; then
  # Extract the base64 string arguments and try decoding them
  B64_LITERALS=$(echo "$ATOB_CALLS" | grep -oP 'atob\s*\(\s*["\x27]([A-Za-z0-9+/=]+)["\x27]' 2>/dev/null | grep -oP '[A-Za-z0-9+/=]{8,}' 2>/dev/null || true)
  if [[ -n "$B64_LITERALS" ]]; then
    while read -r b64str; do
      [[ -z "$b64str" ]] && continue
      DECODED=$(echo "$b64str" | base64 -d 2>/dev/null | tr -d '\0' || true)
      for domain in "${BANNED_FULL_DOMAINS[@]}"; do
        if echo "$DECODED" | grep -qi "$domain" 2>/dev/null; then
          fail "atob() call decodes to telemetry domain: $b64str -> $DECODED"
          B64_FOUND=1
        fi
      done
    done <<< "$B64_LITERALS"
  fi
fi

if [[ $B64_FOUND -eq 0 ]]; then
  pass "No base64-encoded telemetry domains in source"
fi

# --- Check 5: Outbound domain allowlist ---
echo ""
echo "--- 5. Outbound domain allowlist scan ---"

TOTAL=$((TOTAL + 1))

# Known-good domains that rolandcode legitimately contacts
ALLOWED_DOMAINS=(
  "api.openai.com"
  "api.anthropic.com"
  "api.deepseek.com"
  "generativelanguage.googleapis.com"
  "api.groq.com"
  "api.mistral.ai"
  "api.together.xyz"
  "openrouter.ai"
  "api.x.ai"
  "api.fireworks.ai"
  "inference.cerebras.ai"
  "api.sambanova.ai"
  "api.cohere.com"
  "amazonaws.com"
  "openai.azure.com"
  "aiplatform.googleapis.com"
  "github.com"
  "api.github.com"
  "raw.githubusercontent.com"
  "registry.npmjs.org"
  "npmjs.com"
  "localhost"
  "127.0.0.1"
  "0.0.0.0"
  "json-schema.org"
  "schema.org"
  "w3.org"
  "xml.org"
  "mozilla.org"
  "ietf.org"
  "docs."
  "spec."
)

# Extract all URL-like strings from source
# shellcheck disable=SC2086
FOUND_URLS=$(grep -rohP 'https?://[a-zA-Z0-9._-]+[a-zA-Z0-9]' $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null \
  | grep -v "README.md" \
  | sed 's|https\?://||' \
  | sort -u || true)

UNKNOWN_DOMAINS=""
while IFS= read -r domain; do
  [[ -z "$domain" ]] && continue
  ALLOWED=0
  for allowed in "${ALLOWED_DOMAINS[@]}"; do
    if echo "$domain" | grep -qi "$allowed" 2>/dev/null; then
      ALLOWED=1
      break
    fi
  done
  if [[ $ALLOWED -eq 0 ]]; then
    IS_BANNED=0
    for banned in "${DOMAINS[@]}"; do
      if echo "$domain" | grep -qi "$banned" 2>/dev/null; then
        IS_BANNED=1
        break
      fi
    done
    if [[ $IS_BANNED -eq 0 ]]; then
      UNKNOWN_DOMAINS="$UNKNOWN_DOMAINS$domain\n"
    fi
  fi
done <<< "$FOUND_URLS"

if [[ -n "$UNKNOWN_DOMAINS" ]]; then
  warn "Unknown outbound domains found in source (not on allowlist):"
  echo -e "$UNKNOWN_DOMAINS" | sort -u | while read -r d; do
    [[ -z "$d" ]] && continue
    echo "    ? $d"
  done
  pass "Outbound domain scan complete (review warnings above)"
  PASS=$((PASS - 1))  # undo double-count from pass()
else
  pass "All outbound domains on allowlist"
  PASS=$((PASS - 1))
fi

# --- Check 6: Dynamic URL construction (informational) ---
echo ""
echo "--- 6. Dynamic URL construction (informational) ---"

# Look for string concatenation near fetch/http calls that could build telemetry URLs
DYNAMIC_HITS=$(grep -rn 'fetch\s*(' --include="*.ts" --include="*.tsx" --include="*.js" \
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=tests \
  . 2>/dev/null | grep -v "README.md" | grep -c '+' 2>/dev/null || true)

if [[ "$DYNAMIC_HITS" -gt 0 ]]; then
  warn "$DYNAMIC_HITS fetch() calls with string concatenation — review manually"
else
  info "No suspicious dynamic URL construction found"
fi

# --- Check 7: Dynamic execution (informational) ---
echo ""
echo "--- 7. Dynamic execution detection (informational) ---"

for pattern in 'eval(' 'new Function(' 'import('; do
  # shellcheck disable=SC2086
  COUNT=$(grep -rn "$pattern" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | grep -v "README.md" | wc -l || true)
  if [[ "$COUNT" -gt 0 ]]; then
    warn "$COUNT instances of '$pattern' — review for dynamic telemetry loading"
  fi
done

# --- Check 8: Timer patterns near network calls (informational) ---
echo ""
echo "--- 8. Timer/scheduler patterns (informational) ---"

for pattern in 'setInterval(' 'setTimeout('; do
  # shellcheck disable=SC2086
  COUNT=$(grep -rn "$pattern" --include="*.ts" --include="*.tsx" --include="*.js" \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=tests \
    . 2>/dev/null | wc -l || true)
  if [[ "$COUNT" -gt 0 ]]; then
    info "$COUNT instances of '$pattern'"
  fi
done

# --- Check 9: Worker/subprocess detection (informational) ---
echo ""
echo "--- 9. Worker/subprocess detection (informational) ---"

for pattern in 'new Worker(' 'worker_threads' 'child_process'; do
  # shellcheck disable=SC2086
  COUNT=$(grep -rn "$pattern" --include="*.ts" --include="*.tsx" --include="*.js" \
    --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=tests \
    . 2>/dev/null | wc -l || true)
  if [[ "$COUNT" -gt 0 ]]; then
    info "$COUNT instances of '$pattern'"
  fi
done

# --- Summary ---
echo ""
echo "=== Static Analysis Results ==="
echo "Total checks: $TOTAL"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Warnings: $WARN"

if [[ $FAIL -ne 0 ]]; then
  echo -e "${RED}STATIC ANALYSIS FAILED${NC}"
  exit 1
fi

echo -e "${GREEN}STATIC ANALYSIS PASSED${NC}"
exit 0
