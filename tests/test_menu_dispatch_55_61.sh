#!/usr/bin/env bash
# Regression: canonical slots 55..61 must dispatch to real actions (not placeholders).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"

if [ ! -f "$APP_SCRIPT" ]; then
  printf "[FAIL] canonical script not found: %s\n" "$APP_SCRIPT"
  exit 1
fi

expected_patterns=(
  '^[[:space:]]*55\) action_55_ableton_tools ;;'
  '^[[:space:]]*56\) action_56_importers ;;'
  '^[[:space:]]*57\) action_57_submenu_excludes ;;'
  '^[[:space:]]*58\) action_58_hash_compare ;;'
  '^[[:space:]]*59\) action_59_health_check ;;'
  '^[[:space:]]*60\) action_60_export_import_config ;;'
  '^[[:space:]]*61\) action_61_mirror_check ;;'
)

for pat in "${expected_patterns[@]}"; do
  if ! rg -n "$pat" "$APP_SCRIPT" >/dev/null; then
    printf "[FAIL] missing dispatch pattern: %s\n" "$pat"
    exit 1
  fi
done

if rg -n 'Slot reservado \[pendiente\]' "$APP_SCRIPT" >/dev/null; then
  printf "[FAIL] slot placeholders still present in app script\n"
  exit 1
fi

if rg -n '^[[:space:]]*(55|56|57|58|59|60|61)\) action_placeholder_generic ;;' "$APP_SCRIPT" >/dev/null; then
  printf "[FAIL] placeholder dispatch still present for slots 55..61\n"
  exit 1
fi

printf "[PASS] slots 55..61 are mapped to concrete handlers\n"
exit 0
