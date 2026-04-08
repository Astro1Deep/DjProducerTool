#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
TMP_BASE="$(mktemp -d "${TMPDIR:-/tmp}/djpt-lab-graph-XXXXXX")"
trap 'rm -rf "$TMP_BASE"' EXIT

mkdir -p "$TMP_BASE/audio" "$TMP_BASE/docs" "$TMP_BASE/video"
printf 'dummy\n' >"$TMP_BASE/docs/readme.txt"
printf 'dummy\n' >"$TMP_BASE/audio/test.wav"
printf 'dummy\n' >"$TMP_BASE/video/clip.mp4"

REPORT_DIR="$TMP_BASE/_DJProducerTools/reports"
mkdir -p "$REPORT_DIR"
before_json="$(find "$REPORT_DIR" -maxdepth 1 -type f -name 'lab_assets_graph_*.json' 2>/dev/null | wc -l | tr -d ' ')"
before_mmd="$(find "$REPORT_DIR" -maxdepth 1 -type f -name 'lab_assets_graph_*.mmd' 2>/dev/null | wc -l | tr -d ' ')"

printf '\n' | BASE_PATH="$TMP_BASE" DJPT_NO_INTERACTIVE=1 LAB=1 bash "$SCRIPT" --no-interactive --run 92 >/tmp/djpt_lab_graph.out 2>&1

after_json="$(find "$REPORT_DIR" -maxdepth 1 -type f -name 'lab_assets_graph_*.json' 2>/dev/null | wc -l | tr -d ' ')"
after_mmd="$(find "$REPORT_DIR" -maxdepth 1 -type f -name 'lab_assets_graph_*.mmd' 2>/dev/null | wc -l | tr -d ' ')"

if [ "$after_json" -le "$before_json" ] || [ "$after_mmd" -le "$before_mmd" ]; then
  echo "[FAIL] lab graph did not create both JSON and Mermaid artifacts"
  cat /tmp/djpt_lab_graph.out
  exit 1
fi

if rg -n "aún no implementado|no implementado" /tmp/djpt_lab_graph.out >/dev/null; then
  echo "[FAIL] lab graph still reports as unimplemented"
  cat /tmp/djpt_lab_graph.out
  exit 1
fi

echo "[PASS] LAB graph creates real artifacts"
