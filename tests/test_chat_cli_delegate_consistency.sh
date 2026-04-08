#!/usr/bin/env bash
# Regression: scripts/djpt_chat_cli.py must delegate to root djpt_chat_cli.py.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DELEGATE="$ROOT_DIR/scripts/djpt_chat_cli.py"

if [ ! -f "$DELEGATE" ]; then
  printf "[FAIL] delegate script not found: %s\n" "$DELEGATE"
  exit 1
fi

tmp_log="$(mktemp)"
cleanup() {
  rm -f "$tmp_log"
}
trap cleanup EXIT

if ! python3 "$DELEGATE" --help >"$tmp_log" 2>&1; then
  printf "[FAIL] delegate --help exited with non-zero code\n"
  sed -n '1,80p' "$tmp_log"
  exit 1
fi

if rg -n "SyntaxError" "$tmp_log" >/dev/null; then
  printf "[FAIL] delegate output contains SyntaxError\n"
  sed -n '1,80p' "$tmp_log"
  exit 1
fi

if ! rg -n "USO:|python3 djpt_chat_cli.py|DJProducerTools Chat CLI" "$tmp_log" >/dev/null; then
  printf "[FAIL] delegate output missing expected CLI help markers\n"
  sed -n '1,80p' "$tmp_log"
  exit 1
fi

printf "[PASS] chat CLI delegate behavior is consistent\n"
exit 0
