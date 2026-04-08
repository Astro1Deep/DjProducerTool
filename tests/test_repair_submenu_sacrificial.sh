#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
HOST_PYTHON="${PYTHON_BIN:-$(command -v python3)}"
BASE="$(mktemp -d /tmp/djpt-repair-XXXX)"
STATE_DIR="$BASE/_DJProducerTools"
REPORTS_DIR="$STATE_DIR/reports"
LOGS_DIR="$STATE_DIR/logs"
CONFIG_DIR="$STATE_DIR/config"
PLANS_DIR="$STATE_DIR/plans"
QUAR_DIR="$STATE_DIR/quarantine"
mkdir -p "$REPORTS_DIR" "$LOGS_DIR" "$CONFIG_DIR" "$PLANS_DIR" "$QUAR_DIR" "$BASE/_Serato_"

cleanup() {
  rm -rf "$BASE"
}
trap cleanup EXIT

invoke_repair_menu() {
  local input="$1"
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
ARG_BASE="$1"; shift
source "$SCRIPT_PATH"
BASE_PATH="$ARG_BASE"
DJPT_BASE_DIR="$ARG_BASE"
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
submenu_R_repair_system
' _ "$SCRIPT" "$BASE"
}

invoke_repair_menu $'1\n2\nB\n' >/tmp/djpt_repair_1.out
rg -q 'DJPT_MPC_ENABLED=1' "$CONFIG_DIR/djpt.conf"
rg -q 'DJPT_MPC_LEARNING=1' "$CONFIG_DIR/djpt.conf"
rg -q 'DJPT_ADAPTIVE_UI=1' "$CONFIG_DIR/djpt.conf"

invoke_repair_menu $'1\n3\n0.85\nB\n' >/tmp/djpt_repair_1_threshold.out
rg -q 'DJPT_MPC_THRESHOLD=0.85' "$CONFIG_DIR/djpt.conf"

invoke_repair_menu $'2\n6\nB\n' >/tmp/djpt_repair_2.out
test -f "$REPORTS_DIR/neural_audio_performance.json"
rg -q 'export_performance' "$REPORTS_DIR/neural_audio_performance.json"

invoke_repair_menu $'3\n1\n4\n3\n3\nB\n' >/tmp/djpt_repair_3.out
test -f "$REPORTS_DIR/distributed_processing_report.json"
rg -q '"workers": 4' "$REPORTS_DIR/distributed_processing_report.json"

invoke_repair_menu $'4\n1\n4\n2\n4\n3\nB\n' >/tmp/djpt_repair_4.out
rg -q 'DJPT_REALTIME_METRICS=1' "$CONFIG_DIR/djpt.conf"
rg -q 'DJPT_AUTO_ALERTS=1' "$CONFIG_DIR/djpt.conf"
rg -q 'CPU:' /tmp/djpt_repair_4.out
if rg -q 'CPU: N/A|Memoria: N/A|Throughput: N/A' /tmp/djpt_repair_4.out; then
  echo 'real-time metrics still unresolved'
  exit 1
fi

invoke_repair_menu $'5\n5\n5\n2\nB\n' >/tmp/djpt_repair_5.out
rg -q 'DJPT_AUTO_HEALING=1' "$CONFIG_DIR/djpt.conf"
test -f "$REPORTS_DIR/error_recovery_report.json"
rg -q 'report' "$REPORTS_DIR/error_recovery_report.json"

invoke_repair_menu $'6\n1\nB\n' >/tmp/djpt_repair_6.out
rg -q 'DJPT_USER_PROFILES=1' "$CONFIG_DIR/djpt.conf"

invoke_repair_menu $'7\n4\nB\n' >/tmp/djpt_repair_7.out
rg -q '"serato"' /tmp/djpt_repair_7.out
rg -q '"mcp"' /tmp/djpt_repair_7.out

invoke_repair_menu $'8\n1\n8\n2\n8\n3\nB\n' >/tmp/djpt_repair_8.out
rg -q 'DJPT_AUTO_OPTIMIZE=1' "$CONFIG_DIR/djpt.conf"
rg -q 'DJPT_SMART_CACHE=1' "$CONFIG_DIR/djpt.conf"
test -f "$REPORTS_DIR/benchmark_system_report.json"
rg -q 'throughput_files_per_min' "$REPORTS_DIR/benchmark_system_report.json"

invoke_repair_menu $'9\nB\n' >/tmp/djpt_repair_9.out
test -f "$REPORTS_DIR/system_analyzer_repair.json"
rg -q '"new_features"' "$REPORTS_DIR/system_analyzer_repair.json"

invoke_repair_menu $'10\n1\n10\n2\n10\n3\n10\n4\n10\n5\nB\n' >/tmp/djpt_repair_10.out
rg -q 'DJPT_QUANTUM=1' "$CONFIG_DIR/djpt.conf"
rg -q 'DJPT_AI_INTEGRATION=avanzada' "$CONFIG_DIR/djpt.conf"
rg -q 'DJPT_ADVANCED_ML=1' "$CONFIG_DIR/djpt.conf"
rg -q 'DJPT_EXPERIMENTAL_MODE=1' "$CONFIG_DIR/djpt.conf"
test -f "$REPORTS_DIR/quantum_processing_report.json"
rg -q 'quantum_processing' "$REPORTS_DIR/quantum_processing_report.json"

printf 'PASS repair_submenu_sacrificial\n'
