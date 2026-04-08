#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
HOST_PYTHON="${PYTHON_BIN:-$(command -v python3)}"
BASE="$(mktemp -d /tmp/djpt-intel-XXXX)"
STATE_DIR="$BASE/_DJProducerTools"
REPORTS_DIR="$STATE_DIR/reports"
LOGS_DIR="$STATE_DIR/logs"
CONFIG_DIR="$STATE_DIR/config"
PROFILES_DIR="$CONFIG_DIR/profiles"
PLANS_DIR="$STATE_DIR/plans"
QUAR_DIR="$STATE_DIR/quarantine"
mkdir -p "$REPORTS_DIR" "$LOGS_DIR" "$CONFIG_DIR" "$PROFILES_DIR" "$PLANS_DIR" "$QUAR_DIR"

cleanup() {
  if [ -f "$STATE_DIR/osc_api_server.pid" ]; then
    kill "$(cat "$STATE_DIR/osc_api_server.pid")" 2>/dev/null || true
  fi
  rm -rf "$BASE"
}
trap cleanup EXIT

invoke_menu_fn() {
  local input="$1"
  local func="$2"
  local audio_root="${3:-$BASE/audio}"
  local general_root="${4:-$BASE/general}"
  printf "%b" "$input" | env \
    BASE_PATH="$BASE" \
    DJPT_BASE_DIR="$BASE" \
    DJPT_SOURCED=1 \
    NO_INTERACTIVE=1 \
    DJPT_NO_INTERACTIVE=1 \
    PYTHON_BIN="$HOST_PYTHON" \
    DJPT_PYTHON_BIN="$HOST_PYTHON" \
    bash -lc '
set -euo pipefail
SCRIPT_PATH="$1"; shift
FUNC="$1"; shift
ARG_BASE="$1"; shift
ARG_AUDIO_ROOT="$1"; shift
ARG_GENERAL_ROOT="$1"; shift
source "$SCRIPT_PATH"
BASE_PATH="$ARG_BASE"
DJPT_BASE_DIR="$ARG_BASE"
AUDIO_ROOT="$ARG_AUDIO_ROOT"
GENERAL_ROOT="$ARG_GENERAL_ROOT"
DJPT_STATE_ANCHOR="$ARG_BASE"
init_paths
load_conf
apply_runtime_defaults
SAFE_MODE=1
DJ_SAFE_LOCK=1
DRYRUN_FORCE=0
SAFETY_PROMPTED=1
confirm_heavy() { return 0; }
clear() { :; }
print_header() { :; }
"$FUNC"
' _ "$SCRIPT" "$func" "$BASE" "$audio_root" "$general_root"
}

mkdir -p "$BASE/audio" "$BASE/_Serato_/Database" "$BASE/Traktor" "$BASE/Ableton"
printf 'club-track' > "$BASE/audio/Club Track 128 bpm.mp3"
printf 'taggy' > "$BASE/audio/Artist  - Song www mix.mp3"
: > "$BASE/audio/this_is_a_very_long_filename_for_predictor_validation_because_it_exceeds_eighty_characters_total.wav"
printf '<rekordbox />' > "$BASE/rekordbox_export.xml"
printf '<NML></NML>' > "$BASE/Traktor/collection.nml"
printf 'ableton-set' > "$BASE/Ableton/Set1.als"
printf 'crate' > "$BASE/_Serato_/Database/database V2"
printf 'hash	action	path	reason\nH1\tQUARANTINE\t%s/audio/Club Track 128 bpm.mp3\tdup\nH2\tQUARANTINE\t%s/audio/Artist  - Song www mix.mp3\tdup\n' "$BASE" "$BASE" > "$PLANS_DIR/dupes_plan.tsv"
printf 'snapshot\n' > "$PLANS_DIR/snapshot.tsv"

invoke_menu_fn '' action_40_smart_analysis >/tmp/djpt_intel_40.out
SMART_JSON="$(ls -1t "$REPORTS_DIR"/smart_analysis_*.json | head -1)"
test -f "$SMART_JSON"
rg -q '"analysis_type": "SMART_ANALYSIS"' "$SMART_JSON"

invoke_menu_fn '' action_41_ml_predictor >/tmp/djpt_intel_41.out
PRED_TSV="$(ls -1t "$REPORTS_DIR"/ml_predictions_*.tsv | head -1)"
test -f "$PRED_TSV"
rg -q 'Nombre muy largo|Archivo vacío' "$PRED_TSV"

invoke_menu_fn '' action_42_efficiency_optimizer >/tmp/djpt_intel_42.out
EFF_TSV="$(ls -1t "$PLANS_DIR"/efficiency_*.tsv | head -1)"
test -f "$EFF_TSV"
rg -q '^Plan\tType\tRows\tPriority\tRecommendation$' "$EFF_TSV"

