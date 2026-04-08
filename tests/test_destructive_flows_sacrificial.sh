#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
BASE="$(mktemp -d /tmp/djpt-sacrificial-XXXX)"
STATE_DIR="$BASE/_DJProducerTools"
PLANS_DIR="$STATE_DIR/plans"
QUAR_DIR="$STATE_DIR/quarantine"
mkdir -p "$PLANS_DIR" "$QUAR_DIR"

cleanup() {
  rm -rf "$BASE"
}
trap cleanup EXIT

printf "audio-a" > "$BASE/keep_a.mp3"
printf "audio-b" > "$BASE/keep_b.wav"
cat > "$PLANS_DIR/dupes_plan.tsv" <<EOF
hash	action	path	reason
H1	QUARANTINE	$BASE/keep_a.mp3	dup
H2	QUARANTINE	$BASE/keep_b.wav	dup
EOF

export BASE_PATH="$BASE"
export DJPT_BASE_DIR="$BASE"
export STATE_DIR
export PLANS_DIR
export QUAR_DIR
export DJPT_SOURCED=1
export NO_INTERACTIVE=1
export DJPT_NO_INTERACTIVE=1
export PYTHON_BIN="${PYTHON_BIN:-python3}"
export SAFETY_PROMPTED=1
export SAFE_MODE=0
export DJ_SAFE_LOCK=0
export DRYRUN_FORCE=0

printf 'y\n' | bash -c "source '$SCRIPT'; BASE_PATH='$BASE'; DJPT_BASE_DIR='$BASE'; STATE_DIR='$STATE_DIR'; PLANS_DIR='$PLANS_DIR'; QUAR_DIR='$QUAR_DIR'; SAFE_MODE=0; DJ_SAFE_LOCK=0; DRYRUN_FORCE=0; SAFETY_PROMPTED=1; action_11_quarantine_from_plan" >/tmp/djpt_destructive_q11.out

test -f "$QUAR_DIR/H1/keep_a.mp3"
test -f "$QUAR_DIR/H2/keep_b.wav"
test ! -f "$BASE/keep_a.mp3"
test ! -f "$BASE/keep_b.wav"

printf '2\nYES\n3\nYES\nb\n' | bash -c "source '$SCRIPT'; BASE_PATH='$BASE'; DJPT_BASE_DIR='$BASE'; STATE_DIR='$STATE_DIR'; PLANS_DIR='$PLANS_DIR'; QUAR_DIR='$QUAR_DIR'; SAFE_MODE=0; DJ_SAFE_LOCK=0; DRYRUN_FORCE=0; SAFETY_PROMPTED=1; action_12_quarantine_manager" >/tmp/djpt_destructive_q12.out

test -f "$BASE/_RESTORED_FROM_QUARANTINE/keep_a.mp3"
test -f "$BASE/_RESTORED_FROM_QUARANTINE/keep_b.wav"
if find "$QUAR_DIR" -type f | grep -q .; then
  echo "quarantine not purged"
  exit 1
fi

mkdir -p "$STATE_DIR/config" "$STATE_DIR/reports"
printf 'marker' > "$STATE_DIR/config/test_marker.txt"
export DRYRUN_FORCE=1
printf 'RESET\nYES\n' | bash -c "source '$SCRIPT'; BASE_PATH='$BASE'; DJPT_BASE_DIR='$BASE'; STATE_DIR='$STATE_DIR'; SAFE_MODE=0; DJ_SAFE_LOCK=0; DRYRUN_FORCE=1; SAFETY_PROMPTED=1; action_53_reset_state" >/tmp/djpt_destructive_reset.out

test -f "$STATE_DIR/config/test_marker.txt"
rg -q "\\[DRY\\]" /tmp/djpt_destructive_reset.out

printf "PASS destructive_sacrificial_quarantine_restore_purge_reset\n"
