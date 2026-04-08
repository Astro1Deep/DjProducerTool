#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
HOST_PYTHON="${PYTHON_BIN:-$(command -v python3)}"
BASE="$(mktemp -d /tmp/djpt-media-XXXX)"
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

mkdir -p "$BASE/audio/Album A" "$BASE/audio/Samples"
printf 'not-real-mp3' > "$BASE/audio/Album A/Áudio??.mp3"
printf 'not-real-flac' > "$BASE/audio/Album A/Canción.flac"
printf 'kick' > "$BASE/audio/Samples/kick_loop.wav"
printf 'snare' > "$BASE/audio/Samples/snare_hit.wav"
printf 'hat' > "$BASE/audio/Samples/hat_closed.wav"
printf 'video-bytes' > "$BASE/audio/clip.mp4"
cat > "$BASE/audio/web_playlist.m3u8" <<'EOF'
https://youtube.com/watch?v=keep
https://example.com/remove
local_track.mp3
EOF

invoke_menu_fn '' action_13_ffprobe_report >/tmp/djpt_media_13.out
test -f "$REPORTS_DIR/media_corrupt.tsv"
rg -q '.*/Áudio\?\?\.mp3\tCORRUPT' "$REPORTS_DIR/media_corrupt.tsv"
rg -q '.*/clip.mp4\tCORRUPT' "$REPORTS_DIR/media_corrupt.tsv"

invoke_menu_fn '' action_14_playlists_per_folder >/tmp/djpt_media_14.out
test -f "$BASE/audio/Album A/playlist.m3u8"
rg -q 'Áudio\?\?\.mp3' "$BASE/audio/Album A/playlist.m3u8"
rg -q 'Canción.flac' "$BASE/audio/Album A/playlist.m3u8"

invoke_menu_fn '' action_32_serato_video_report >/tmp/djpt_media_32.out
test -f "$REPORTS_DIR/serato_video_report.tsv"
rg -q '^File\tFormat\tStatus$' "$REPORTS_DIR/serato_video_report.tsv"

invoke_menu_fn $'\nn\n' action_33_serato_video_prep >/tmp/djpt_media_33.out
test -f "$PLANS_DIR/serato_video_transcode_plan.tsv"
rg -q '^File\tAction\tCommand$' "$PLANS_DIR/serato_video_transcode_plan.tsv"

invoke_menu_fn '' action_34_normalize_names >/tmp/djpt_media_34.out
test -f "$PLANS_DIR/normalize_names_plan.tsv"
rg -q $'audio/Album A/Áudio\\?\\?\\.mp3\t.*\tRENAME' "$PLANS_DIR/normalize_names_plan.tsv"

invoke_menu_fn '' action_35_samples_by_type >/tmp/djpt_media_35.out
test -f "$PLANS_DIR/samples_by_type_plan.tsv"
rg -q '.*/kick_loop.wav\tKICK' "$PLANS_DIR/samples_by_type_plan.tsv"
rg -q '.*/snare_hit.wav\tSNARE' "$PLANS_DIR/samples_by_type_plan.tsv"
rg -q '.*/hat_closed.wav\tHAT' "$PLANS_DIR/samples_by_type_plan.tsv"

invoke_menu_fn $'2\nmixcloud.com\nb\n' action_37_web_whitelist_manager >/tmp/djpt_media_37_add.out
rg -q 'WEB_WHITELIST=.*mixcloud.com' "$CONFIG_DIR/djpt.conf"

invoke_menu_fn $'1\nb\n' submenu_36_web_clean >/tmp/djpt_media_36.out
rg -q 'mixcloud.com' /tmp/djpt_media_36.out
rg -q 'youtube.com' /tmp/djpt_media_36.out

printf 'https://mixcloud.com/keep-set\n' >> "$BASE/audio/web_playlist.m3u8"
invoke_menu_fn '' action_38_clean_web_playlists >/tmp/djpt_media_38.out
rg -Fq 'https://youtube.com/watch?v=keep' "$BASE/audio/web_playlist.m3u8"
rg -Fq 'https://mixcloud.com/keep-set' "$BASE/audio/web_playlist.m3u8"
rg -Fq 'local_track.mp3' "$BASE/audio/web_playlist.m3u8"
if rg -Fq 'https://example.com/remove' "$BASE/audio/web_playlist.m3u8"; then
  echo "example.com should have been removed"
  exit 1
fi

invoke_menu_fn '' action_39_clean_web_tags >/tmp/djpt_media_39.out
test -f "$PLANS_DIR/clean_web_tags_plan.tsv"
rg -q '.*/Áudio\?\?\.mp3\tCLEAN_WEB_TAGS' "$PLANS_DIR/clean_web_tags_plan.tsv"
rg -q '.*/kick_loop.wav\tCLEAN_WEB_TAGS' "$PLANS_DIR/clean_web_tags_plan.tsv"

invoke_menu_fn $'4\nb\n' action_37_web_whitelist_manager >/tmp/djpt_media_37_reset.out
if rg -q 'mixcloud.com' "$CONFIG_DIR/djpt.conf"; then
  echo "mixcloud.com should not remain after reset"
  exit 1
fi

printf "PASS non_ai_media_web_block_sacrificial\n"
