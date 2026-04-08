#!/usr/bin/env bash
# Smoke: key AI menu flows must not emit "command not found".

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CANONICAL_SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
failures=0

pass() {
  printf "[PASS] %s\n" "$1"
}

fail() {
  printf "[FAIL] %s\n" "$1"
  failures=$((failures + 1))
}

if [ ! -x "$CANONICAL_SCRIPT" ]; then
  printf "[FAIL] canonical script missing or not executable: %s\n" "$CANONICAL_SCRIPT"
  exit 1
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

run_case() {
  local name="$1"
  local input="$2"
  local log="$tmpdir/${name}.log"

  (
    cd "$ROOT_DIR" || exit 2
    BASE_PATH="$ROOT_DIR" DJPT_NO_INTERACTIVE=1 DJPT_SKIP_MLX=1 bash "$CANONICAL_SCRIPT" >"$log" 2>&1 <<EOF
$input
EOF
  ) &
  local pid=$!
  local timeout=90
  local elapsed=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1
    elapsed=$((elapsed + 1))
    if [ "$elapsed" -ge "$timeout" ]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      fail "${name}: timed out after ${timeout}s"
      return
    fi
  done

  wait "$pid"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "${name}: exited with rc=$rc"
    return
  fi

  if rg -n "command not found|action_ai_backend_supermenu|action_65_submenu_T_tensorflow_lab|ensure_python_package_installed: command not found" "$log" >/dev/null; then
    fail "${name}: unresolved command/function detected"
    return
  fi

  pass "${name}: no unresolved commands"
}

run_case "flow_80_7" $'80\n7\n0\n0\n'
run_case "flow_82_1" $'82\n1\n0\n0\n'
run_case "flow_74_1" $'74\n1\n0\n0\n'
run_case "flow_71_8_4" $'71\n8\n4\n0\n0\n'
run_case "flow_71_8_3_0" $'71\n8\n3\n0\n0\n0\n'

if [ "$failures" -gt 0 ]; then
  printf "[RESULT] %s failures\n" "$failures"
  exit 1
fi

printf "[RESULT] OK\n"
exit 0
