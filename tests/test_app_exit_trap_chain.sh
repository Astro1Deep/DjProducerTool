#!/usr/bin/env bash
# Regression: canonical script must use a single EXIT trap chain via on_exit_app().

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"

if [ ! -f "$APP_SCRIPT" ]; then
  printf "[FAIL] canonical script not found: %s\n" "$APP_SCRIPT"
  exit 1
fi

trap_lines="$(rg -n '^[[:space:]]*trap .+ EXIT' "$APP_SCRIPT" || true)"
trap_count="$(printf "%s\n" "$trap_lines" | sed '/^$/d' | wc -l | tr -d ' ')"

if [ "$trap_count" -ne 1 ]; then
  printf "[FAIL] expected exactly 1 EXIT trap, found %s\n" "$trap_count"
  printf "%s\n" "$trap_lines"
  exit 1
fi

if ! printf "%s\n" "$trap_lines" | grep -q 'on_exit_app'; then
  printf "[FAIL] EXIT trap does not route through on_exit_app\n"
  printf "%s\n" "$trap_lines"
  exit 1
fi

exit_fn_body="$(awk '/^[[:space:]]*on_exit_app\(\)[[:space:]]*\{/,/^[[:space:]]*\}/ { print }' "$APP_SCRIPT")"
if [ -z "$exit_fn_body" ]; then
  printf "[FAIL] on_exit_app() function not found\n"
  exit 1
fi

if ! printf "%s\n" "$exit_fn_body" | grep -q 'rm -f ".*STATE_DIR'; then
  printf "[FAIL] on_exit_app() missing tmp cleanup\n"
  exit 1
fi

if ! printf "%s\n" "$exit_fn_body" | grep -q 'pause_on_error_exit_app'; then
  printf "[FAIL] on_exit_app() missing pause_on_error_exit_app chain\n"
  exit 1
fi

printf "[PASS] app EXIT trap chain is unified and complete\n"
exit 0
