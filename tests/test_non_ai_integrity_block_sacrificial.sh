#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
HOST_PYTHON="${PYTHON_BIN:-$(command -v python3)}"
BASE="$(mktemp -d /tmp/djpt-integrity-XXXX)"
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

mkdir -p "$BASE/audio/sub" "$BASE/_Serato_/Database" "$BASE/Rekordbox Library" "$BASE/Ableton Projects"
printf 'same-dupe' > "$BASE/audio/dup_a.mp3"
cp "$BASE/audio/dup_a.mp3" "$BASE/audio/dup_b.mp3"
printf 'unique-wav' > "$BASE/audio/sub/unique.wav"
printf 'crate' > "$BASE/_Serato_/Database/database V2"
printf 'rekordbox' > "$BASE/Rekordbox Library/master.db"
printf 'ableton' > "$BASE/Ableton Projects/Set1.als"

invoke_menu_fn '' action_9_hash_index >/tmp/djpt_integrity_9.out
HASH_INDEX="$REPORTS_DIR/hash_index.tsv"
test -f "$HASH_INDEX"
rg -q $'\taudio/dup_a.mp3\t.*/audio/dup_a.mp3' "$HASH_INDEX"
rg -q $'\taudio/dup_b.mp3\t.*/audio/dup_b.mp3' "$HASH_INDEX"
rg -q $'\taudio/sub/unique.wav\t.*/audio/sub/unique.wav' "$HASH_INDEX"
awk -F'\t' '{counts[$1]++} END {for (h in counts) if (counts[h] > 1) {found=1; break} exit(found ? 0 : 1)}' "$HASH_INDEX"

invoke_menu_fn '' action_10_dupes_plan >/tmp/djpt_integrity_10.out
PLAN_TSV="$PLANS_DIR/dupes_plan.tsv"
PLAN_JSON="$PLANS_DIR/dupes_plan.json"
test -f "$PLAN_TSV"
test -f "$PLAN_JSON"
awk -F'\t' '($3 ~ /audio\/dup_a\.mp3$/ || $3 ~ /audio\/dup_b\.mp3$/) && $2=="KEEP" {keep++} ($3 ~ /audio\/dup_a\.mp3$/ || $3 ~ /audio\/dup_b\.mp3$/) && $2=="QUARANTINE" {quar++} END {exit (keep==1 && quar==1 ? 0 : 1)}' "$PLAN_TSV"
rg -q '"type": "dupes_plan"' "$PLAN_JSON"

invoke_menu_fn '' action_16_mirror_by_genre >/tmp/djpt_integrity_16.out
MIRROR_PLAN="$PLANS_DIR/mirror_by_genre.tsv"
test -f "$MIRROR_PLAN"
rg -q $'_MIRROR_BY_GENRE/GENRE_UNKNOWN/dup_a.mp3' "$MIRROR_PLAN"
rg -q $'_MIRROR_BY_GENRE/GENRE_UNKNOWN/dup_b.mp3' "$MIRROR_PLAN"
rg -q $'_MIRROR_BY_GENRE/GENRE_UNKNOWN/unique.wav' "$MIRROR_PLAN"

invoke_menu_fn '' action_17_find_dj_libs >/tmp/djpt_integrity_17.out
rg -q 'Found: .*/_Serato_' /tmp/djpt_integrity_17.out
rg -q 'Found: .*/Rekordbox Library' /tmp/djpt_integrity_17.out
rg -q 'Found: .*/Ableton Projects' /tmp/djpt_integrity_17.out

invoke_menu_fn '' action_18_rescan_intelligent >/tmp/djpt_integrity_18.out
RESCAN_OUT="$REPORTS_DIR/rescan_intelligent.tsv"
test -f "$RESCAN_OUT"
rg -q '.*/audio/dup_a.mp3' "$RESCAN_OUT"
rg -q '.*/audio/sub/unique.wav' "$RESCAN_OUT"

COMPARE_B="$REPORTS_DIR/hash_index_compare_b.tsv"
MIRROR_B="$REPORTS_DIR/hash_index_mirror_b.tsv"
python3 - "$HASH_INDEX" "$COMPARE_B" "$MIRROR_B" "$BASE" <<'PY'
import sys
from pathlib import Path

src = Path(sys.argv[1])
compare_b = Path(sys.argv[2])
mirror_b = Path(sys.argv[3])
base = Path(sys.argv[4])
rows = []
for line in src.read_text().splitlines():
    if not line.strip():
        continue
    rows.append(line.split("\t"))

compare_rows = [row for row in rows if row[1] != "audio/sub/unique.wav"]
compare_rows.append(["ghosthash", "audio/mirror_only.mp3", str(base / "mirror/audio/mirror_only.mp3")])
compare_b.write_text("".join("\t".join(row) + "\n" for row in compare_rows))

mirror_rows = []
for row in rows:
    if row[1] == "audio/sub/unique.wav":
        continue
    if row[1] == "audio/dup_a.mp3":
        row = ["deadbeef", row[1], row[2]]
    mirror_rows.append(row)
mirror_rows.append(["ghosthash", "audio/mirror_only.mp3", str(base / "mirror/audio/mirror_only.mp3")])
mirror_b.write_text("".join("\t".join(row) + "\n" for row in mirror_rows))
PY

invoke_menu_fn $"\n$COMPARE_B\n" action_58_hash_compare >/tmp/djpt_integrity_58.out
COMPARE_EXTRA="$(ls -1t "$REPORTS_DIR"/hash_compare_extra_*.tsv | head -n 1)"
COMPARE_MISSING="$(ls -1t "$REPORTS_DIR"/hash_compare_missing_*.tsv | head -n 1)"
test -f "$COMPARE_EXTRA"
test -f "$COMPARE_MISSING"
rg -q '.*/audio/sub/unique.wav' "$COMPARE_EXTRA"
rg -q '.*/mirror/audio/mirror_only.mp3' "$COMPARE_MISSING"

invoke_menu_fn $"\n$MIRROR_B\n" action_61_mirror_check >/tmp/djpt_integrity_61.out
MISSING_IN_B="$(ls -1t "$REPORTS_DIR"/mirror_missing_in_B_*.tsv | head -n 1)"
MISSING_IN_A="$(ls -1t "$REPORTS_DIR"/mirror_missing_in_A_*.tsv | head -n 1)"
MISMATCH="$(ls -1t "$REPORTS_DIR"/mirror_hash_mismatch_*.tsv | head -n 1)"
test -f "$MISSING_IN_B"
test -f "$MISSING_IN_A"
test -f "$MISMATCH"
rg -q '^audio/sub/unique.wav\t' "$MISSING_IN_B"
rg -q '^audio/mirror_only.mp3\t' "$MISSING_IN_A"
rg -q '^audio/dup_a.mp3\tA:' "$MISMATCH"

printf "PASS non_ai_integrity_block_sacrificial\n"
