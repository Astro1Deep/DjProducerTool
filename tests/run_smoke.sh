#!/usr/bin/env bash
# set -euo pipefail # Desactivado para evitar cierres al hacer doble clic
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PY_BIN="${PYTHON_BIN:-$ROOT_DIR/_DJProducerTools/djpt_venv/bin/python3}"
if [[ ! -x "$PY_BIN" ]]; then
  PY_BIN="${PYTHON_BIN:-$ROOT_DIR/djpt_venv/bin/python3}"
fi
if [[ ! -x "$PY_BIN" ]]; then
  PY_BIN="${PYTHON_BIN:-$ROOT_DIR/venv/bin/python3}"
fi
if [[ ! -x "$PY_BIN" ]]; then
  PY_BIN="$(command -v python3)"
fi
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
STAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/smoke_${STAMP}.log"

run_step() {
  local name="$1"; shift
  echo "[SMOKE] $name" | tee -a "$LOG_FILE"
  "$@" 2>&1 | tee -a "$LOG_FILE"
  return ${PIPESTATUS[0]}
}

status=0
rc=0
run_step "health" "$PY_BIN" "$ROOT_DIR/scripts/ai_health.py" || rc=$?
if [[ $rc -gt 1 ]]; then status=$rc; fi
rc=0
run_step "ai status" env PYTHONPATH="$ROOT_DIR" "$PY_BIN" "$ROOT_DIR/scripts/cli.py" ai status || rc=$?
(( status = status || rc ))
rc=0
run_step "kb status" env PYTHONPATH="$ROOT_DIR" "$PY_BIN" "$ROOT_DIR/scripts/cli.py" ai kb --action status || rc=$?
(( status = status || rc ))
if command -v timeout >/dev/null 2>&1; then TOUT=(timeout 60); else TOUT=(); fi
rc=0
run_step "ai train classifier" env PYTHONPATH="$ROOT_DIR" "${TOUT[@]}" "$PY_BIN" "$ROOT_DIR/scripts/cli.py" ai train --type classifier || rc=$?
(( status = status || rc ))

if [[ $status -eq 0 ]]; then
  echo "[SMOKE] OK -> $LOG_FILE"
else
  echo "[SMOKE] COMPLETADO rc=$status -> $LOG_FILE"
fi
exit $status
