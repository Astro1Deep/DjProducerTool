#!/usr/bin/env bash
# Regression: startup guard behavior and non-interactive double-click style run.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_SCRIPT="$ROOT_DIR/DJProducerTools_Con_Opciones_IA.sh"
TARGET_ES_ROOT="$ROOT_DIR/DJProducerTools_MultiScript_ES.sh"

failures=0

pass() {
  printf "[PASS] %s\n" "$1"
}

fail() {
  printf "[FAIL] %s\n" "$1"
  failures=$((failures + 1))
}

if [ ! -x "$TARGET_SCRIPT" ]; then
  printf "[FAIL] Target script missing or not executable: %s\n" "$TARGET_SCRIPT"
  exit 1
fi

if [ ! -x "$TARGET_ES_ROOT" ]; then
  printf "[FAIL] Target script missing or not executable: %s\n" "$TARGET_ES_ROOT"
  exit 1
fi

tmpdir="$(mktemp -d)"
subdir="$HOME/.djpt_home_subdir_test_$$"
cleanup() {
  rm -rf "$tmpdir" "$subdir"
}
trap cleanup EXIT

mkdir -p "$subdir"

# Case A: HOME exact + absolute path should auto-relocate (Finder behavior).
case_a_log="$tmpdir/case_a.log"
(
  cd "$HOME" || exit 2
  BASE_PATH="$ROOT_DIR" "$TARGET_SCRIPT" --run status --no-interactive >"$case_a_log" 2>&1
)
case_a_rc=$?
if [ "$case_a_rc" -ne 0 ]; then
  fail "Case A: expected startup recovery from HOME with absolute path"
elif grep -q "No ejecutes este script desde HOME" "$case_a_log"; then
  fail "Case A: HOME guard triggered unexpectedly during recovery"
else
  pass "Case A: HOME exact recovers to project root for double-click startup"
fi

# Case B: strict guard mode must still block HOME exact when explicitly requested.
case_b_log="$tmpdir/case_b.log"
(
  cd "$HOME" || exit 2
  BASE_PATH="$ROOT_DIR" DJPT_STRICT_HOME_GUARD=1 "$TARGET_SCRIPT" --run status --no-interactive >"$case_b_log" 2>&1
)
case_b_rc=$?
if [ "$case_b_rc" -eq 0 ]; then
  fail "Case B: strict HOME guard should block exact HOME"
elif ! grep -q "No ejecutes este script desde HOME" "$case_b_log"; then
  fail "Case B: expected strict HOME guard message not found"
else
  pass "Case B: strict HOME guard blocks exact HOME"
fi

# Case C: HOME subdirectory must not trigger false HOME guard.
case_c_log="$tmpdir/case_c.log"
(
  cd "$subdir" || exit 2
  BASE_PATH="$ROOT_DIR" "$TARGET_SCRIPT" --run status --no-interactive >"$case_c_log" 2>&1
)
case_c_rc=$?
if grep -q "No ejecutes este script desde HOME" "$case_c_log"; then
  fail "Case C: HOME subdirectory triggered false positive guard"
elif [ "$case_c_rc" -ne 0 ]; then
  fail "Case C: expected successful non-interactive startup from HOME subdirectory"
else
  pass "Case C: HOME subdirectory does not trigger false guard"
fi

# Case D: non-interactive stdin must not block forever.
case_d_log="$tmpdir/case_d.log"
(
  cd "$ROOT_DIR" || exit 2
  BASE_PATH="$ROOT_DIR" "$TARGET_SCRIPT" --run status --no-interactive </dev/null >"$case_d_log" 2>&1
) &
case_d_pid=$!

case_d_timeout=25
case_d_elapsed=0
while kill -0 "$case_d_pid" 2>/dev/null; do
  sleep 1
  case_d_elapsed=$((case_d_elapsed + 1))
  if [ "$case_d_elapsed" -ge "$case_d_timeout" ]; then
    kill "$case_d_pid" 2>/dev/null || true
    wait "$case_d_pid" 2>/dev/null || true
    fail "Case D: non-interactive run blocked longer than ${case_d_timeout}s"
    break
  fi
done

if [ "$case_d_elapsed" -lt "$case_d_timeout" ]; then
  wait "$case_d_pid"
  case_d_rc=$?
  if [ "$case_d_rc" -ne 0 ]; then
    fail "Case D: non-interactive run exited with error code $case_d_rc"
  else
    pass "Case D: non-interactive run exits without blocking"
  fi
fi

# Case E: root ES wrapper by absolute path from HOME must also recover.
case_e_log="$tmpdir/case_e.log"
(
  cd "$HOME" || exit 2
  BASE_PATH="$ROOT_DIR" "$TARGET_ES_ROOT" --run status --no-interactive >"$case_e_log" 2>&1
)
case_e_rc=$?
if [ "$case_e_rc" -ne 0 ]; then
  fail "Case E: root ES wrapper should recover from HOME with absolute path"
elif grep -q "No ejecutes este script desde HOME" "$case_e_log"; then
  fail "Case E: root ES wrapper triggered false HOME guard"
else
  pass "Case E: root ES wrapper recovers correctly from HOME"
fi

if [ "$failures" -gt 0 ]; then
  printf "[RESULT] %s failures\n" "$failures"
  exit 1
fi

printf "[RESULT] OK\n"
exit 0
