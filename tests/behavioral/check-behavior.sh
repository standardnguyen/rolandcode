#!/bin/bash
# check-behavior.sh — Behavioral analysis: file system, fingerprinting, process tree
#
# What it tests:
#   - Files created/modified during binary execution
#   - Persistent tracking IDs / UUIDs in created files
#   - Machine fingerprinting code in source
#   - Process tree monitoring for child processes
#
# Tools needed: inotifywait (optional, from inotify-tools)
# What a failure means: The binary writes tracking data or spawns suspicious child processes

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
skip() { echo -e "${YELLOW}SKIP${NC}: $1"; }

cd "$REPO_ROOT"

INCLUDE_ARGS=""
for ext in ts tsx js jsx; do
  INCLUDE_ARGS="$INCLUDE_ARGS --include=*.$ext"
done
EXCLUDE_ARGS="--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=tests"

echo "=== Behavioral Analysis ==="
echo ""

# --- Check 1: Machine fingerprinting in source ---
echo "--- 1. Machine fingerprinting detection ---"

TOTAL=$((TOTAL + 1))
FINGERPRINT_PATTERNS=(
  "os.hostname()"
  "os.networkInterfaces()"
  "os.userInfo()"
  "/etc/machine-id"
  "/var/lib/dbus/machine-id"
  "getMACAddress"
  "getmac"
)

# These are OK (used for feature detection, not telemetry):
# os.platform(), os.arch(), os.cpus() — common in build tools

FP_SUSPICIOUS=0
for pattern in "${FINGERPRINT_PATTERNS[@]}"; do
  # shellcheck disable=SC2086
  HITS=$(grep -rn "$pattern" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | wc -l || true)
  if [[ "$HITS" -gt 0 ]]; then
    warn "Found $HITS references to fingerprinting pattern: $pattern"
    # shellcheck disable=SC2086
    grep -rn "$pattern" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | head -3 | while read -r line; do
      echo "    $line"
    done
  fi
done

# Check for UUID generation that could be used for persistent tracking
# shellcheck disable=SC2086
UUID_HITS=$(grep -rn "randomUUID\|uuid\|nanoid" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | grep -v "test" | grep -v "spec" | wc -l || true)
if [[ "$UUID_HITS" -gt 0 ]]; then
  info "$UUID_HITS UUID/nanoid references in source (review for persistent tracking IDs)"
fi

pass "Fingerprinting audit complete (review warnings above)"

# --- Check 2: Telemetry-related file paths in source ---
echo ""
echo "--- 2. Telemetry state file detection ---"

TOTAL=$((TOTAL + 1))

TELEMETRY_FILES=(
  ".posthog"
  "posthog-queue"
  "posthog.init"
  "analytics.json"
  "telemetry.json"
  "/.analytics"
  "/.telemetry"
  "/.sentry"
)

# These are file path patterns for telemetry state files written to disk.
# We search for path-like references (with slashes or dots as path separators),
# not bare words like "analytics" or "telemetry" which appear in legitimate contexts
# (privacy policy prose, AI SDK experimental_telemetry flag, etc.)

TF_FOUND=0
for pattern in "${TELEMETRY_FILES[@]}"; do
  # shellcheck disable=SC2086
  if grep -rn "$pattern" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | grep -v "README" | grep -v "CHANGELOG"; then
    fail "Source references telemetry state file: $pattern"
    TF_FOUND=1
  fi
done

if [[ $TF_FOUND -eq 0 ]]; then
  pass "No telemetry state file references in source"
fi

# --- Check 3: Clipboard/history access ---
echo ""
echo "--- 3. Privacy-sensitive data access ---"

TOTAL=$((TOTAL + 1))

PRIVACY_PATTERNS=(
  "xclip"
  "xsel"
  "pbpaste"
  "pbcopy"
  ".bash_history"
  ".zsh_history"
  "clipboard"
)

