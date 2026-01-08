#!/usr/bin/env bash
set -euo pipefail

readonly BASE_PATH="/Users/ivan/Desktop/0 SERATO BIBLIOTECA"
readonly MULTISCRIPT_PATH="$BASE_PATH/DJProducerTools_Project/scripts/DJProducerTools_MultiScript_EN.sh"
readonly STATE_DIR="$BASE_PATH/_DJProducerTools"
readonly PLAN_FILE="$STATE_DIR/plans/general_hash_dupes_plan.tsv"
readonly LOG_DIR="$STATE_DIR/logs/quarantine_safe"
readonly AUTOSAVE_DIR="$LOG_DIR/autosaves"

mkdir -p "$LOG_DIR" "$AUTOSAVE_DIR"

if [ ! -f "$PLAN_FILE" ]; then
  printf "%s ERROR: Plan %s no encontrado.\n" "$(date -u)" "$PLAN_FILE" >&2
  exit 1
fi

readonly TIMESTAMP=$(date -u +"%Y%m%d_%H%M%S")
readonly BACKUP_PLAN="$AUTOSAVE_DIR/general_hash_dupes_plan_${TIMESTAMP}.tsv"
cp "$PLAN_FILE" "$BACKUP_PLAN"

readonly META_FILE="$LOG_DIR/last_run.idx"
run_idx=0
if [ -f "$META_FILE" ]; then
  run_idx=$(<"$META_FILE")
fi
run_idx=$((run_idx + 1))
printf "%s\n" "$run_idx" >"$META_FILE"

printf "%s [run %d] plan snapshot %s\n" "$(date -u)" "$run_idx" "$BACKUP_PLAN" >>"$LOG_DIR/quarantine_safe.log"

/usr/bin/expect <<EOF
set timeout -1
spawn env SAFE_MODE=0 DJ_SAFE_LOCK=0 "$MULTISCRIPT_PATH"
expect -re "Opción:"
send "11\r"
while {1} {
  expect {
    -re "SAFE_MODE o DJ_SAFE_LOCK" {
      send "n\r"
      exp_continue
    }
    -re "Confirmar mover archivos" {
      send "y\r"
      exp_continue
    }
    -re "Pulsa ENTER" {
      send "\r"
      exp_continue
    }
    -re "Opción:" {
      break
    }
    eof {
      exit 0
    }
  }
}
send "0\r"
expect eof
EOF

quarantine_dir="$STATE_DIR/quarantine"
quarantine_count=$(find "$quarantine_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
quarantine_size=$(du -sh "$quarantine_dir" 2>/dev/null | cut -f1 || printf "0B")
printf "%s [run %d] quarantine files=%s size=%s\n" "$(date -u)" "$run_idx" "$quarantine_count" "$quarantine_size" >>"$LOG_DIR/quarantine_safe.log"

printf "%s [run %d] finalizado (quarantine %s / %s archivos)\n" "$(date -u)" "$run_idx" "$quarantine_size" "$quarantine_count" >>"$LOG_DIR/quarantine_safe.log"
