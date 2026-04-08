#!/usr/bin/env bash
# Regression: ai install-deps must fallback editable -> requirements deterministically.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REQ_FILE="$ROOT_DIR/requirements.txt"

if [ ! -f "$REQ_FILE" ]; then
  printf "[FAIL] requirements.txt missing: %s\n" "$REQ_FILE"
  exit 1
fi

if ! python3 -c "import typer" >/dev/null 2>&1; then
  printf "[SKIP] typer no disponible en python3 global; omitiendo test ai install-deps path\n"
  exit 0
fi

run_cmd() {
  (
    cd "$ROOT_DIR" || exit 2
    DJPT_PIP_INSTALL_MOCK_EDITABLE_RC="$1" \
    DJPT_PIP_INSTALL_MOCK_REQUIREMENTS_RC="$2" \
    python3 -m scripts.cli ai install-deps
  )
}

out_ok="$(run_cmd 1 0 2>&1)"
rc_ok=$?
if [ "$rc_ok" -ne 0 ]; then
  printf "[FAIL] expected fallback success, got rc=%s\n" "$rc_ok"
  printf "%s\n" "$out_ok"
  exit 1
fi

if ! printf "%s\n" "$out_ok" | grep -q "intento: editable extras"; then
  printf "[FAIL] missing editable attempt log\n"
  printf "%s\n" "$out_ok"
  exit 1
fi

if ! printf "%s\n" "$out_ok" | grep -q "intento: requirements.txt"; then
  printf "[FAIL] missing requirements fallback log\n"
  printf "%s\n" "$out_ok"
  exit 1
fi

out_fail="$(run_cmd 1 1 2>&1)"
rc_fail=$?
if [ "$rc_fail" -eq 0 ]; then
  printf "[FAIL] expected non-zero rc when both attempts fail\n"
  printf "%s\n" "$out_fail"
  exit 1
fi

printf "[PASS] ai install-deps fallback path is deterministic\n"
exit 0
