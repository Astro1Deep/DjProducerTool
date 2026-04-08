#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"

if [ ! -x "$SCRIPT" ]; then
  echo "[FAIL] Script not executable: $SCRIPT" >&2
  exit 1
fi

run_case() {
  local name="$1"
  local input="$2"
  local out
  out="$(mktemp)"

  local timeout_bin=""
  if command -v timeout >/dev/null 2>&1; then
    timeout_bin="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    timeout_bin="gtimeout"
  fi

  if [ -n "$timeout_bin" ]; then
    # shellcheck disable=SC2086
    NO_INTERACTIVE=1 DJPT_SKIP_MLX=1 $timeout_bin 25 bash "$SCRIPT" >"$out" 2>&1 <<<"$input" || true
  else
    NO_INTERACTIVE=1 DJPT_SKIP_MLX=1 bash "$SCRIPT" >"$out" 2>&1 <<<"$input" || true
  fi

  if rg -q "\[ERR\] Opción inválida|Opción no válida|Invalid option" "$out"; then
    echo "[FAIL] $name: empty input triggered invalid option"
    echo "------ output ------"
    sed -n '1,160p' "$out"
    rm -f "$out"
    exit 1
  fi

  rm -f "$out"
  echo "[PASS] $name"
}

# Caso 1: Enter vacío en menú principal y luego salir.
run_case "main menu empty input" $'\n0\n'

# Caso 2: Entrar al submenú 87, Enter vacío, volver y salir.
run_case "submenu 87 empty input" $'87\n\n0\n0\n'

echo "[RESULT] OK"
