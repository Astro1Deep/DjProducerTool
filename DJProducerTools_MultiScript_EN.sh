#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/scripts/DJProducerTools_MultiScript_EN.sh"

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
  echo "[ERR] Missing canonical EN menu: $TARGET" >&2
  exit 1
fi

if [[ -z "${BASE_PATH:-}" ]]; then
  if [ -t 0 ] || [ -t 1 ]; then
    BASE_PATH="$SCRIPT_DIR"
    export BASE_PATH
    echo "[INFO] BASE_PATH not set. Using project root: $BASE_PATH" >&2
  else
    echo "[ERR] BASE_PATH is required for safety. Example:" >&2
    echo "      export BASE_PATH=\"$SCRIPT_DIR\"" >&2
    exit 1
  fi
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
