#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="${TMPDIR:-/tmp}/djpt_enhanced_chat_menu_smoke.$$ .log"
LOG="${LOG// /}"
trap 'rm -f "$LOG"' EXIT

printf 'salir\n' | BASE_PATH="$ROOT" bash "$ROOT/scripts/DJProducerTools_MultiScript_ES.sh" --run enhanced_chat >"$LOG" 2>&1

grep -q "Iniciando Enhanced Chat CLI" "$LOG"
! grep -q "Script de Enhanced Chat CLI no encontrado" "$LOG"
! grep -q "djpt_chat_cli.py no encontrado" "$LOG"
