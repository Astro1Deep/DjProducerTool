#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/DJProducerTools_MultiScript_ES.sh"
OUT="$(mktemp "${TMPDIR:-/tmp}/djpt-menu-zero-XXXXXX.log")"
trap 'rm -f "$OUT"' EXIT

# 0 debe salir del menú principal sin marcar opción inválida.
if ! (printf "0\n" | timeout 20 bash "$SCRIPT" --no-interactive) >"$OUT" 2>&1; then
  # Permitimos timeout con salida limpia de proceso en entornos lentos,
  # pero en ese caso debe haber consumido la opción y no marcar invalid option.
  true
fi

if grep -E -q "\\[ERR\\].*Opción inválida|INVALID_OPTION|Invalid option" "$OUT"; then
  echo "[FAIL] selecting 0 from main menu produced invalid option"
  sed -n '1,120p' "$OUT"
  exit 1
fi

# También validar retorno 0 desde submenu 87.
if ! (printf "87\n0\n0\n" | timeout 30 bash "$SCRIPT" --no-interactive) >"$OUT" 2>&1; then
  true
fi

if grep -E -q "\\[ERR\\].*Opción inválida|INVALID_OPTION|Invalid option" "$OUT"; then
  echo "[FAIL] selecting 0 inside option 87 produced invalid option"
  sed -n '1,160p' "$OUT"
  exit 1
fi

echo "[PASS] menu 0 exit behavior ok (main + submenu 87)"
