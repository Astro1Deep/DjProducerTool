#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
HOST_PYTHON="${PYTHON_BIN:-$(command -v python3)}"
BASE="$(mktemp -d /tmp/djpt-nonai-XXXX)"
STATE_DIR="$BASE/_DJProducerTools"
REPORTS_DIR="$STATE_DIR/reports"
LOGS_DIR="$STATE_DIR/logs"
CONFIG_DIR="$STATE_DIR/config"
PROFILES_DIR="$CONFIG_DIR/profiles"
PLANS_DIR="$STATE_DIR/plans"
QUAR_DIR="$STATE_DIR/quarantine"
mkdir -p "$REPORTS_DIR" "$LOGS_DIR" "$CONFIG_DIR" "$PROFILES_DIR" "$PLANS_DIR" "$QUAR_DIR"

cleanup() {
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

mkdir -p "$BASE/_Serato_/Database" "$BASE/_Serato_Backup/history"
printf 'serato-db' > "$BASE/_Serato_/Database/database V2"
printf 'serato-backup' > "$BASE/_Serato_Backup/history/session.txt"

mkdir -p "$BASE/Collections/SeratoData" "$BASE/Collections/Rekordbox Library" "$BASE/Collections/Ableton Projects"
printf 'crate' > "$BASE/Collections/SeratoData/crates.db"
printf 'rekordbox' > "$BASE/Collections/Rekordbox Library/master.db"
printf 'ableton' > "$BASE/Collections/Ableton Projects/Set1.als"

mkdir -p "$BASE/audio/sub"
printf 'a' > "$BASE/audio/track_a.mp3"
printf 'b' > "$BASE/audio/sub/track_b.wav"

printf 'config-one' > "$CONFIG_DIR/custom_marker.conf"

invoke_menu_fn '' action_7_backup_serato >/tmp/djpt_nonai_7.out
test -f "$STATE_DIR/serato_backup/_Serato_/Database/database V2"
test -f "$STATE_DIR/serato_backup/_Serato_Backup/history/session.txt"

invoke_menu_fn '' action_8_backup_dj >/tmp/djpt_nonai_8.out
test -f "$STATE_DIR/dj_metadata_backup/Serato_SeratoData/crates.db"
test -f "$STATE_DIR/dj_metadata_backup/Rekordbox_Rekordbox Library/master.db"
test -f "$STATE_DIR/dj_metadata_backup/Ableton_Ableton Projects/Set1.als"

invoke_menu_fn '' action_15_relink_helper >/tmp/djpt_nonai_15.out
test -f "$REPORTS_DIR/relink_helper.tsv"
rg -q $'audio/track_a.mp3\t.*/audio/track_a.mp3' "$REPORTS_DIR/relink_helper.tsv"
rg -q $'audio/sub/track_b.wav\t.*/audio/sub/track_b.wav' "$REPORTS_DIR/relink_helper.tsv"

mkdir -p "$QUAR_DIR/hash1"
printf 'q' > "$QUAR_DIR/hash1/file.mp3"
printf 'log' > "$LOGS_DIR/test.log"
printf 'report' > "$REPORTS_DIR/marker.txt"
invoke_menu_fn '' action_59_health_check >/tmp/djpt_nonai_59.out
test -f "$REPORTS_DIR/state_health.txt"
rg -q 'STATE HEALTH REPORT' "$REPORTS_DIR/state_health.txt"
rg -q 'BASE_PATH:' "$REPORTS_DIR/state_health.txt"

invoke_menu_fn $'1\nStudioA\n3\nb\n' submenu_profiles_manager "$BASE/audio" "$BASE/general" >/tmp/djpt_nonai_profiles.out
test -f "$PROFILES_DIR/StudioA.conf"
rg -q 'BASE_PATH=' "$PROFILES_DIR/StudioA.conf"
rg -q 'AUDIO_ROOT=' "$PROFILES_DIR/StudioA.conf"
rg -q 'GENERAL_ROOT=' "$PROFILES_DIR/StudioA.conf"

invoke_menu_fn $'1\n' action_export_import_config >/tmp/djpt_nonai_60_export.out
BUNDLE="$(ls -1t "$STATE_DIR"/config_bundle_*.tar.gz | head -n 1)"
test -f "$BUNDLE"
rm -f "$CONFIG_DIR/custom_marker.conf"
test ! -f "$CONFIG_DIR/custom_marker.conf"
invoke_menu_fn "2\n$BUNDLE\n" action_export_import_config >/tmp/djpt_nonai_60_import.out
test -f "$CONFIG_DIR/custom_marker.conf"
rg -q 'config-one' "$CONFIG_DIR/custom_marker.conf"

printf "PASS non_ai_core_ops_sacrificial\n"
