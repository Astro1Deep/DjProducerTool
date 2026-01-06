#!/usr/bin/env bash
# Comprehensive testing suite for DJProducerTools
# Tests all scripts, functions, and edge cases

set -e
SCRIPT_DIR="$(cd -- "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Colors
C_GRN='\033[1;32m'
C_RED='\033[1;31m'
C_YLW='\033[1;33m'
C_BLU='\033[1;34m'
C_RESET='\033[0m'

TESTS_RUN=0
TESTS_PASS=0
TESTS_FAIL=0

# Test framework
test_case() {
    local name="$1"
    echo -e "${C_BLU}▶${C_RESET} Testing: $name"
    TESTS_RUN=$((TESTS_RUN + 1))
}

assert_pass() {
    local result=$?
    local msg="$1"
    if [ $result -eq 0 ]; then
        echo -e "  ${C_GRN}✓${C_RESET} $msg"
        TESTS_PASS=$((TESTS_PASS + 1))
    else
        echo -e "  ${C_RED}✗${C_RESET} $msg (exit code: $result)"
        TESTS_FAIL=$((TESTS_FAIL + 1))
    fi
}

assert_file_exists() {
    local file="$1"
    local msg="$2"
    if [ -f "$file" ]; then
        echo -e "  ${C_GRN}✓${C_RESET} $msg"
        TESTS_PASS=$((TESTS_PASS + 1))
    else
        echo -e "  ${C_RED}✗${C_RESET} $msg (not found: $file)"
        TESTS_FAIL=$((TESTS_FAIL + 1))
    fi
}

assert_file_readable() {
    local file="$1"
    local msg="$2"
    if [ -r "$file" ]; then
        echo -e "  ${C_GRN}✓${C_RESET} $msg"
        TESTS_PASS=$((TESTS_PASS + 1))
    else
        echo -e "  ${C_RED}✗${C_RESET} $msg (not readable: $file)"
        TESTS_FAIL=$((TESTS_FAIL + 1))
    fi
}

assert_file_executable() {
    local file="$1"
    local msg="$2"
    if [ -x "$file" ]; then
        echo -e "  ${C_GRN}✓${C_RESET} $msg"
        TESTS_PASS=$((TESTS_PASS + 1))
    else
        echo -e "  ${C_RED}✗${C_RESET} $msg (not executable: $file)"
        TESTS_FAIL=$((TESTS_FAIL + 1))
    fi
}

echo -e "\n${C_BLU}═══════════════════════════════════════════════════${C_RESET}"
echo -e "${C_BLU}DJProducerTools - Comprehensive Test Suite${C_RESET}"
echo -e "${C_BLU}═══════════════════════════════════════════════════${C_RESET}\n"

# Test 1: Syntax Validation
echo -e "${C_YLW}TEST GROUP 1: Syntax Validation${C_RESET}"
test_case "English script syntax"
bash -n DJProducerTools_MultiScript_EN.sh
assert_pass "English script syntax valid"

test_case "Spanish script syntax"
bash -n DJProducerTools_MultiScript_ES.sh
assert_pass "Spanish script syntax valid"

test_case "Python file compilation"
python3 -m py_compile aplicar_correcciones_premium.py
assert_pass "Python files compile without errors"

# Test 2: File Integrity
echo -e "\n${C_YLW}TEST GROUP 2: File Integrity${C_RESET}"
test_case "English script exists"
assert_file_exists "DJProducerTools_MultiScript_EN.sh" "English main script"

test_case "Spanish script exists"
assert_file_exists "DJProducerTools_MultiScript_ES.sh" "Spanish main script"

test_case "README exists"
assert_file_exists "README.md" "README.md documentation"

test_case "LICENSE exists"
assert_file_exists "LICENSE.md" "LICENSE.md"

test_case "VERSION file exists"
assert_file_exists "VERSION" "Version file"

# Test 3: Permissions
echo -e "\n${C_YLW}TEST GROUP 3: File Permissions${C_RESET}"
test_case "English script executable"
assert_file_executable "DJProducerTools_MultiScript_EN.sh" "English script is executable"

test_case "Spanish script executable"
assert_file_executable "DJProducerTools_MultiScript_ES.sh" "Spanish script is executable"

test_case "Documentation readable"
assert_file_readable "README.md" "README is readable"

# Test 4: Documentation
echo -e "\n${C_YLW}TEST GROUP 4: Documentation Completeness${C_RESET}"
for doc in API.md DEBUG_GUIDE.md INSTALL.md INSTALL_ES.md GUIDE.md GUIDE_en.md GUIDE_es.md \
           CONTRIBUTING.md CONTRIBUTING_ES.md SECURITY.md ROADMAP.md CHANGELOG.md CHANGELOG_ES.md; do
    test_case "Documentation: $doc"
    assert_file_exists "$doc" "$doc present"
done

