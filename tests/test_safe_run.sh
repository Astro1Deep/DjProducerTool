#!/usr/bin/env bash
# Regression: safe_run must propagate command failures without killing caller shell.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROBUST_SCRIPT="$ROOT_DIR/scripts/core/robustness.sh"

if [ ! -f "$ROBUST_SCRIPT" ]; then
  printf "[FAIL] robustness script not found: %s\n" "$ROBUST_SCRIPT"
  exit 1
fi

# shellcheck disable=SC1090
source "$ROBUST_SCRIPT"

set +e
safe_run "expected failure" bash -c 'exit 7'
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  printf "[FAIL] safe_run should return non-zero for failing command\n"
  exit 1
fi
if [ "$rc" -ne 7 ]; then
  printf "[FAIL] expected rc=7 from safe_run, got rc=%s\n" "$rc"
  exit 1
fi

if ! safe_run "expected success" bash -c 'exit 0'; then
  printf "[FAIL] safe_run should return zero for successful command\n"
  exit 1
fi

printf "[PASS] safe_run handles failure/success deterministically\n"
