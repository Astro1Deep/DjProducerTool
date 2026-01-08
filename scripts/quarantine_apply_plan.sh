#!/usr/bin/env bash
set -euo pipefail

# Ejecuta el plan dupes_plan.tsv en lotes, con autoguardado por offset.
# Útil para planes grandes y para reanudar sin repetir todo el trabajo.

script_dir="$(cd "$(dirname "$0")" && pwd)"
base_root="$(cd "$script_dir/../.." && pwd)"

STATE_DIR="${STATE_DIR_OVERRIDE:-"$base_root/_DJProducerTools"}"
PLAN_FILE="${PLAN_FILE_OVERRIDE:-"$STATE_DIR/plans/dupes_plan.tsv"}"
LOG_DIR="$STATE_DIR/logs/quarantine_safe"
CKP_FILE="$LOG_DIR/quarantine_offset.state"
LOG_FILE="$LOG_DIR/quarantine_apply.log"

mkdir -p "$LOG_DIR"

batch_size=2000
offset=0
resume=0

usage() {
    cat <<EOF
Uso: $(basename "$0") [--plan <path>] [--batch-size <n>] [--offset <n>] [--resume]
  --plan        Plan TSV a aplicar (default: $PLAN_FILE)
  --batch-size  Número de entradas QUARANTINE por ejecución (default: $batch_size)
  --offset      Número de línea del plan por donde empezar (default: $offset)
  --resume      Lee el offset guardado en $CKP_FILE
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --plan) PLAN_FILE="$2"; shift 2 ;;
        --batch-size) batch_size="$2"; shift 2 ;;
        --offset) offset="$2"; shift 2 ;;
        --resume) resume=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Opción desconocida: $1" >&2; usage; exit 1 ;;
    esac
done

if [ "$resume" -eq 1 ] && [ -f "$CKP_FILE" ]; then
    offset="$(cat "$CKP_FILE")"
fi

if [ ! -f "$PLAN_FILE" ]; then
    echo "ERROR: No existe el plan: $PLAN_FILE" >&2
    exit 1
fi

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

log() {
    local msg="$1"
    printf "%s %s\n" "$(timestamp)" "$msg" | tee -a "$LOG_FILE"
}

save_offset() {
    printf "%s\n" "$1" >"$CKP_FILE"
}

quar_dir="$STATE_DIR/quarantine"
mkdir -p "$quar_dir"

processed=0
errors=0
start_line=$((offset + 1))
last_line="$offset"

log "Inicio batch desde línea $start_line (batch_size=$batch_size, plan=$PLAN_FILE)"

trap 'log "Interrumpido en línea $last_line (procesados=$processed, errores=$errors)"; save_offset "$last_line"' INT TERM

while IFS=$'\t' read -r hash action src; do
    last_line=$((last_line + 1))
    [ "$last_line" -le "$offset" ] && continue
    [ "$action" != "QUARANTINE" ] && continue

    dest_dir="$quar_dir/$hash"
    dest="$dest_dir/$(basename "$src")"
    mkdir -p "$dest_dir"

    if mv "$src" "$dest" 2>/dev/null; then
        processed=$((processed + 1))
    else
        # Fallback rsync --remove-source-files si mv no pudo borrar (permisos/flags)
        if command -v rsync >/dev/null 2>&1; then
            if rsync -a --remove-source-files "$src" "$dest_dir/" 2>/dev/null; then
                processed=$((processed + 1))
            else
                printf "%s\tMOVE_FAIL\t%s\t->\t%s\n" "$(timestamp)" "$src" "$dest" >>"$LOG_FILE"
                errors=$((errors + 1))
            fi
        else
            printf "%s\tMOVE_FAIL\t%s\t->\t%s\n" "$(timestamp)" "$src" "$dest" >>"$LOG_FILE"
            errors=$((errors + 1))
        fi
    fi

    if [ "$processed" -ge "$batch_size" ]; then
        save_offset "$last_line"
        log "Batch completo: offset=$last_line procesados=$processed errores=$errors"
        exit 0
    fi
done <"$PLAN_FILE"

save_offset "$last_line"
log "Plan agotado: offset=$last_line procesados=$processed errores=$errors"
