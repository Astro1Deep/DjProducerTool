#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
HOST_PYTHON="${PYTHON_BIN:-$(command -v python3)}"
BASE="$(mktemp -d /tmp/djpt-state-XXXX)"
BASE_ALT="$(mktemp -d /tmp/djpt-state-alt-XXXX)"
STATE_DIR="$BASE/_DJProducerTools"
REPORTS_DIR="$STATE_DIR/reports"
LOGS_DIR="$STATE_DIR/logs"
CONFIG_DIR="$STATE_DIR/config"
PROFILES_DIR="$CONFIG_DIR/profiles"
PLANS_DIR="$STATE_DIR/plans"
QUAR_DIR="$STATE_DIR/quarantine"
mkdir -p "$REPORTS_DIR" "$LOGS_DIR" "$CONFIG_DIR" "$PROFILES_DIR" "$PLANS_DIR" "$QUAR_DIR"

cleanup() {
  rm -rf "$BASE" "$BASE_ALT"
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
    DJPT_CMD_TARGET_DIR="$BASE/bin" \
    DJPT_SOURCED=1 \
    NO_INTERACTIVE=1 \
    DJPT_NO_INTERACTIVE=1 \
    DJPT_PARALLEL=0 \
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

mkdir -p "$BASE/audio/sub"
printf 'track-main' > "$BASE/audio/main.mp3"
printf 'track-flac' > "$BASE/audio/sub/alt.flac"
printf 'big-file' > "$BASE/audio/sub/huge.wav"
printf 'log-entry\n' > "$LOGS_DIR/run.log"
printf 'report-seed\n' > "$REPORTS_DIR/existing_report.txt"
printf 'state-marker\n' > "$CONFIG_DIR/state_marker.conf"

invoke_menu_fn '' action_1_status >/tmp/djpt_state_1.out
rg -q 'BASE_PATH:' /tmp/djpt_state_1.out
rg -q 'SAFE_MODE: ON' /tmp/djpt_state_1.out

invoke_menu_fn "$BASE_ALT\n" action_2_change_base >/tmp/djpt_state_2.out
test -f "$BASE_ALT/_DJProducerTools/config/djpt.conf"
rg -q "BASE_PATH=" "$BASE_ALT/_DJProducerTools/config/djpt.conf"

invoke_menu_fn '' action_3_summary >/tmp/djpt_state_3.out
rg -q 'Resumen del volumen' /tmp/djpt_state_3.out
rg -q 'existing_report.txt' /tmp/djpt_state_3.out

invoke_menu_fn '' action_4_top_dirs >/tmp/djpt_state_4.out
rg -q '.*/audio' /tmp/djpt_state_4.out

invoke_menu_fn '' action_5_top_files >/tmp/djpt_state_5.out
rg -q 'main.mp3|alt.flac|huge.wav' /tmp/djpt_state_5.out

invoke_menu_fn '' action_6_scan_workspace >/tmp/djpt_state_6.out
test -f "$REPORTS_DIR/workspace_scan.tsv"
rg -q $'^audio/main.mp3\t.*/audio/main.mp3$' "$REPORTS_DIR/workspace_scan.tsv"
rg -q $'^audio/sub/alt.flac\t.*/audio/sub/alt.flac$' "$REPORTS_DIR/workspace_scan.tsv"

invoke_menu_fn '' action_19_tools_diag >/tmp/djpt_state_19.out
rg -q 'ffprobe: OK|ffprobe: NO ENCONTRADO' /tmp/djpt_state_19.out
rg -q 'Tools Diagnostic:' /tmp/djpt_state_19.out

invoke_menu_fn '' action_20_fix_ownership_flags >/tmp/djpt_state_20.out
test -f "$PLANS_DIR/fix_ownership_flags.tsv"
rg -q $'.*/audio/main.mp3\tchown-KEEP\tchmod-KEEP' "$PLANS_DIR/fix_ownership_flags.tsv"

invoke_menu_fn '' action_21_install_cmd >/tmp/djpt_state_21.out
rg -q 'SAFE_MODE=1' /tmp/djpt_state_21.out
rg -q 'djproducertool' /tmp/djpt_state_21.out
test ! -e "$BASE/bin/djproducertool"

invoke_menu_fn '' action_22_uninstall_cmd >/tmp/djpt_state_22.out
rg -q 'No existe el comando|SAFE_MODE=1' /tmp/djpt_state_22.out

invoke_menu_fn '' action_23_toggle_safe_mode >/tmp/djpt_state_23.out
rg -q 'SAFE_MODE ahora: 0' /tmp/djpt_state_23.out
rg -q 'SAFE_MODE=0' "$CONFIG_DIR/djpt.conf"

invoke_menu_fn '' action_24_toggle_lock >/tmp/djpt_state_24.out
rg -q 'DJ_SAFE_LOCK ahora: 0' /tmp/djpt_state_24.out
rg -q 'DJ_SAFE_LOCK=0' "$CONFIG_DIR/djpt.conf"

invoke_menu_fn '' action_25_quick_help >/tmp/djpt_state_25.out
rg -q '6 -> 9 -> 10 -> 11 -> 12' /tmp/djpt_state_25.out
rg -q '27 para snapshot rápido' /tmp/djpt_state_25.out

invoke_menu_fn $'1\n' action_26_export_import_state >/tmp/djpt_state_26_export.out
BUNDLE="$STATE_DIR/DJPT_state_bundle.tar.gz"
test -f "$BUNDLE"
rm -f "$CONFIG_DIR/state_marker.conf"
test ! -f "$CONFIG_DIR/state_marker.conf"
invoke_menu_fn $'2\ny\n' action_26_export_import_state >/tmp/djpt_state_26_import.out
test -f "$CONFIG_DIR/state_marker.conf"

invoke_menu_fn '' action_27_snapshot >/tmp/djpt_state_27.out
test -f "$REPORTS_DIR/snapshot_hash_fast.tsv"
rg -q '^audio/main.mp3\t' "$REPORTS_DIR/snapshot_hash_fast.tsv"

invoke_menu_fn '' action_28_logs_viewer >/tmp/djpt_state_28.out
rg -q 'run.log' /tmp/djpt_state_28.out

invoke_menu_fn '' action_29_toggle_dryrun >/tmp/djpt_state_29.out
rg -q 'DRYRUN_FORCE ahora: 1' /tmp/djpt_state_29.out
rg -q 'DRYRUN_FORCE=1' "$CONFIG_DIR/djpt.conf"

invoke_menu_fn '' action_30_plan_tags >/tmp/djpt_state_30.out
test -f "$PLANS_DIR/audio_by_tags_plan.tsv"
rg -q '.*/audio/main.mp3\tUnknown' "$PLANS_DIR/audio_by_tags_plan.tsv"
rg -q '.*/audio/sub/alt.flac\tUnknown' "$PLANS_DIR/audio_by_tags_plan.tsv"

invoke_menu_fn '' action_31_report_tags >/tmp/djpt_state_31.out
test -f "$REPORTS_DIR/audio_tags_report.tsv"
rg -q '^Tag\tCount$' "$REPORTS_DIR/audio_tags_report.tsv"

printf "PASS non_ai_state_config_block_sacrificial\n"
