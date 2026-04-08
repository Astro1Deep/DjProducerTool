#!/usr/bin/env bash
set -euo pipefail

# Compatibility wrapper: canonical implementation lives in scripts/.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"

is_root_volume_path() {
  local p="${1%/}"
  [ -z "$p" ] && return 1
  [ "$p" = "/" ] && return 0
  [[ "$p" =~ ^/Volumes/[^/]+$ ]] && return 0
  return 1
}

guard_wrapper_reentry() {
  local current_script stack
  current_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
  stack="${DJPT_ENTRYPOINT_STACK:-}"
  if [[ "$stack" == *"|$current_script|"* ]]; then
    echo "[ERR] Recursive source/exec detected for $current_script" >&2
    exit 1
  fi
  export DJPT_ENTRYPOINT_STACK="${stack}|${current_script}|"
}

if [ ! -x "$TARGET" ]; then
  echo "[ERR] Missing canonical ES menu: $TARGET" >&2
  exit 1
fi

if [[ -z "${BASE_PATH:-}" ]]; then
  echo "[ERR] BASE_PATH is required for safety. Example:" >&2
  echo "      export BASE_PATH=\"$ROOT_DIR\"" >&2
  exit 1
fi

if is_root_volume_path "$BASE_PATH" && [[ "${ALLOW_FULL_VOLUME:-0}" != "1" ]]; then
  echo "[ERR] Refusing root-volume BASE_PATH without ALLOW_FULL_VOLUME=1: $BASE_PATH" >&2
  exit 1
fi

if [ ! -d "$BASE_PATH" ]; then
  echo "[ERR] BASE_PATH does not exist: $BASE_PATH" >&2
  exit 1
fi

guard_wrapper_reentry

exec bash "$TARGET" "$@"
