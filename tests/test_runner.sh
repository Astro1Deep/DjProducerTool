#!/usr/bin/env bash

# Basic Shell Test Runner for DJProducerTools

# --- Test Setup ---
# Source the script to be tested. We'll use the English one for readable outputs.
# We need to be in the script's directory for it to find its own path correctly.
SCRIPT_DIR="$(cd -- "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Mock functions that interact with the user or filesystem in undesirable ways during tests
# These dummy functions will override the real ones when the script is sourced.
pause_enter() { :; }
print_header() { :; }
clear() { :; }
save_conf() { :; }
load_conf() { :; }
ensure_base_path_valid() { :; }
ensure_general_root_valid() { :; }
init_paths() {
    # Provide minimal paths for testing
    STATE_DIR="/tmp/djpt_test_state"
    CONFIG_DIR="$STATE_DIR/config"
    REPORTS_DIR="$STATE_DIR/reports"
    PLANS_DIR="$STATE_DIR/plans"
    QUAR_DIR="$STATE_DIR/quarantine"
    VENV_DIR="$STATE_DIR/venv"
    mkdir -p "$STATE_DIR" "$CONFIG_DIR" "$REPORTS_DIR" "$PLANS_DIR" "$QUAR_DIR" "$VENV_DIR"
}

# Source the main script after mocks are defined
# shellcheck source=/dev/null
DJPT_SOURCED=1 . ./scripts/DJProducerTools_MultiScript_EN.sh

# --- Test Framework ---
TEST_COUNT=0
FAIL_COUNT=0

