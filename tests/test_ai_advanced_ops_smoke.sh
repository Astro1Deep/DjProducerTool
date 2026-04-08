#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_CANONICAL="$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/djpt-ai-smoke-XXXXXX")"
BASE_LIB="$WORK_DIR/library"
STATE_REPORTS="$BASE_LIB/_DJProducerTools/reports"
MOCK_BIN="$WORK_DIR/mock-bin"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$BASE_LIB" "$MOCK_BIN"

cat >"$MOCK_BIN/ollama" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
case "$cmd" in
  list)
    printf "NAME\tID\tSIZE\tMODIFIED\n"
    exit 0
    ;;
  run)
    printf "mock-ollama-response\n"
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "$MOCK_BIN/ollama"

python3 - "$BASE_LIB" <<'PY'
import math
import struct
import sys
import wave

base = sys.argv[1]
sample_rate = 22050
duration = 0.5
tones = [
    ("tone_a.wav", 220.0),
    ("tone_b.wav", 440.0),
    ("tone_c.wav", 880.0),
]

for name, freq in tones:
    path = f"{base}/{name}"
    frames = int(sample_rate * duration)
    with wave.open(path, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        for i in range(frames):
            sample = int(0.3 * 32767 * math.sin(2 * math.pi * freq * (i / sample_rate)))
            wav.writeframes(struct.pack("<h", sample))
PY

run_with_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout 180 "$@"
    return
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout 180 "$@"
    return
  fi
  "$@"
}

run_action() {
  local action="$1"
  PATH="$MOCK_BIN:$PATH" \
  HOME_OVERRIDE="$BASE_LIB" \
  DJPT_NO_INTERACTIVE=1 \
  NO_INTERACTIVE=1 \
  DJPT_STEMS_BACKEND=hpss \
  run_with_timeout bash "$SCRIPT_CANONICAL" --no-interactive --run "$action" >/dev/null
}

count_matches() {
  local pattern="$1"
  find "$STATE_REPORTS" -type f -name "$pattern" 2>/dev/null | wc -l | tr -d ' '
}

assert_artifact_created() {
  local pattern="$1"
  local action="$2"
  mkdir -p "$STATE_REPORTS"
  local before after
  before="$(count_matches "$pattern")"
  run_action "$action"
  after="$(count_matches "$pattern")"
  if [ "$after" -le "$before" ]; then
    echo "[FAIL] action=$action did not create artifact matching $pattern"
    exit 1
  fi
  echo "[OK] action=$action artifact=$pattern"
}

assert_artifact_created "mlx_batch_*" "mlx_batch"
assert_artifact_created "tf_spectral_*" "tf_spectral"
assert_artifact_created "tf_genre_*" "tf_genre"
assert_artifact_created "tf_bpm_*" "tf_bpm"

mkdir -p "$STATE_REPORTS"
before_stems="$(find "$STATE_REPORTS" -type f -path "*/stems_*/manifest.tsv" 2>/dev/null | wc -l | tr -d ' ')"
run_action "tf_stems"
after_stems="$(find "$STATE_REPORTS" -type f -path "*/stems_*/manifest.tsv" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$after_stems" -le "$before_stems" ]; then
  echo "[FAIL] action=tf_stems did not create manifest.tsv"
  exit 1
fi
echo "[OK] action=tf_stems artifact=stems_*/manifest.tsv"

assert_artifact_created "local_clustering_*" "local_cluster"
assert_artifact_created "local_recommendations_*" "local_recommend"
assert_artifact_created "local_similarity_*" "local_similarity"
assert_artifact_created "local_popularity_*" "local_popularity"
assert_artifact_created "ollama_chat_library_*" "ollama_chat"
assert_artifact_created "ollama_playlist_*" "ollama_playlist"
assert_artifact_created "ollama_music_analysis_*" "ollama_music"

echo "[PASS] AI advanced smoke completed"
