#!/usr/bin/env bash
# Fixed test runner - avoids directory check by mocking early

SCRIPT_DIR="$(cd -- "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Color codes
C_GRN='\033[1;32m'
C_RED='\033[1;31m'
C_RESET='\033[0m'

TEST_COUNT=0
FAIL_COUNT=0

# Test framework
assert_equals() {
    TEST_COUNT=$((TEST_COUNT + 1))
    local expected="$1"
    local actual="$2"
    local message="$3"
    if [ "$expected" == "$actual" ]; then
        echo "✅ PASS: $message"
    else
        echo "❌ FAIL: $message"
        echo "   Expected: '$expected'"
        echo "   Got:      '$actual'"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_file_exists() {
    TEST_COUNT=$((TEST_COUNT + 1))
    local file="$1"
    local message="$2"
    if [ -f "$file" ]; then
        echo "✅ PASS: $message"
    else
        echo "❌ FAIL: $message (File not found: $file)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_dir_exists() {
    TEST_COUNT=$((TEST_COUNT + 1))
    local dir="$1"
    local message="$2"
    if [ -d "$dir" ]; then
        echo "✅ PASS: $message"
    else
        echo "❌ FAIL: $message (Directory not found: $dir)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# Test script syntax
test_syntax() {
    echo -e "\n=== Testing Script Syntax ==="
    bash -n DJProducerTools_MultiScript_EN.sh >/dev/null 2>&1
    assert_equals "0" "$?" "English script syntax is valid"
    
    bash -n DJProducerTools_MultiScript_ES.sh >/dev/null 2>&1
    assert_equals "0" "$?" "Spanish script syntax is valid"
}

# Test Python syntax
test_python_syntax() {
    echo -e "\n=== Testing Python Syntax ==="
    if command -v python3 >/dev/null 2>&1; then
        python3 -m py_compile *.py >/dev/null 2>&1
        assert_equals "0" "$?" "Python files compile without syntax errors"
    fi
}

# Test file structure
test_file_structure() {
    echo -e "\n=== Testing File Structure ==="
    assert_file_exists "DJProducerTools_MultiScript_EN.sh" "English main script exists"
    assert_file_exists "DJProducerTools_MultiScript_ES.sh" "Spanish main script exists"
    assert_file_exists "README.md" "README.md exists"
    assert_file_exists "LICENSE.md" "LICENSE.md exists"
    assert_dir_exists "tests" "Tests directory exists"
    assert_dir_exists "docs" "Documentation directory exists"
}

# Test executability
test_executability() {
    echo -e "\n=== Testing Executability ==="
    [ -x DJProducerTools_MultiScript_EN.sh ]
    assert_equals "0" "$?" "English script is executable"
    
    [ -x DJProducerTools_MultiScript_ES.sh ]
    assert_equals "0" "$?" "Spanish script is executable"
}

# Summary
run_all_tests() {
    test_syntax
    test_python_syntax
    test_file_structure
    test_executability
    
    echo -e "\n=== Test Summary ==="
    if [ "$FAIL_COUNT" -eq 0 ]; then
        echo -e "${C_GRN}✅ All $TEST_COUNT tests passed!${C_RESET}"
        rc=0
    else
        echo -e "${C_RED}❌ $FAIL_COUNT of $TEST_COUNT tests failed!${C_RESET}"
        rc=1
    fi
    if [ "${DJPT_PAUSE_AT_END:-0}" -eq 1 ]; then
        read -rp "Press Enter to exit..."
    fi
    return $rc
}

run_all_tests
exit $?
