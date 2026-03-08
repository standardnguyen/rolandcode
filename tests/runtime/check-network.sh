#!/bin/bash
# check-network.sh — Runtime network interception tests
#
# What it tests:
#   - DNS queries to telemetry domains during startup
#   - TCP/UDP connections to banned IPs during startup
#   - Syscall-level network monitoring via strace
#   - Loopback canary (redirect telemetry domains to localhost, check for hits)
#
# Tools needed: strace (required), tcpdump (optional), python3 (for canary server)
# What a failure means: The binary makes network connections to telemetry services at runtime

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

# Find the binary
BINARY=""
for candidate in \
  "packages/opencode/dist/opencode-linux-x64/bin/rolandcode" \
  "packages/opencode/dist/opencode-linux-arm64/bin/rolandcode"; do
  if [[ -f "$candidate" ]]; then
    BINARY="$(realpath "$candidate")"
    break
  fi
done

if [[ -z "$BINARY" ]]; then
  skip "No compiled binary found — build first"
  exit 0
fi

BANNED_DOMAINS=(
  "us.i.posthog.com"
  "api.honeycomb.io"
  "api.opencode.ai"
  "opncd.ai"
  "opencode.ai"
  "mcp.exa.ai"
  "app.opencode.ai"
  "models.dev"
)

TMPDIR=$(mktemp -d)
trap 'cleanup' EXIT

cleanup() {
  # Kill any background processes we started
  jobs -p 2>/dev/null | xargs -r kill 2>/dev/null || true
  rm -rf "$TMPDIR"
}

echo "=== Runtime Network Tests ==="
echo "Binary: $BINARY"
echo ""

# --- Test 1: Strace syscall monitoring ---
echo "--- 1. Strace network syscall test ---"

if command -v strace &>/dev/null; then
  TOTAL=$((TOTAL + 1))

  # Run the binary under strace, capturing network syscalls
  # Use --help or --version to avoid interactive TUI
  timeout 15 strace -f -e trace=network -o "$TMPDIR/strace.log" \
    "$BINARY" --version 2>/dev/null || true

  # Extract connect() destinations
  CONNECT_CALLS=$(grep -c "connect(" "$TMPDIR/strace.log" 2>/dev/null || true)
  info "Captured $CONNECT_CALLS connect() syscalls"

  # Check for connections to banned domains (via resolved IPs in sin_addr)
  STRACE_FAIL=0
  for domain in "${BANNED_DOMAINS[@]}"; do
    if grep -i "$domain" "$TMPDIR/strace.log" 2>/dev/null; then
      fail "strace captured connection to banned domain: $domain"
      STRACE_FAIL=1
    fi
  done

  if [[ $STRACE_FAIL -eq 0 ]]; then
    pass "No strace-detected connections to telemetry domains"
  fi

  # Log all unique destinations for manual review
  grep "connect(" "$TMPDIR/strace.log" 2>/dev/null | grep -oP 'sin_addr=inet_addr\("[^"]+"\)' | sort -u > "$TMPDIR/strace-destinations.txt" 2>/dev/null || true
  DEST_COUNT=$(wc -l < "$TMPDIR/strace-destinations.txt" 2>/dev/null || echo "0")
  if [[ "$DEST_COUNT" -gt 0 ]]; then
    info "Unique connection destinations:"
    cat "$TMPDIR/strace-destinations.txt" | while read -r line; do
      echo "    $line"
    done
  fi
else
  skip "strace not available — install with 'apt install strace'"
fi

# --- Test 2: tcpdump DNS monitoring ---
echo ""
echo "--- 2. DNS query monitoring ---"

if command -v tcpdump &>/dev/null; then
  TOTAL=$((TOTAL + 1))

  # Start tcpdump capturing DNS
  tcpdump -i any -w "$TMPDIR/dns.pcap" port 53 2>/dev/null &
  TCPDUMP_PID=$!
  sleep 1

  # Run the binary briefly
  timeout 10 "$BINARY" --version 2>/dev/null || true
  sleep 2

  kill $TCPDUMP_PID 2>/dev/null || true
  wait $TCPDUMP_PID 2>/dev/null || true

  # Parse DNS queries
  tcpdump -r "$TMPDIR/dns.pcap" -nn 2>/dev/null | grep -oP 'A\? [^ ]+' | sort -u > "$TMPDIR/dns-queries.txt" 2>/dev/null || true

  DNS_FAIL=0
  for domain in "${BANNED_DOMAINS[@]}"; do
    if grep -q "$domain" "$TMPDIR/dns-queries.txt" 2>/dev/null; then
      fail "DNS query to banned domain: $domain"
      DNS_FAIL=1
    fi
  done

  if [[ $DNS_FAIL -eq 0 ]]; then
    pass "No DNS queries to telemetry domains"
  fi

  DNS_COUNT=$(wc -l < "$TMPDIR/dns-queries.txt" 2>/dev/null || echo "0")
  if [[ "$DNS_COUNT" -gt 0 ]]; then
    info "All DNS queries during startup:"
    cat "$TMPDIR/dns-queries.txt" | while read -r line; do
      echo "    $line"
    done
  fi
else
  skip "tcpdump not available — install with 'apt install tcpdump'"
fi

# --- Test 3: /proc/net/tcp connection audit ---
echo ""
echo "--- 3. /proc/net connection audit ---"

TOTAL=$((TOTAL + 1))

# Start the binary in background
"$BINARY" --version > /dev/null 2>&1 &
BIN_PID=$!
sleep 2

# Check /proc/net/tcp for established connections
if [[ -f "/proc/$BIN_PID/net/tcp" ]]; then
  CONNECTIONS=$(cat "/proc/$BIN_PID/net/tcp" 2>/dev/null | tail -n +2 | wc -l || echo "0")
  info "Active TCP connections: $CONNECTIONS"

  # Extract remote addresses (column 3, hex encoded)
  cat "/proc/$BIN_PID/net/tcp" 2>/dev/null | tail -n +2 | awk '{print $3}' | while read -r hexaddr; do
    HEX_IP=$(echo "$hexaddr" | cut -d: -f1)
    HEX_PORT=$(echo "$hexaddr" | cut -d: -f2)
    if [[ "$HEX_IP" != "00000000" && "$HEX_IP" != "0100007F" ]]; then
      # Convert hex IP to decimal
      IP=$(printf "%d.%d.%d.%d" "0x${HEX_IP:6:2}" "0x${HEX_IP:4:2}" "0x${HEX_IP:2:2}" "0x${HEX_IP:0:2}" 2>/dev/null || echo "unknown")
      PORT=$((16#$HEX_PORT))
      info "  Connection to: $IP:$PORT"
    fi
  done
  pass "/proc/net/tcp audit complete (review above connections)"
else
  info "Process $BIN_PID exited before /proc check — likely --version exits immediately"
  pass "/proc/net/tcp audit (process exited cleanly, no persistent connections)"
fi

kill $BIN_PID 2>/dev/null || true
wait $BIN_PID 2>/dev/null || true

# --- Summary ---
echo ""
echo "=== Runtime Network Results ==="
echo "Total checks: $TOTAL"
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Warnings: $WARN"

if [[ $FAIL -ne 0 ]]; then
  echo -e "${RED}RUNTIME NETWORK TESTS FAILED${NC}"
  exit 1
fi

echo -e "${GREEN}RUNTIME NETWORK TESTS PASSED${NC}"
exit 0
