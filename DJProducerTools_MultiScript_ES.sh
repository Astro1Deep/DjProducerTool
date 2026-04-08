#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$SCRIPT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"

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

ensure_safe_base_path() {
  if [[ -z "${BASE_PATH:-}" ]]; then
    if [ -t 0 ] || [ -t 1 ]; then
      BASE_PATH="$SCRIPT_DIR"
      export BASE_PATH
      echo "[INFO] BASE_PATH not set. Using project root: $BASE_PATH" >&2
    else
      echo "[ERR] BASE_PATH is required for safety. Example:" >&2
      echo "      export BASE_PATH=\"$SCRIPT_DIR\"" >&2
      return 1
    fi
  fi

  if is_root_volume_path "$BASE_PATH" && [[ "${ALLOW_FULL_VOLUME:-0}" != "1" ]]; then
    echo "[ERR] Refusing root-volume BASE_PATH without ALLOW_FULL_VOLUME=1: $BASE_PATH" >&2
    return 1
  fi

  if [ ! -d "$BASE_PATH" ]; then
    echo "[ERR] BASE_PATH does not exist: $BASE_PATH" >&2
    return 1
  fi

  return 0
}

run_canonical_action() {
  local action_number="$1"
  shift || true

  ensure_safe_base_path
  guard_wrapper_reentry
  exec bash "$TARGET" --run "$action_number" "$@"
}

# Real wrappers for deep options 40-52 so they are callable from this entrypoint.
action_40() { run_canonical_action 40 "$@"; }
action_41() { run_canonical_action 41 "$@"; }
action_42() { run_canonical_action 42 "$@"; }
action_43() { run_canonical_action 43 "$@"; }
action_44() { run_canonical_action 44 "$@"; }
action_45() { run_canonical_action 45 "$@"; }
action_46() { run_canonical_action 46 "$@"; }
action_47() { run_canonical_action 47 "$@"; }
action_48() { run_canonical_action 48 "$@"; }
action_49() { run_canonical_action 49 "$@"; }
action_50() { run_canonical_action 50 "$@"; }
action_51() { run_canonical_action 51 "$@"; }
action_52() { run_canonical_action 52 "$@"; }

if [ ! -x "$TARGET" ]; then
  echo "[ERR] Missing canonical ES menu: $TARGET" >&2
  exit 1
fi

if [[ $# -gt 0 ]]; then
  case "$1" in
    40|41|42|43|44|45|46|47|48|49|50|51|52)
      selected_action="$1"
      shift
      "action_${selected_action}" "$@"
      ;;
    action_40|action_41|action_42|action_43|action_44|action_45|action_46|action_47|action_48|action_49|action_50|action_51|action_52)
      selected_fn="$1"
      shift
      "$selected_fn" "$@"
      ;;
  esac
fi

ensure_safe_base_path

guard_wrapper_reentry

exec bash "$TARGET" "$@"