PRIV_SUSPICIOUS=0
for pattern in "${PRIVACY_PATTERNS[@]}"; do
  # shellcheck disable=SC2086
  HITS=$(grep -rn "$pattern" $INCLUDE_ARGS $EXCLUDE_ARGS . 2>/dev/null | grep -v "README" | wc -l || true)
  if [[ "$HITS" -gt 0 ]]; then
    # Clipboard access is legitimate for a code editor — just log it
    info "$HITS references to '$pattern'"
  fi
done

pass "Privacy access audit complete"

# --- Check 4: Process tree (requires binary) ---
echo ""
echo "--- 4. Process tree monitoring ---"

BINARY=""
for candidate in \
  "packages/opencode/dist/opencode-linux-x64/bin/rolandcode" \
  "packages/opencode/dist/opencode-linux-arm64/bin/rolandcode"; do
  if [[ -f "$candidate" ]]; then
    BINARY="$(realpath "$candidate")"
    break
  fi
done

if [[ -n "$BINARY" ]]; then
  TOTAL=$((TOTAL + 1))

  # Run binary briefly and capture process tree
  "$BINARY" --version > /dev/null 2>&1 &
  BIN_PID=$!
  sleep 1

  if kill -0 $BIN_PID 2>/dev/null; then
    # Process is still running — check its children
    CHILDREN=$(ls /proc/$BIN_PID/task/ 2>/dev/null | wc -l || echo "1")
    info "Process $BIN_PID has $CHILDREN threads"

    # Check for child processes
    CHILD_PIDS=$(pgrep -P $BIN_PID 2>/dev/null || true)
    if [[ -n "$CHILD_PIDS" ]]; then
      info "Child processes spawned:"
      for cpid in $CHILD_PIDS; do
        CMDLINE=$(tr '\0' ' ' < "/proc/$cpid/cmdline" 2>/dev/null || echo "unknown")
        info "  PID $cpid: $CMDLINE"
      done
    fi

    kill $BIN_PID 2>/dev/null || true
    wait $BIN_PID 2>/dev/null || true
  fi

  pass "Process tree audit complete"
else
  skip "No binary found for process tree monitoring"
fi

# --- Check 5: Config directory creation audit ---
echo ""
echo "--- 5. Config directory audit ---"

if [[ -n "$BINARY" ]]; then
  TOTAL=$((TOTAL + 1))

  # Create isolated home
  TEST_HOME=$(mktemp -d)
  trap 'rm -rf "$TEST_HOME" "$TMPDIR" 2>/dev/null; jobs -p 2>/dev/null | xargs -r kill 2>/dev/null || true' EXIT
  TMPDIR=$(mktemp -d)

  # Snapshot before
  find "$TEST_HOME" -type f 2>/dev/null | sort > "$TMPDIR/before.txt"

  # Run with isolated home
  HOME="$TEST_HOME" timeout 5 "$BINARY" --version 2>/dev/null || true

  # Snapshot after
  find "$TEST_HOME" -type f 2>/dev/null | sort > "$TMPDIR/after.txt"

  # Diff
  NEW_FILES=$(comm -13 "$TMPDIR/before.txt" "$TMPDIR/after.txt" 2>/dev/null || true)
  if [[ -n "$NEW_FILES" ]]; then
    info "Files created during execution:"
    echo "$NEW_FILES" | while read -r f; do
      SIZE=$(stat -c%s "$f" 2>/dev/null || echo "?")
      echo "    $f ($SIZE bytes)"
      # Check for tracking IDs
      if grep -qP '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$f" 2>/dev/null; then
        warn "File contains UUID (potential tracking ID): $f"
      fi
    done
  else
    info "No files created during --version execution"
  fi

  pass "Config directory audit complete"
fi

# --- Summary ---
echo ""
echo "=== Behavioral Analysis Results ==="
echo "Total checks: $TOTAL"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Warnings: $WARN"

if [[ $FAIL -ne 0 ]]; then
  echo -e "${RED}BEHAVIORAL ANALYSIS FAILED${NC}"
  exit 1
fi

echo -e "${GREEN}BEHAVIORAL ANALYSIS PASSED${NC}"
exit 0
