#!/bin/bash
# verify-clean.sh — comprehensive telemetry scan for RolandCode
# Exit 0 = clean, Exit 1 = telemetry found
#
# This is the primary gate — CI runs this on every push and PR.
# Coverage must match or exceed what tests/static/check-source.sh checks.
set -euo pipefail

FAIL=0
TOTAL=0
CLEAN=0

echo "=== RolandCode Telemetry Verification ==="
echo ""

# --- All known telemetry domains ---
# models.dev is NOT in this list — it appears as inert metadata in the vendored
# model catalog (models-snapshot.js, models-api.json), which are excluded from
# the scan. The runtime fetch is verified stripped in check 6 below.
DOMAINS=(
  "posthog"
  "honeycomb"
  "api.opencode.ai"
  "opncd.ai"
  "mcp.exa.ai"
  "opencode.ai/zen"
  "app.opencode.ai"
)

# --- Telemetry SDK imports/requires ---
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

# --- Known-bad environment variables ---
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

# File extensions to scan
INCLUDE_ARGS=""
for ext in ts tsx js jsx go json yaml yml toml; do
  INCLUDE_ARGS="$INCLUDE_ARGS --include=*.$ext"
done

# Directories and files to exclude
# models-api.json is the upstream model catalog fixture — it contains provider
# entries for opencode.ai/zen and other upstream infrastructure that the build
# strips. models-snapshot.js is generated from it at build time (also stripped).
# These are vendored data, not source code.
EXCLUDE_ARGS="--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=vendor --exclude-dir=dist --exclude-dir=build --exclude-dir=tests --exclude=models-snapshot.js --exclude=models-api.json"

# --- 1. Domain checks ---
echo "--- 1. Domain checks (${#DOMAINS[@]} domains) ---"
for pattern in "${DOMAINS[@]}"; do
  TOTAL=$((TOTAL + 1))
  # shellcheck disable=SC2086
  if grep -rn "$pattern" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | grep -v "README.md" | grep -v "CHANGELOG.md" | grep -v "LICENSE"; then
    echo "FAIL: found telemetry domain: $pattern"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: no references to $pattern"
    CLEAN=$((CLEAN + 1))
  fi
  echo ""
done

# --- 2. Import/require audit ---
echo "--- 2. Import/require audit (${#BAD_PACKAGES[@]} packages) ---"
for pkg in "${BAD_PACKAGES[@]}"; do
  TOTAL=$((TOTAL + 1))
  # shellcheck disable=SC2086
  if grep -rn "from ['\"]${pkg}" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | grep -v "README.md"; then
    echo "FAIL: found telemetry import: $pkg"
    FAIL=$((FAIL + 1))
  # shellcheck disable=SC2086
  elif grep -rn "require(['\"]${pkg}" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | grep -v "README.md"; then
    echo "FAIL: found telemetry require: $pkg"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: no imports of $pkg"
    CLEAN=$((CLEAN + 1))
  fi
done
echo ""

# --- 3. Environment variable audit ---
echo "--- 3. Environment variable audit (${#BAD_ENV_VARS[@]} vars) ---"
for var in "${BAD_ENV_VARS[@]}"; do
  TOTAL=$((TOTAL + 1))
  # shellcheck disable=SC2086
  if grep -rn "$var" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null; then
    echo "FAIL: found telemetry env var: $var"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: no references to $var"
    CLEAN=$((CLEAN + 1))
  fi
done
echo ""

# --- 4. Base64-encoded telemetry detection ---
echo "--- 4. Base64 obfuscation scan ---"
TOTAL=$((TOTAL + 1))
B64_FOUND=0

# Check for atob() or Buffer.from() calls containing base64-encoded telemetry domains
BANNED_B64=()
for domain in "us.i.posthog.com" "api.honeycomb.io" "api.opencode.ai" "opncd.ai" "opencode.ai" "mcp.exa.ai" "app.opencode.ai"; do
  BANNED_B64+=("$(echo -n "$domain" | base64)")
done

for b64 in "${BANNED_B64[@]}"; do
  # shellcheck disable=SC2086
  if grep -rn "$b64" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | grep -v "README.md"; then
    echo "FAIL: found base64-encoded telemetry domain: $b64"
    B64_FOUND=1
    FAIL=$((FAIL + 1))
    TOTAL=$((TOTAL - 1))  # avoid double-count
  fi
done

if [[ $B64_FOUND -eq 0 ]]; then
  echo "PASS: no base64-encoded telemetry domains in source"
  CLEAN=$((CLEAN + 1))
fi
echo ""

# --- 5. Outbound domain allowlist ---
echo "--- 5. Outbound domain allowlist scan ---"
TOTAL=$((TOTAL + 1))

# Known-good domains that rolandcode legitimately contacts
ALLOWED_DOMAINS=(
  # LLM providers (user-configured)
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
  # AWS Bedrock
  "amazonaws.com"
  # Azure OpenAI
  "openai.azure.com"
  # Google Vertex
  "aiplatform.googleapis.com"
  # GitHub (for updates, MCP)
  "github.com"
  "api.github.com"
  "raw.githubusercontent.com"
  # npm/package registries
  "registry.npmjs.org"
  "npmjs.com"
  # Standard infra
  "localhost"
  "127.0.0.1"
  "0.0.0.0"
  # Schema/standards
  "json-schema.org"
  "schema.org"
  "w3.org"
  "xml.org"
  "mozilla.org"
  "ietf.org"
  # Documentation URLs (not contacted at runtime)
  "docs."
  "spec."
)

# Extract all URL-like strings from source (excluding node_modules, dist, etc.)
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
    # Double-check it's not a banned domain (those are caught above)
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
  echo "WARNING: Unknown outbound domains found in source (not on allowlist):"
  echo -e "$UNKNOWN_DOMAINS" | sort -u | while read -r d; do
    [[ -z "$d" ]] && continue
    echo "  ? $d"
  done
  echo "  (Review these manually — they may be legitimate or new telemetry)"
  echo "PASS: outbound domain scan complete (warnings above need review)"
  CLEAN=$((CLEAN + 1))
else
  echo "PASS: all outbound domains are on the allowlist"
  CLEAN=$((CLEAN + 1))
fi
echo ""

# --- 6. models.dev runtime fetch strip verification ---
# Instead of scanning for the string "models.dev" (which appears in vendored
# model catalog metadata), verify directly that the runtime fetch is still stripped.
echo "--- 6. models.dev strip verification ---"
TOTAL=$((TOTAL + 1))
MODELS_TS="./packages/opencode/src/provider/models.ts"
if [ ! -f "$MODELS_TS" ]; then
  echo "FAIL: $MODELS_TS not found — cannot verify models.dev strip"
  FAIL=$((FAIL + 1))
elif grep -q "Stripped: no remote model catalog fetch" "$MODELS_TS"; then
  echo "PASS: models.dev runtime fetch is stripped (refresh() is stubbed)"
  CLEAN=$((CLEAN + 1))
else
  echo "FAIL: models.dev runtime fetch may have been reintroduced — refresh() in $MODELS_TS is not stubbed"
  FAIL=$((FAIL + 1))
fi
echo ""

# --- Results ---
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