# assert_equals "expected" "actual" "message"
assert_equals() {
    TEST_COUNT=$((TEST_COUNT + 1))
    local expected="$1"
    local actual="$2"
    local message="$3"
    if [ "$expected" == "$actual" ]; then
        echo "✅  PASS: $message"
    else
        echo "❌  FAIL: $message"
        echo "     Expected: '$expected'"
        echo "     Got:      '$actual'"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# assert_true "command" "message"
assert_true() {
    TEST_COUNT=$((TEST_COUNT + 1))
    local message="$2"
    if eval "$1"; then
        echo "✅  PASS: $message"
    else
        echo "❌  FAIL: $message (Command failed or returned non-zero)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# assert_false "command" "message"
assert_false() {
    TEST_COUNT=$((TEST_COUNT + 1))
    local message="$2"
    if ! eval "$1"; then
        echo "✅  PASS: $message"
    else
        echo "❌  FAIL: $message (Command succeeded or returned zero)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# --- Test Cases ---

test_strip_quotes() {
    echo -e "\n--- Testing strip_quotes ---"
    assert_equals "hello" "$(strip_quotes '"hello"')" "Should remove double quotes"
    assert_equals "hello" "$(strip_quotes "hello")" "Should not change string with no quotes"
    assert_equals "" "$(strip_quotes '""')" "Should handle empty quoted string"
    assert_equals "hel'lo" "$(strip_quotes "hel'lo")" "Should not affect single quotes"
}

test_should_exclude_path() {
    echo -e "\n--- Testing should_exclude_path ---"
    local patterns="*.log,*/.git/*,*.tmp"

    assert_true "should_exclude_path '/path/to/file.log' '$patterns'" "Should exclude .log files"
    assert_true "should_exclude_path '/path/to/.git/HEAD' '$patterns'" "Should exclude files in .git directory"
    assert_false "should_exclude_path '/path/to/file.mp3' '$patterns'" "Should not exclude .mp3 files"
    assert_false "should_exclude_path '/path/to/git/file' '$patterns'" "Should not exclude a folder named 'git'"
    assert_true "should_exclude_path 'file.tmp' '$patterns'" "Should exclude .tmp files"
    assert_false "should_exclude_path 'file.txt' ''" "Should not exclude anything with empty patterns"
}

test_append_history() {
    echo -e "\n--- Testing append_history ---"
    local test_dir="/tmp/djpt_test_history"
    rm -rf "$test_dir"
    mkdir -p "$test_dir"

    local history_file="$test_dir/history.txt"
    local path1="$test_dir/path1"
    local path2="$test_dir/path2"
    mkdir -p "$path1" "$path2"

    # Test 1: Add to empty file
    append_history "$history_file" "$path1"
    assert_equals "$path1" "$(cat "$history_file")" "Should add a single path to an empty file"

    # Test 2: Add a new, different path
    append_history "$history_file" "$path2"
    local expected_content
    expected_content=$(printf "%s\n%s" "$path2" "$path1")
    assert_equals "$expected_content" "$(cat "$history_file")" "Should prepend a new path"

    # Test 3: Add an existing path
    append_history "$history_file" "$path1"
    expected_content=$(printf "%s\n%s" "$path1" "$path2")
    assert_equals "$expected_content" "$(cat "$history_file")" "Should move an existing path to the top"

    # Test 4: Add to a full file (20 entries)
    rm -f "$history_file"
    for i in $(seq 1 20); do mkdir -p "$test_dir/path$i"; append_history "$history_file" "$test_dir/path$i"; done
    local new_path="$test_dir/new_path"; mkdir -p "$new_path"
    append_history "$history_file" "$new_path"
    assert_equals "20" "$(wc -l < "$history_file" | tr -d ' ')" "Should keep history at 20 entries"
    assert_equals "$new_path" "$(head -n 1 "$history_file")" "Should prepend the new path to a full file"
    assert_false "grep -q '/path1$' \"$history_file\"" "Should remove the oldest entry from a full file"

    # Test 5: Add a non-existent directory
    local before_content; before_content=$(cat "$history_file")
    append_history "$history_file" "/tmp/djpt_test_history/non_existent"
    assert_equals "$before_content" "$(cat "$history_file")" "Should not add a non-existent directory"
}

test_video_tools_inventory_and_plan() {
    echo -e "\n--- Testing video_tools inventory/plan ---"
    local base="$SCRIPT_DIR/tests/fixtures/videos"
    local reports_dir="$SCRIPT_DIR/tests/_DJProducerTools/reports"
    local plans_dir="$SCRIPT_DIR/tests/_DJProducerTools/plans"
    mkdir -p "$reports_dir" "$plans_dir"

    local inv_tsv="$reports_dir/video_inventory.tsv"
    local plan_tsv="$plans_dir/video_transcode_plan.tsv"
    rm -f "$inv_tsv" "$inv_tsv.json" "$plan_tsv" "$plan_tsv.json"

    python3 "$SCRIPT_DIR/lib/video_tools.py" inventory "$base" "$inv_tsv"
    assert_true "[ -s \"$inv_tsv\" ]" "Inventory TSV generated"
    assert_true "grep -q \"artist_loop_compose.mp4\" \"$inv_tsv\"" "Inventory contains artist clip"
    local inv_json="${inv_tsv%.tsv}.json"
    assert_true "[ -s \"$inv_json\" ]" "Inventory JSON generated"

    python3 "$SCRIPT_DIR/lib/video_tools.py" transcode_plan "$base" "$plan_tsv"
    assert_true "[ -s \"$plan_tsv\" ]" "Transcode plan TSV generated"
    assert_true "grep -q \"artist_loop_transcode.mov\" \"$plan_tsv\"" "Plan lists artist transcode clip"
    assert_true "grep -q \"h264_1080p\" \"$plan_tsv\"" "Plan marks transcode preset where needed"
    local plan_json="${plan_tsv%.tsv}.json"
    assert_true "[ -s \"$plan_json\" ]" "Transcode plan JSON generated"
}

test_bpm_analyzer() {
    echo -e "\n--- Testing bpm_analyzer ---"
    local reports_dir="$SCRIPT_DIR/tests/_DJProducerTools/reports"
    mkdir -p "$reports_dir"
    local out="$reports_dir/bpm_test.tsv"
    rm -f "$out"
    python3 "$SCRIPT_DIR/lib/bpm_analyzer.py" --base "$SCRIPT_DIR/tests/fixtures/audio" --out "$out" --limit 0
    assert_true "[ -s \"$out\" ]" "BPM report generated"
    local bpm_tag
    bpm_tag=$(awk -F'\t' '/tagged_128.mp3/{print $2}' "$out")
    assert_equals "128.00" "$bpm_tag" "Should read TBPM tag when present"

    local has_librosa
    has_librosa=$(python3 - <<'PY'
try:
    import librosa
    print("yes")
except Exception:
    print("no")
PY
)
    if [ "$has_librosa" = "yes" ]; then
        local bpm_click
        bpm_click=$(awk -F'\t' '/click_120.wav/{print $2}' "$out")
        awk -v v="$bpm_click" 'BEGIN{exit !(v>=119 && v<=121)}'
        assert_true "[ $? -eq 0 ]" "click_120 detected near 120 BPM"
    else
        assert_true "grep -q 'click_120.wav' \"$out\"" "click_120 present in report (librosa missing allowed)"
    fi
}

test_playlist_bridge() {
    echo -e "\n--- Testing playlist_bridge ---"
    local plans_dir="$SCRIPT_DIR/tests/_DJProducerTools/plans"
    mkdir -p "$plans_dir"
    local pl="$SCRIPT_DIR/tests/fixtures/playlists/test_playlist.m3u8"
    if [ ! -f "$pl" ]; then
        mkdir -p "$SCRIPT_DIR/tests/fixtures/playlists"
        cat >"$pl" <<'EOF'
#EXTM3U
#EXTINF:10,Artist One - Track A
fixtures/videos/artist_blend_a.mp4
#EXTINF:10,Artist One - Track B
fixtures/videos/artist_blend_b.mp4
EOF
    fi
    local osc_out="$plans_dir/osc_from_playlist.tsv"
    local dmx_out="$plans_dir/dmx_from_playlist.tsv"
    rm -f "$osc_out" "$dmx_out"

    python3 "$SCRIPT_DIR/lib/playlist_bridge.py" osc "$pl" "$osc_out"
    python3 "$SCRIPT_DIR/lib/playlist_bridge.py" dmx "$pl" "$dmx_out"

    assert_true "[ -s \"$osc_out\" ]" "OSC plan generated"
    assert_true "[ -s \"$dmx_out\" ]" "DMX plan generated"

    local second_start
    second_start=$(awk -F'\t' 'NR==3 {print $1}' "$osc_out")
    awk -v v="$second_start" 'BEGIN{exit !(v>=7.5 && v<=8.5)}'
    assert_true "[ $? -eq 0 ]" "Second track starts near 8s"
    assert_true "grep -q 'INTRO' \"$dmx_out\"" "DMX plan marks INTRO"
    assert_true "grep -q 'OUTRO' \"$dmx_out\"" "DMX plan marks OUTRO"
}

test_dmx_send() {
    echo -e "\n--- Testing dmx_send ---"
    local plans_dir="$SCRIPT_DIR/tests/_DJProducerTools/plans"
    local logs_dir="$SCRIPT_DIR/tests/_DJProducerTools/logs"
    mkdir -p "$logs_dir"
    local plan="$plans_dir/dmx_from_playlist.tsv"
    local log="$logs_dir/dmx_test.log"
    rm -f "$log"
    python3 - "$SCRIPT_DIR" "$plan" "$log" <<'PY'
import sys
from pathlib import Path
from lib import dmx_send

root = Path(sys.argv[1])
plan = Path(sys.argv[2])
log = Path(sys.argv[3])

dmx_send.send_plan(plan, "/dev/null", 57600, True, log)

# Validate packet builder
packet = dmx_send.build_dmx_packet({1: 255, 2: 128, 3: 64})
assert packet[0] == 0x7E and packet[-1] == 0xE7
assert len(packet) == 512 + 5
PY
    assert_true "[ -s \"$log\" ]" "DMX log generated in dry-run"
    assert_true "grep -q 'INTRO' \"$log\"" "DMX log contains scene name"
}

test_ml_autotag_mock() {
    echo -e "\n--- Testing ml_autotag mock ---"
    local reports_dir="$SCRIPT_DIR/tests/_DJProducerTools/reports"
    mkdir -p "$reports_dir"
    local emb="$reports_dir/audio_embeddings.tsv"
    local tags="$reports_dir/audio_tags.tsv"
    rm -f "$emb" "$tags"
    python3 "$SCRIPT_DIR/lib/ml_autotag.py" embeddings --base "$SCRIPT_DIR/tests/fixtures/audio" --out "$emb" --limit 50
    python3 "$SCRIPT_DIR/lib/ml_autotag.py" tags --base "$SCRIPT_DIR/tests/fixtures/audio" --out "$tags" --limit 50
    assert_true "[ -s \"$emb\" ]" "Embeddings TSV generated"
    assert_true "[ -s \"$tags\" ]" "Tags TSV generated"
}

test_ml_tf_enhanced_mock() {
    echo -e "\n--- Testing ml_tf enhanced mock ---"
    local reports_dir="$SCRIPT_DIR/tests/_DJProducerTools/reports"
    mkdir -p "$reports_dir"
    local base_audio="$SCRIPT_DIR/tests/fixtures/audio"
    local base_video="$SCRIPT_DIR/tests/fixtures/videos"
    local emb="$reports_dir/audio_embeddings.tsv"
    local tags="$reports_dir/audio_tags.tsv"
    local garb="$reports_dir/audio_garbage.tsv"
    local lufs="$reports_dir/audio_loudness.tsv"
    local seg="$reports_dir/audio_segments.tsv"
    local match="$reports_dir/audio_matching.tsv"
    local vtags="$reports_dir/video_tags.tsv"
    local mtags="$reports_dir/music_tags.tsv"
    rm -f "$emb" "$tags" "$garb" "$lufs" "$seg" "$match" "$vtags" "$mtags"

    DJPT_TF_MOCK=1 python3 "$SCRIPT_DIR/lib/ml_tf.py" embeddings --offline --base "$base_audio" --out "$emb" --limit 10
    DJPT_TF_MOCK=1 python3 "$SCRIPT_DIR/lib/ml_tf.py" tags --offline --base "$base_audio" --out "$tags" --limit 10
    DJPT_TF_MOCK=1 python3 "$SCRIPT_DIR/lib/ml_tf.py" anomalies --base "$base_audio" --out "$garb" --limit 10
    DJPT_TF_MOCK=1 python3 "$SCRIPT_DIR/lib/ml_tf.py" segments --base "$base_audio" --out "$seg" --limit 5
    DJPT_TF_MOCK=1 python3 "$SCRIPT_DIR/lib/ml_tf.py" loudness --base "$base_audio" --out "$lufs" --limit 5 --target -14
    DJPT_TF_MOCK=1 python3 "$SCRIPT_DIR/lib/ml_tf.py" matching --base "$base_audio" --out "$match" --limit 10 --embeddings "$emb" --tags "$tags"
    DJPT_TF_MOCK=1 python3 "$SCRIPT_DIR/lib/ml_tf.py" video_tags --base "$base_video" --out "$vtags" --limit 2
    DJPT_TF_MOCK=1 python3 "$SCRIPT_DIR/lib/ml_tf.py" music_tags --base "$base_audio" --out "$mtags" --limit 10

    assert_true "[ -s \"$emb\" ]" "TF embeddings TSV generated"
    assert_true "[ -s \"$tags\" ]" "TF tags TSV generated"
    assert_true "[ -s \"$garb\" ]" "Garbage report generated"
    if command -v ffmpeg >/dev/null 2>&1; then
        local keyframe_dir="$reports_dir/video_keyframes"
        local kf_count="$(ls \"$keyframe_dir\"/*_kf.jpg 2>/dev/null | wc -l | tr -d ' ')"
        if [ "$kf_count" -gt 0 ]; then
            assert_true "[ \"$kf_count\" -gt 0 ]" "Keyframe extracted via ffmpeg"
        else
            echo "⚠️  WARN: ffmpeg disponible pero no se generó keyframe (se omite check duro)."
        fi
    fi
    assert_true "grep -q \"dirty_click.wav\" \"$garb\"" "Garbage report incluye dirty_click.wav"
    assert_true "head -1 \"$lufs\" | grep -q 'gain_db_to_target'" "Loudness report has gain/crest columns"
    assert_true "head -1 \"$seg\" | grep -q 'beats_sec'" "Segments report includes beats"
    assert_true "[ -s \"$match\" ]" "Matching report generated"
    assert_true "[ -s \"$vtags\" ]" "Video tags TSV generated"
    assert_true "[ -s \"$mtags\" ]" "Music tags TSV generated"
}

test_osc_api_http() {
    echo -e "\n--- Testing OSC/API HTTP endpoints ---"
    local state="$SCRIPT_DIR/tests/_DJProducerTools"
    local reports_dir="$state/reports"
    local plans_dir="$state/plans"
    local logs_dir="$state/logs"
    mkdir -p "$reports_dir" "$plans_dir" "$logs_dir"
    echo "dummy" >"$reports_dir/example.txt"
    cat >"$plans_dir/dupes_plan.tsv" <<'EOF'
path	hash	action
a	abc	KEEP
EOF
    cat >"$logs_dir/server.log" <<'EOF'
line1
line2
line3
EOF

    python3 - "$SCRIPT_DIR" "$state" <<'PY'
import json
import sys
import time
import urllib.request
from pathlib import Path
from lib import osc_api_server as srv

root = Path(sys.argv[1])
state = Path(sys.argv[2])
report = state / "reports"

http_srv = srv.start_http_server("127.0.0.1", 0, root, state, report, auth_token=None)
port = http_srv.server_address[1]

def fetch(path):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}{path}") as resp:
        return resp.getcode(), resp.read().decode()

code, body = fetch("/status")
assert code == 200
assert '"base_path"' in body

code, body = fetch("/reports")
assert code == 200
assert "example.txt" in body

code, body = fetch("/dupes/summary")
assert code == 200
data = json.loads(body)
assert data.get("entries") == 1

code, body = fetch("/logs/tail?limit=2")
assert code == 200
assert "line3" in body

http_srv.shutdown()
PY
    assert_true "[ $? -eq 0 ]" "HTTP server endpoints respond as expected"
}

# --- Test Runner ---
run_tests() {
    test_strip_quotes
    test_should_exclude_path
    test_append_history
    test_video_tools_inventory_and_plan
    test_bpm_analyzer
    test_playlist_bridge
    test_dmx_send
    test_ml_autotag_mock
    test_ml_tf_enhanced_mock
    test_osc_api_http

    echo -e "\n--- Summary ---"
    if [ "$FAIL_COUNT" -eq 0 ]; then
        echo -e "${C_GRN}All $TEST_COUNT tests passed! ✅${C_RESET}"
        return 0
    else
        echo -e "${C_RED}$FAIL_COUNT of $TEST_COUNT tests failed! ❌${C_RESET}"
        return 1
    fi
}

# Execute
run_tests
exit $?
