#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$TEST_DIR")"
BIN="$ROOT_DIR/bin/djpt"

C_RED='\033[1;31m'
C_GRN='\033[1;32m'
C_RESET='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo "  ${C_GRN}PASS${C_RESET} $1"; TESTS_PASSED=$((TESTS_PASSED+1)); }
fail() { echo "  ${C_RED}FAIL${C_RESET} $1"; TESTS_FAILED=$((TESTS_FAILED+1)); }

run_test() {
  local name="$1"; shift
  TESTS_RUN=$((TESTS_RUN+1))
  if "$@"; then pass "$name"; else fail "$name"; fi
}

run_test "bin/djpt exists" test -x "$BIN"
run_test "cli --help works" "$BIN" --help >/dev/null
run_test "Config paths avoid matrioshka" bash -c 'python3 - <<\"PY\"\nfrom scripts.core.config import Config\nassert \"_DJProducerTools/_DJProducerTools\" not in str(Config.STATE_DIR)\nPY'

echo "Summary: $TESTS_RUN run, $TESTS_PASSED passed, $TESTS_FAILED failed"
if [ "$TESTS_FAILED" -gt 0 ]; then exit 1; fi
