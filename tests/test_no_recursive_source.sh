#!/usr/bin/env bash
# Regression: canonical script must not source legacy wrappers during main flow.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"

if [ ! -f "$APP_SCRIPT" ]; then
  printf "[FAIL] canonical script not found: %s\n" "$APP_SCRIPT"
  exit 1
fi

recursive_hits="$(rg -n "source[[:space:]]+.*DJProducerTools_Con_Opciones_IA\.sh" "$APP_SCRIPT" || true)"
via_main_hits="$(rg -n "_via_main" "$APP_SCRIPT" || true)"

if [ -n "$recursive_hits" ]; then
  printf "[FAIL] recursive source found in app script:\n%s\n" "$recursive_hits"
  exit 1
fi

if [ -n "$via_main_hits" ]; then
  printf "[FAIL] leftover *_via_main calls found in app script:\n%s\n" "$via_main_hits"
  exit 1
fi

printf "[PASS] no recursive source and no *_via_main coupling\n"
exit 0