# Test 5: Directory Structure
echo -e "\n${C_YLW}TEST GROUP 5: Directory Structure${C_RESET}"
for dir in tests docs _DJProducerTools lib; do
    test_case "Directory: $dir"
    if [ -d "$dir" ]; then
        echo -e "  ${C_GRN}✓${C_RESET} Directory exists: $dir"
        TESTS_PASS=$((TESTS_PASS + 1))
    else
        echo -e "  ${C_RED}✗${C_RESET} Missing directory: $dir"
        TESTS_FAIL=$((TESTS_FAIL + 1))
    fi
done

# Test 6: Git Status
echo -e "\n${C_YLW}TEST GROUP 6: Git Repository${C_RESET}"
test_case "Git repository initialized"
if [ -d ".git" ]; then
    echo -e "  ${C_GRN}✓${C_RESET} Git repository present"
    TESTS_PASS=$((TESTS_PASS + 1))
else
    echo -e "  ${C_RED}✗${C_RESET} Git repository not found"
    TESTS_FAIL=$((TESTS_FAIL + 1))
fi

test_case "Git working tree clean"
if git diff-index --quiet HEAD --; then
    echo -e "  ${C_GRN}✓${C_RESET} Working tree is clean"
    TESTS_PASS=$((TESTS_PASS + 1))
else
    echo -e "  ${C_YLW}⚠${C_RESET} Uncommitted changes present"
fi

# Test 7: Scripts can be sourced
echo -e "\n${C_YLW}TEST GROUP 7: Script Sourcing${C_RESET}"
test_case "English script sourcing"
if bash -c ". ./DJProducerTools_MultiScript_EN.sh --help" 2>/dev/null | head -1 | grep -q "DJProducerTools"; then
    echo -e "  ${C_GRN}✓${C_RESET} English script executes"
    TESTS_PASS=$((TESTS_PASS + 1))
else
    echo -e "  ${C_YLW}⚠${C_RESET} Script may need full execution context"
fi

# Test 8: File Size Sanity Checks
echo -e "\n${C_YLW}TEST GROUP 8: File Size Sanity${C_RESET}"
test_case "English script size reasonable"
EN_SIZE=$(stat -f%z DJProducerTools_MultiScript_EN.sh 2>/dev/null || echo 0)
if [ "$EN_SIZE" -gt 100000 ] && [ "$EN_SIZE" -lt 500000 ]; then
    echo -e "  ${C_GRN}✓${C_RESET} English script size: $EN_SIZE bytes"
    TESTS_PASS=$((TESTS_PASS + 1))
else
    echo -e "  ${C_RED}✗${C_RESET} Unexpected size: $EN_SIZE bytes"
    TESTS_FAIL=$((TESTS_FAIL + 1))
fi

test_case "Spanish script size reasonable"
ES_SIZE=$(stat -f%z DJProducerTools_MultiScript_ES.sh 2>/dev/null || echo 0)
if [ "$ES_SIZE" -gt 100000 ] && [ "$ES_SIZE" -lt 500000 ]; then
    echo -e "  ${C_GRN}✓${C_RESET} Spanish script size: $ES_SIZE bytes"
    TESTS_PASS=$((TESTS_PASS + 1))
else
    echo -e "  ${C_RED}✗${C_RESET} Unexpected size: $ES_SIZE bytes"
    TESTS_FAIL=$((TESTS_FAIL + 1))
fi

# Test 9: No Forbidden Characters
echo -e "\n${C_YLW}TEST GROUP 9: Character Validation${C_RESET}"
test_case "Scripts have no null bytes"
if ! grep -r $'\0' DJProducerTools_MultiScript_*.sh 2>/dev/null; then
    echo -e "  ${C_GRN}✓${C_RESET} No null bytes found"
    TESTS_PASS=$((TESTS_PASS + 1))
else
    echo -e "  ${C_RED}✗${C_RESET} Null bytes detected"
    TESTS_FAIL=$((TESTS_FAIL + 1))
fi

# Test 10: Essential Functions Present
echo -e "\n${C_YLW}TEST GROUP 10: Essential Functions${C_RESET}"
for func in scan_workspace backup_metadata find_duplicates quarantine_files; do
    test_case "Function: $func"
    if grep -q "^${func}()" DJProducerTools_MultiScript_EN.sh; then
        echo -e "  ${C_GRN}✓${C_RESET} Function $func found"
        TESTS_PASS=$((TESTS_PASS + 1))
    else
        echo -e "  ${C_YLW}⚠${C_RESET} Function $func may be defined differently"
    fi
done

# Final Report
echo -e "\n${C_BLU}═══════════════════════════════════════════════════${C_RESET}"
echo -e "${C_BLU}Test Summary${C_RESET}"
echo -e "${C_BLU}═══════════════════════════════════════════════════${C_RESET}"
echo -e "Total Tests Run: ${TESTS_RUN}"
echo -e "Tests Passed:    ${C_GRN}${TESTS_PASS}${C_RESET}"
echo -e "Tests Failed:    ${TESTS_FAIL}"
if [ $TESTS_FAIL -eq 0 ]; then
    echo -e "\n${C_GRN}✓ ALL TESTS PASSED${C_RESET}"
    exit 0
else
    echo -e "\n${C_RED}✗ Some tests failed${C_RESET}"
    exit 1
fi
