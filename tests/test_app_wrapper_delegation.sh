#!/usr/bin/env bash
# Regression: app wrapper must delegate to canonical scripts entrypoint.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_WRAPPER="$ROOT_DIR/app/DJProducerTools_MultiScript_ES.sh"
CANONICAL_SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"

if [ ! -f "$APP_WRAPPER" ]; then
  printf "[FAIL] app wrapper not found: %s\n" "$APP_WRAPPER"
  exit 1
fi

if [ ! -x "$APP_WRAPPER" ]; then
  printf "[FAIL] app wrapper not executable: %s\n" "$APP_WRAPPER"
  exit 1
fi

if [ ! -x "$CANONICAL_SCRIPT" ]; then
  printf "[FAIL] canonical script not executable: %s\n" "$CANONICAL_SCRIPT"
  exit 1
fi

if ! rg -n 'TARGET="\$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES\.sh"' "$APP_WRAPPER" >/dev/null; then
  printf "[FAIL] wrapper does not point to canonical script\n"
  exit 1
fi

if ! rg -n 'exec bash "\$TARGET" "\$@"' "$APP_WRAPPER" >/dev/null; then
  printf "[FAIL] wrapper does not exec canonical target\n"
  exit 1
fi

printf "[PASS] app wrapper delegates to canonical script\n"
