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
. ./DJProducerTools_MultiScript_EN.sh

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
    assert_false "grep -q 'path1' '$history_file'" "Should remove the oldest entry from a full file"

    # Test 5: Add a non-existent directory
    local before_content; before_content=$(cat "$history_file")
    append_history "$history_file" "/tmp/djpt_test_history/non_existent"
    assert_equals "$before_content" "$(cat "$history_file")" "Should not add a non-existent directory"
}

# --- Test Runner ---
run_tests() {
    mapfile -t test_functions < <(declare -F | awk '{print $3}' | grep '^test_')

    for test_func in "${test_functions[@]}"; do
        "$test_func"
    done

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