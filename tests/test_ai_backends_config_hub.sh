#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
RAW_OUT="$(mktemp "${TMPDIR:-/tmp}/djpt-ai-backends-config-raw-XXXXXX.log")"
TXT_OUT="$(mktemp "${TMPDIR:-/tmp}/djpt-ai-backends-config-txt-XXXXXX.log")"
trap 'rm -f "$RAW_OUT" "$TXT_OUT"' EXIT

if ! printf '71\n8\n0\n0\n' | BASE_PATH="$ROOT_DIR" DJPT_NO_INTERACTIVE=1 DJPT_SKIP_MLX=1 DJPT_SKIP_TF=1 bash "$SCRIPT" --no-interactive >"$RAW_OUT" 2>&1; then
  true
fi

perl -pe 's/\e\[[0-9;]*[A-Za-z]//g' "$RAW_OUT" >"$TXT_OUT"

for expected in \
  "HUB DE CONFIGURACIÓN DE BACKENDS IA" \
  "1) Configuración global IA" \
  "2) Tuning rápido de backends" \
  "3) Submenú clásico de backends (1-9)" \
  "4) Validar dependencias IA" \
  "5) Instalar / reparar dependencias IA" \
  "6) Operaciones IA avanzadas" \
  "7) Gestionar modelos locales" \
  "8) Health check IA centralizado"
do
  if ! grep -Fq "$expected" "$TXT_OUT"; then
    echo "[FAIL] backend config hub missing line: $expected"
    sed -n '1,220p' "$TXT_OUT"
    exit 1
  fi
done

echo "[PASS] backend config hub preserves backend capabilities"
