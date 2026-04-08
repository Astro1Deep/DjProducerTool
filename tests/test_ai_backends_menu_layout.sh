#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
RAW_OUT="$(mktemp "${TMPDIR:-/tmp}/djpt-ai-backends-layout-raw-XXXXXX.log")"
TXT_OUT="$(mktemp "${TMPDIR:-/tmp}/djpt-ai-backends-layout-txt-XXXXXX.log")"
trap 'rm -f "$RAW_OUT" "$TXT_OUT"' EXIT

if ! printf '71\n0\n0\n' | BASE_PATH="$ROOT_DIR" DJPT_NO_INTERACTIVE=1 DJPT_SKIP_MLX=1 DJPT_SKIP_TF=1 bash "$SCRIPT" --no-interactive >"$RAW_OUT" 2>&1; then
  true
fi

perl -pe 's/\e\[[0-9;]*[A-Za-z]//g' "$RAW_OUT" >"$TXT_OUT"

for expected in \
  "GESTOR DE BACKENDS IA (Multi-Backend)" \
  "1) MLX (Apple Silicon GPU)" \
  "2) TensorFlow (Metal)" \
  "3) Scikit-learn (Local)" \
  "4) Ollama (Local LLM)" \
  "5) Verificar estado de todos" \
  "6) Optimizar rendimiento" \
  "7) Benchmark comparativo" \
  "8) Configurar backends"
do
  if ! grep -Fq "$expected" "$TXT_OUT"; then
    echo "[FAIL] backend menu missing line: $expected"
    sed -n '1,200p' "$TXT_OUT"
    exit 1
  fi
done

echo "[PASS] backend manager layout matches canonical 1-8 contract"
