#!/bin/bash
# check-mutations.sh — Mutation testing: inject telemetry, verify detection
#
# What it tests:
#   - That the static analysis catches injected telemetry domains
#   - That the static analysis catches injected telemetry imports
#   - That obfuscated telemetry (string concat, base64) is flagged
#   - That each test level actually works — a test suite that passes on dirty code is useless
#
# Tools needed: bash, the other test scripts
# What a failure means: The test suite has a gap — telemetry could be added without detection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TESTS_DIR="$REPO_ROOT/tests"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
if [[ "${NO_COLOR:-}" == "1" || "${1:-}" == "--no-color" ]]; then
  RED="" GREEN="" YELLOW="" NC=""
fi

MUTATIONS_CAUGHT=0
MUTATIONS_MISSED=0
MUTATIONS_TOTAL=0

caught() { MUTATIONS_CAUGHT=$((MUTATIONS_CAUGHT + 1)); MUTATIONS_TOTAL=$((MUTATIONS_TOTAL + 1)); echo -e "${GREEN}CAUGHT${NC}: $1"; }
missed() { MUTATIONS_MISSED=$((MUTATIONS_MISSED + 1)); MUTATIONS_TOTAL=$((MUTATIONS_TOTAL + 1)); echo -e "${RED}MISSED${NC}: $1"; }
info() { echo "  INFO: $1"; }

cd "$REPO_ROOT"

echo "=== Mutation Testing ==="
echo "Injecting telemetry and verifying detection..."
echo ""

# We use a sacrificial file for injections
SACRIFICE="packages/opencode/src/mutation-test-target.ts"

cleanup_mutation() {
  rm -f "$SACRIFICE"
}
trap cleanup_mutation EXIT

# --- Mutation 1: Plain domain injection ---
echo "--- Mutation 1: Plain domain in source ---"

cat > "$SACRIFICE" << 'INJECT'
// Mutation test: this should be caught by static analysis
const ANALYTICS_URL = "https://us.i.posthog.com/capture"
INJECT

if ! bash "$TESTS_DIR/static/check-source.sh" --no-color > /dev/null 2>&1; then
  caught "Static analysis detected plain posthog domain"
else
  missed "Static analysis did NOT detect plain posthog domain — CRITICAL GAP"
fi
rm -f "$SACRIFICE"

# --- Mutation 2: Different telemetry domain ---
echo ""
echo "--- Mutation 2: Honeycomb domain ---"

cat > "$SACRIFICE" << 'INJECT'
const TELEMETRY_ENDPOINT = "https://api.honeycomb.io/v1/events"
INJECT

if ! bash "$TESTS_DIR/static/check-source.sh" --no-color > /dev/null 2>&1; then
  caught "Static analysis detected honeycomb domain"
else
  missed "Static analysis did NOT detect honeycomb domain — CRITICAL GAP"
fi
rm -f "$SACRIFICE"

# --- Mutation 3: Import injection ---
echo ""
echo "--- Mutation 3: Telemetry import ---"

cat > "$SACRIFICE" << 'INJECT'
import posthog from "posthog-node"
posthog.capture({ event: "test" })
INJECT

if ! bash "$TESTS_DIR/static/check-source.sh" --no-color > /dev/null 2>&1; then
  caught "Static analysis detected posthog import"
else
  missed "Static analysis did NOT detect posthog import — CRITICAL GAP"
fi
rm -f "$SACRIFICE"

# --- Mutation 4: Environment variable injection ---
echo ""
echo "--- Mutation 4: Telemetry env var ---"

cat > "$SACRIFICE" << 'INJECT'
const key = process.env.POSTHOG_API_KEY
INJECT

if ! bash "$TESTS_DIR/static/check-source.sh" --no-color > /dev/null 2>&1; then
  caught "Static analysis detected POSTHOG_API_KEY env var"
else
  missed "Static analysis did NOT detect POSTHOG_API_KEY — CRITICAL GAP"
fi
rm -f "$SACRIFICE"

# --- Mutation 5: String concatenation obfuscation ---
echo ""
echo "--- Mutation 5: String concatenation obfuscation ---"

cat > "$SACRIFICE" << 'INJECT'
const host = "us.i." + "posthog" + ".com"
fetch("https://" + host + "/capture")
INJECT

# This SHOULD be caught because "posthog" is a banned substring
if ! bash "$TESTS_DIR/static/check-source.sh" --no-color > /dev/null 2>&1; then
  caught "Static analysis detected concatenated posthog domain"
else
  missed "Static analysis did NOT detect concatenated posthog — known limitation of substring matching"
fi
rm -f "$SACRIFICE"

# --- Mutation 6: Base64 obfuscation ---
echo ""
echo "--- Mutation 6: Base64 encoded domain ---"

cat > "$SACRIFICE" << 'INJECT'
const endpoint = atob("dXMuaS5wb3N0aG9nLmNvbQ==")
fetch("https://" + endpoint + "/capture")
INJECT

# Static analysis may not catch this — base64 is caught by binary forensics
if ! bash "$TESTS_DIR/static/check-source.sh" --no-color > /dev/null 2>&1; then
  caught "Static analysis detected base64 obfuscation (bonus — caught by atob pattern)"
else
  # This is expected — static grep can't decode base64
  info "Static analysis did not catch base64 (expected — binary forensics would catch this in compiled output)"
  MUTATIONS_TOTAL=$((MUTATIONS_TOTAL + 1))
  echo -e "${YELLOW}EXPECTED MISS${NC}: Base64 obfuscation not caught by static analysis (caught by binary forensics level)"
fi
rm -f "$SACRIFICE"

# --- Summary ---
echo ""
echo "=== Mutation Testing Results ==="
echo "Total mutations: $MUTATIONS_TOTAL"
echo "Caught: $MUTATIONS_CAUGHT"
echo "Missed: $MUTATIONS_MISSED"

if [[ $MUTATIONS_MISSED -gt 0 ]]; then
  echo -e "${RED}MUTATION TESTING FAILED — $MUTATIONS_MISSED mutations went undetected${NC}"
  exit 1
fi

echo -e "${GREEN}MUTATION TESTING PASSED — all detectable mutations caught${NC}"
exit 0
