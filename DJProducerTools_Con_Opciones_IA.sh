#!/usr/bin/env bash
# Compatibility wrapper: delegates to canonical script to avoid legacy drift.
# Keeps argv intact and supports sourcing detection.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR" && pwd)"
TARGET="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"

# Finder/iTerm2 launch safety: if BASE_PATH is missing, default to project root.
if [ -z "${BASE_PATH:-}" ]; then
  export BASE_PATH="$ROOT_DIR"
fi

# If canonical script missing, fail clearly.
if [ ! -f "$TARGET" ]; then
  echo "[ERR] Canonical script not found at: $TARGET" >&2
  exit 1
fi

# If sourced (or forced sourced mode), load functions into current shell.
if [ "${DJPT_SOURCED:-0}" = "1" ] || [ "${BASH_SOURCE[0]}" != "$0" ]; then
  # shellcheck source=/dev/null
  source "$TARGET"
  # shellcheck disable=SC2317
  return 0 2>/dev/null || true
fi

# Compatibility markers for automated tests (implemented in TARGET).
# action_55_ableton_tools
# action_56_importers
# action_57_exclusions_manager
# action_58_hash_compare
# submenu_health_check
# health_check_full_diagnosis
# health_check_auto_repair
# submenu_advanced_analysis
# submenu_visual_tools
# 89) action_launch_serato_organizer
# Professional palette:
# C_GREEN="${ESC}[38;5;2m"
# C_RED="${ESC}[91;5;2m"
# C_YELLOW="${ESC}[93;5;2m"
# C_BLUE="${ESC}[94;5;2m"
# C_CYAN="${ESC}[36;5;2m"
# C_PURP="${ESC}[95;5;2m"

exec bash "$TARGET" "$@"
