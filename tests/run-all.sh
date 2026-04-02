#!/bin/bash
# run-all.sh — Master test runner for RolandCode verification
#
# Usage:
#   ./tests/run-all.sh              # Run all available tests
#   ./tests/run-all.sh --quick      # Static + deps + supply-chain only
#   ./tests/run-all.sh --full       # Everything including soak test
#   ./tests/run-all.sh --no-color   # No ANSI colors (for CI)
#
# Flags:
#   --skip-runtime      Skip runtime network tests
#   --skip-build        Skip build and binary tests
#   --skip-mutation     Skip mutation tests (slow)
#   --skip-behavioral   Skip behavioral tests
#   --skip-binary       Skip binary forensics
#   --skip-snapshot     Skip snapshot comparison
#   --quick             Only static + deps + supply-chain
#   --full              Run everything
#   --no-color          Disable color output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse flags
SKIP_RUNTIME=0
SKIP_BUILD=0
SKIP_MUTATION=0
SKIP_BEHAVIORAL=0
SKIP_BINARY=0
SKIP_SNAPSHOT=0
NO_COLOR_FLAG=""

for arg in "$@"; do
  case "$arg" in
    --skip-runtime)    SKIP_RUNTIME=1 ;;
    --skip-build)      SKIP_BUILD=1; SKIP_BINARY=1 ;;
    --skip-mutation)   SKIP_MUTATION=1 ;;
    --skip-behavioral) SKIP_BEHAVIORAL=1 ;;
    --skip-binary)     SKIP_BINARY=1 ;;
    --skip-snapshot)   SKIP_SNAPSHOT=1 ;;
    --quick)           SKIP_RUNTIME=1; SKIP_BUILD=1; SKIP_MUTATION=1; SKIP_BEHAVIORAL=1; SKIP_BINARY=1; SKIP_SNAPSHOT=1 ;;
    --full)            ;; # run everything
    --no-color)        NO_COLOR_FLAG="--no-color"; export NO_COLOR=1 ;;
  esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'
if [[ "${NO_COLOR:-}" == "1" ]]; then
  RED="" GREEN="" YELLOW="" BOLD="" NC=""
fi

cd "$REPO_ROOT"

echo -e "${BOLD}=== RolandCode Verification Suite ===${NC}"
echo ""

declare -A RESULTS
OVERALL_PASS=0
OVERALL_FAIL=0
OVERALL_SKIP=0

run_level() {
  local NAME="$1"
  local SCRIPT="$2"
  local SKIP="$3"

  if [[ "$SKIP" -eq 1 ]]; then
    RESULTS["$NAME"]="SKIP"
    OVERALL_SKIP=$((OVERALL_SKIP + 1))
    echo -e "${YELLOW}SKIP${NC}: $NAME"
    echo ""
    return
  fi

  if [[ ! -f "$SCRIPT" ]]; then
    RESULTS["$NAME"]="SKIP (not found)"
    OVERALL_SKIP=$((OVERALL_SKIP + 1))
    echo -e "${YELLOW}SKIP${NC}: $NAME (script not found)"
    echo ""
    return
  fi

  echo -e "${BOLD}--- $NAME ---${NC}"
  if bash "$SCRIPT" $NO_COLOR_FLAG; then
    RESULTS["$NAME"]="PASS"
    OVERALL_PASS=$((OVERALL_PASS + 1))
  else
    RESULTS["$NAME"]="FAIL"
    OVERALL_FAIL=$((OVERALL_FAIL + 1))
  fi
  echo ""
}

# Run each level
run_level "Static analysis"    "$SCRIPT_DIR/static/check-source.sh"         0
run_level "Dependency audit"   "$SCRIPT_DIR/deps/check-deps.sh"             0
run_level "Supply chain"       "$SCRIPT_DIR/supply-chain/check-supply-chain.sh" 0
run_level "Binary forensics"   "$SCRIPT_DIR/binary/check-binary.sh"         $SKIP_BINARY
run_level "Runtime network"    "$SCRIPT_DIR/runtime/check-network.sh"       $SKIP_RUNTIME
run_level "Behavioral"         "$SCRIPT_DIR/behavioral/check-behavior.sh"   $SKIP_BEHAVIORAL
run_level "Mutation testing"   "$SCRIPT_DIR/mutation/check-mutations.sh"     $SKIP_MUTATION
run_level "Snapshot comparison" "$SCRIPT_DIR/snapshots/compare-snapshot.sh"  $SKIP_SNAPSHOT

# Summary
echo -e "${BOLD}=== RolandCode Verification Report ===${NC}"

LEVELS=("Static analysis" "Dependency audit" "Supply chain" "Binary forensics" "Runtime network" "Behavioral" "Mutation testing" "Snapshot comparison")

for level in "${LEVELS[@]}"; do
  STATUS="${RESULTS[$level]:-SKIP}"
  case "$STATUS" in
    PASS)  echo -e "  $level: ${GREEN}PASS${NC}" ;;
    FAIL)  echo -e "  $level: ${RED}FAIL${NC}" ;;
    SKIP*) echo -e "  $level: ${YELLOW}$STATUS${NC}" ;;
  esac
done

echo ""
echo "Passed: $OVERALL_PASS"
echo "Failed: $OVERALL_FAIL"
echo "Skipped: $OVERALL_SKIP"
echo ""

if [[ $OVERALL_FAIL -gt 0 ]]; then
  echo -e "${RED}${BOLD}VERIFICATION FAILED${NC}"
  exit 1
fi

echo -e "${GREEN}${BOLD}VERIFICATION PASSED${NC}"
exit 0
