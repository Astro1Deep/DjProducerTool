#!/usr/bin/env bash
# Regression: sourcing progress.sh must be library-safe by default.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROGRESS_SCRIPT="$ROOT_DIR/progress.sh"

if [ ! -f "$PROGRESS_SCRIPT" ]; then
  printf "[FAIL] progress script not found: %s\n" "$PROGRESS_SCRIPT"
  exit 1
fi

if ! bash -c 'before="$(trap -p EXIT || true)"; source "$1"; after="$(trap -p EXIT || true)"; [ "$before" = "$after" ]' _ "$PROGRESS_SCRIPT"; then
  printf "[FAIL] source progress.sh modified EXIT trap without explicit opt-in\n"
  exit 1
fi

default_out="$(bash -c 'source "$1"; exit 0' _ "$PROGRESS_SCRIPT" 2>&1)"
if [ -n "$default_out" ]; then
  printf "[FAIL] source progress.sh produced EXIT side effects by default: %s\n" "$default_out"
  exit 1
fi

if ! bash -c 'DJPT_PROGRESS_AUTO_TRAP=1; source "$1"; trap -p EXIT | grep -q "cleanup_progress"' _ "$PROGRESS_SCRIPT"; then
  printf "[FAIL] explicit DJPT_PROGRESS_AUTO_TRAP=1 did not install cleanup trap\n"
  exit 1
fi

printf "[PASS] progress.sh is library-safe by default and supports explicit trap opt-in\n"
exit 0