invoke_menu_fn '' action_43_smart_workflow >/tmp/djpt_intel_43.out
WORKFLOW_TXT="$(ls -1t "$PLANS_DIR"/workflow_*.txt | head -1)"
test -f "$WORKFLOW_TXT"
rg -q 'SMART WORKFLOW' "$WORKFLOW_TXT"

invoke_menu_fn '' action_44_integrated_dedup >/tmp/djpt_intel_44.out
DEDUP_TSV="$(ls -1t "$PLANS_DIR"/integrated_dedup_*.tsv | head -1)"
test -f "$DEDUP_TSV"
rg -q $'Exactos \(hash\)\t2\t' "$DEDUP_TSV"

invoke_menu_fn '' action_45_ml_organization >/tmp/djpt_intel_45.out
ORG_TSV="$(ls -1t "$PLANS_DIR"/ml_organization_*.tsv | head -1)"
test -f "$ORG_TSV"
rg -q '^File\tCategory\tSuggestedDestination\tConfidence$' "$ORG_TSV"
rg -q 'Club Track 128 bpm.mp3\tAUDIO\t' "$ORG_TSV"

invoke_menu_fn '' action_46_metadata_harmonizer >/tmp/djpt_intel_46.out
HARM_TSV="$(ls -1t "$PLANS_DIR"/metadata_harmony_*.tsv | head -1)"
test -f "$HARM_TSV"
rg -q 'web_tag_detected|double_spaces|inconsistent_separator' "$HARM_TSV"

invoke_menu_fn '' action_47_predictive_backup >/tmp/djpt_intel_47.out
BACKUP_TXT="$(ls -1t "$PLANS_DIR"/predictive_backup_*.txt | head -1)"
test -f "$BACKUP_TXT"
rg -q 'BACKUP PREDICTIVO' "$BACKUP_TXT"

invoke_menu_fn '' action_48_cross_platform_sync >/tmp/djpt_intel_48.out
SYNC_TXT="$(ls -1t "$PLANS_DIR"/cross_platform_*.txt | head -1)"
test -f "$SYNC_TXT"
rg -q 'Serato: OK' "$SYNC_TXT"
rg -q 'Traktor NML: Detectado' "$SYNC_TXT"
rg -q 'Ableton ALS: Detectado' "$SYNC_TXT"

invoke_menu_fn '' action_49_advanced_analysis >/tmp/djpt_intel_49.out
BPM_TSV="$REPORTS_DIR/audio_bpm_report.tsv"
test -f "$BPM_TSV"
rg -q $'Club Track 128 bpm.mp3\t128\.00\tfilename\t0\.80' "$BPM_TSV"

PORTS="$(python3 - <<'PY'
import socket
ports = []
for _ in range(2):
    s = socket.socket()
    s.bind(('127.0.0.1', 0))
    ports.append(str(s.getsockname()[1]))
    s.close()
print(' '.join(ports))
PY
)"
HTTP_PORT="${PORTS%% *}"
OSC_PORT="${PORTS##* }"
invoke_menu_fn "${HTTP_PORT}\n${OSC_PORT}\n\ny\n" action_50_integration_engine >/tmp/djpt_intel_50_start.out
PID_FILE="$STATE_DIR/osc_api_server.pid"
test -f "$PID_FILE"
SERVER_PID="$(cat "$PID_FILE")"
ps -p "$SERVER_PID" >/dev/null 2>&1
python3 - <<PY
import json
import os
from urllib.request import urlopen
payload = json.load(urlopen('http://127.0.0.1:${HTTP_PORT}/status', timeout=5))
assert payload['http_port'] == ${HTTP_PORT}
assert payload['base_path'] == os.path.realpath('${BASE}')
PY
invoke_menu_fn $'y\n' action_50_integration_engine >/tmp/djpt_intel_50_stop.out
if [ -f "$PID_FILE" ]; then
  echo 'pid file should be removed after stop'
  exit 1
fi

invoke_menu_fn '' action_51_adaptive_recommendations >/tmp/djpt_intel_51.out
REC_TXT="$(ls -1t "$REPORTS_DIR"/adaptive_recommendations_*.txt | head -1)"
test -f "$REC_TXT"
rg -q 'RECOMENDACIONES ADAPTATIVAS' "$REC_TXT"
rg -q '2 pendientes' "$REC_TXT"

invoke_menu_fn '' action_52_automated_cleanup_pipeline >/tmp/djpt_intel_52.out
PIPE_TXT="$(ls -1t "$PLANS_DIR"/cleanup_pipeline_*.txt | head -1)"
test -f "$PIPE_TXT"
rg -q 'FASE 1: Análisis' "$PIPE_TXT"
rg -q 'FASE 8: Snapshot rápido' "$PIPE_TXT"

printf 'PASS non_ai_intelligent_block_sacrificial\n'
