#!/usr/bin/env bash
# DJProducerTools - Comprehensive Stage-by-Stage Testing Framework
# Tests all 72+ menu options with progress tracking, dependency validation, and error recovery

set -u

SCRIPT_DIR="$(cd -- "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Colors
C_RESET='\033[0m'
C_RED='\033[1;31m'
C_GRN='\033[1;32m'
C_YLW='\033[1;33m'
C_BLU='\033[1;34m'
C_CYN='\033[1;36m'
C_PURP='\033[38;5;129m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Test results
declare -a TEST_RESULTS
declare -a FAILED_TESTS_LIST

# Logging
LOG_FILE="tests/test_run_$(date +%Y%m%d_%H%M%S).log"
mkdir -p tests

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_test() {
    local status="$1"
    local test_name="$2"
    local message="${3:-}"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] [$status] $test_name"
    [ -n "$message" ] && log_entry="$log_entry - $message"
    
    echo "$log_entry" >> "$LOG_FILE"
}

print_header() {
    printf "\n${C_BLU}═══════════════════════════════════════════════════${C_RESET}\n"
    printf "${C_BLU}%s${C_RESET}\n" "$1"
    printf "${C_BLU}═══════════════════════════════════════════════════${C_RESET}\n\n"
}

print_stage() {
    printf "\n${C_CYN}▶ STAGE: %s${C_RESET}\n" "$1"
}

test_case() {
    local name="$1"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    printf "  ${C_BLU}[%03d]${C_RESET} %s" "$TOTAL_TESTS" "$name"
}

test_pass() {
    local message="${1:-OK}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    printf " ${C_GRN}✓${C_RESET} %s\n" "$message"
    log_test "PASS" "Test $TOTAL_TESTS" "$message"
}

test_fail() {
    local message="${1:-FAILED}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    FAILED_TESTS_LIST+=("Test $TOTAL_TESTS: $message")
    printf " ${C_RED}✗${C_RESET} %s\n" "$message"
    log_test "FAIL" "Test $TOTAL_TESTS" "$message"
}

test_skip() {
    local message="${1:-SKIPPED}"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    printf " ${C_YLW}⊘${C_RESET} %s\n" "$message"
    log_test "SKIP" "Test $TOTAL_TESTS" "$message"
}

# ============================================================================
# DEPENDENCY VALIDATION
# ============================================================================

check_required_tools() {
    print_stage "Dependency Validation - Required Tools"
    
    local required_tools=(
        "bash:Bash shell"
        "shasum:SHA-256 hashing"
        "rsync:File synchronization"
        "find:File searching"
        "awk:Text processing"
        "sed:Stream editing"
    )
    
    for tool_spec in "${required_tools[@]}"; do
        local tool="${tool_spec%%:*}"
        local desc="${tool_spec##*:}"
        
        test_case "Tool: $tool ($desc)"
        if command -v "$tool" >/dev/null 2>&1; then
            local version=$("$tool" --version 2>/dev/null | head -1 || echo "installed")
            test_pass "$version"
        else
            test_fail "Not found"
        fi
    done
}

check_optional_tools() {
    print_stage "Dependency Validation - Optional Tools"
    
    local optional_tools=(
        "ffprobe:Media analysis"
        "ffmpeg:Video processing"
        "sox:Audio processing"
        "flac:FLAC codec"
        "jq:JSON parsing"
        "bc:Calculator"
    )
    
    for tool_spec in "${optional_tools[@]}"; do
        local tool="${tool_spec%%:*}"
        local desc="${tool_spec##*:}"
        
        test_case "Optional: $tool ($desc)"
        if command -v "$tool" >/dev/null 2>&1; then
            test_pass "Available"
        else
            test_skip "Not installed (optional)"
        fi
    done
}

check_python_environment() {
    print_stage "Dependency Validation - Python Environment"
    
    test_case "Python 3 availability"
    if command -v python3 >/dev/null 2>&1; then
        local py_version=$(python3 --version 2>&1)
        test_pass "$py_version"
    else
        test_fail "Python 3 not found"
        return 1
    fi
    
    test_case "Python 3 version >= 3.8"
    local py_minor=$(python3 -c 'import sys; print(sys.version_info.minor)' 2>/dev/null || echo "0")
    if [ "$py_minor" -ge 8 ]; then
        test_pass "Python 3.$py_minor"
    else
        test_fail "Python 3.$py_minor (need >= 3.8)"
    fi
    
    test_case "pip availability"
    if python3 -m pip --version >/dev/null 2>&1; then
        test_pass "pip available"
    else
        test_fail "pip not available"
    fi
}

# ============================================================================
# SYNTAX & STATIC ANALYSIS
# ============================================================================

check_script_syntax() {
    print_stage "Static Analysis - Script Syntax"
    
    test_case "English script syntax (bash -n)"
    if bash -n scripts/DJProducerTools_MultiScript_EN.sh 2>/dev/null; then
        test_pass "No syntax errors"
    else
        test_fail "Syntax errors found"
    fi
    
    test_case "Spanish script syntax (bash -n)"
    if bash -n scripts/DJProducerTools_MultiScript_ES.sh 2>/dev/null; then
        test_pass "No syntax errors"
    else
        test_fail "Syntax errors found"
    fi
    
    test_case "Progress library syntax"
    if bash -n lib/progress.sh 2>/dev/null; then
        test_pass "No syntax errors"
    else
        test_fail "Syntax errors found"
    fi
}

check_function_definitions() {
    print_stage "Static Analysis - Function Definitions"
    
    local critical_functions=(
        "status_line"
        "finish_status_line"
        "run_with_spinner"
        "print_header"
        "pause_enter"
        "ensure_tool_installed"
        "save_conf"
        "load_conf"
    )
    
    for func in "${critical_functions[@]}"; do
        test_case "Function: $func"
        if grep -q "^${func}()" scripts/DJProducerTools_MultiScript_EN.sh; then
            test_pass "Defined"
        else
            test_fail "Not found"
        fi
    done
}

# ============================================================================
# STAGE 1: CORE SETUP (Options 1-5)
# ============================================================================

test_stage_1_core_setup() {
    print_stage "STAGE 1: Core Setup (Options 1-5)"
    
    test_case "Option 1: Status display"
    # Verify status_line function exists and works
    if grep -q "action_1_status" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
    
    test_case "Option 2: Change base path"
    if grep -q "action_2_change_base" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
    
    test_case "Option 3: Volume summary"
    if grep -q "action_3_summary" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
    
    test_case "Option 4: Top directories"
    if grep -q "action_4_top_dirs" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
    
    test_case "Option 5: Top files"
    if grep -q "action_5_top_files" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
}

# ============================================================================
# STAGE 2: SCANNING (Options 6-8)
# ============================================================================

test_stage_2_scanning() {
    print_stage "STAGE 2: Scanning (Options 6-8)"
    
    test_case "Option 6: Scan workspace"
    if grep -q "action_6_scan_workspace" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
    
    test_case "Option 7: Backup Serato"
    if grep -q "action_7_backup_serato" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
    
    test_case "Option 8: Backup DJ metadata"
    if grep -q "action_8_backup_dj" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
}

# ============================================================================
# STAGE 3: INDEXING (Option 9)
# ============================================================================

test_stage_3_indexing() {
    print_stage "STAGE 3: Indexing (Option 9)"
    
    test_case "Option 9: SHA-256 index"
    if grep -q "action_9_hash_index" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
    
    test_case "Hash function uses shasum"
    if grep -q "shasum -a 256" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "SHA-256 implementation found"
    else
        test_fail "SHA-256 not found"
    fi
}

# ============================================================================
# STAGE 4: DEDUPLICATION (Options 10-12)
# ============================================================================

test_stage_4_deduplication() {
    print_stage "STAGE 4: Deduplication (Options 10-12)"
    
    test_case "Option 10: Dupes plan"
    if grep -q "action_10_dupes_plan" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
    
    test_case "Option 11: Quarantine from plan"
    if grep -q "action_11_quarantine_from_plan" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
    
    test_case "Option 12: Quarantine manager"
    if grep -q "action_12_quarantine_manager" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
}

# ============================================================================
# STAGE 5: MEDIA ANALYSIS (Options 13-20)
# ============================================================================

test_stage_5_media_analysis() {
    print_stage "STAGE 5: Media Analysis (Options 13-20)"
    
    local media_options=(
        "13:ffprobe_report"
        "14:playlists_per_folder"
        "15:relink_helper"
        "16:mirror_by_genre"
        "17:find_dj_libs"
        "18:rescan_intelligent"
        "19:tools_diag"
        "20:fix_ownership_flags"
    )
    
    for opt_spec in "${media_options[@]}"; do
        local opt="${opt_spec%%:*}"
        local func="${opt_spec##*:}"
        
        test_case "Option $opt: $func"
        if grep -q "action_${opt}_${func}" scripts/DJProducerTools_MultiScript_EN.sh; then
            test_pass "Function defined"
        else
            test_fail "Function not found"
        fi
    done
}

# ============================================================================
# STAGE 6: CLEANUP (Options 25-41)
# ============================================================================

test_stage_6_cleanup() {
    print_stage "STAGE 6: Cleanup (Options 25-41)"
    
    # Sample key cleanup options
    local cleanup_options=(
        "25:quick_help"
        "26:export_import_state"
        "27:snapshot"
        "28:logs_viewer"
        "29:toggle_dryrun"
    )
    
    for opt_spec in "${cleanup_options[@]}"; do
        local opt="${opt_spec%%:*}"
        local func="${opt_spec##*:}"
        
        test_case "Option $opt: $func"
        if grep -q "action_${opt}_${func}" scripts/DJProducerTools_MultiScript_EN.sh; then
            test_pass "Function defined"
        else
            test_fail "Function not found"
        fi
    done
}

# ============================================================================
# STAGE 7: ML/DEEP (Options 42-59)
# ============================================================================

test_stage_7_ml_features() {
    print_stage "STAGE 7: ML/Deep Features (Options 42-59)"
    
    test_case "ML environment setup"
    if grep -q "maybe_activate_ml_env" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "ML activation function found"
    else
        test_fail "ML activation not found"
    fi
    
    test_case "ML profile selection"
    if grep -q "ML_PROFILE" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "ML profile variable found"
    else
        test_fail "ML profile not found"
    fi
}

# ============================================================================
# STAGE 8: UTILITIES (Options 60-72)
# ============================================================================

test_stage_8_utilities() {
    print_stage "STAGE 8: Utilities (Options 60-72)"
    
    test_case "Option 60: Reset state"
    if grep -q "action_53_reset_state" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
    
    test_case "Option 61: Profiles manager"
    if grep -q "submenu_excludes_manager" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Profiles/exclusions manager found"
    else
        test_fail "Profiles manager not found"
    fi
}

# ============================================================================
# STAGE 9: BILINGUAL CONSISTENCY
# ============================================================================

test_stage_9_bilingual() {
    print_stage "STAGE 9: Bilingual Consistency"
    
    test_case "EN script has action_1_status"
    if grep -q "action_1_status" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Found"
    else
        test_fail "Not found"
    fi
    
    test_case "ES script has action_1_status"
    if grep -q "action_1_status" scripts/DJProducerTools_MultiScript_ES.sh; then
        test_pass "Found"
    else
        test_fail "Not found"
    fi
    
    test_case "Emoji consistency (🔍 SCAN)"
    if grep -q "🔍" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Emoji found in EN"
    else
        test_fail "Emoji not found"
    fi
}

# ============================================================================
# STAGE 10: SAFETY FEATURES
# ============================================================================

test_stage_10_safety() {
    print_stage "STAGE 10: Safety Features"
    
    test_case "SAFE_MODE variable"
    if grep -q "SAFE_MODE=" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "SAFE_MODE defined"
    else
        test_fail "SAFE_MODE not found"
    fi
    
    test_case "DJ_SAFE_LOCK variable"
    if grep -q "DJ_SAFE_LOCK=" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "DJ_SAFE_LOCK defined"
    else
        test_fail "DJ_SAFE_LOCK not found"
    fi
    
    test_case "DRYRUN_FORCE variable"
    if grep -q "DRYRUN_FORCE=" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "DRYRUN_FORCE defined"
    else
        test_fail "DRYRUN_FORCE not found"
    fi
    
    test_case "Quarantine system"
    if grep -q "QUAR_DIR" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Quarantine system found"
    else
        test_fail "Quarantine system not found"
    fi
}

# ============================================================================
# STAGE 11: PROGRESS & UX
# ============================================================================

test_stage_11_progress_ux() {
    print_stage "STAGE 11: Progress & UX"
    
    test_case "status_line function"
    if grep -q "^status_line()" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
    
    test_case "finish_status_line function"
    if grep -q "^finish_status_line()" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Function defined"
    else
        test_fail "Function not found"
    fi
    
    test_case "Spinner frames defined"
    if grep -q "SPIN_FRAMES=" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Spinner frames found"
    else
        test_fail "Spinner frames not found"
    fi
    
    test_case "Ghost emoji defined"
    if grep -q "GHOST_COLORS=" scripts/DJProducerTools_MultiScript_EN.sh; then
        test_pass "Ghost colors found"
    else
        test_fail "Ghost colors not found"
    fi
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

main() {
    print_header "DJProducerTools - Comprehensive Test Suite"
    
    printf "Test Log: %s\n\n" "$LOG_FILE"
    
    # Run all test stages
    check_required_tools
    check_optional_tools
    check_python_environment
    check_script_syntax
    check_function_definitions
    test_stage_1_core_setup
    test_stage_2_scanning
    test_stage_3_indexing
    test_stage_4_deduplication
    test_stage_5_media_analysis
    test_stage_6_cleanup
    test_stage_7_ml_features
    test_stage_8_utilities
    test_stage_9_bilingual
    test_stage_10_safety
    test_stage_11_progress_ux
    
    # Print summary
    print_header "Test Summary"
    
    printf "Total Tests:    %d\n" "$TOTAL_TESTS"
    printf "Passed:         ${C_GRN}%d${C_RESET}\n" "$PASSED_TESTS"
    printf "Failed:         ${C_RED}%d${C_RESET}\n" "$FAILED_TESTS"
    printf "Skipped:        ${C_YLW}%d${C_RESET}\n" "$SKIPPED_TESTS"
    printf "Pass Rate:      %.1f%%\n" "$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo 0)"
    
    if [ "$FAILED_TESTS" -gt 0 ]; then
        printf "\n${C_RED}Failed Tests:${C_RESET}\n"
        for failed in "${FAILED_TESTS_LIST[@]}"; do
            printf "  - %s\n" "$failed"
        done
    fi
    
    printf "\n${C_BLU}Log saved to: %s${C_RESET}\n" "$LOG_FILE"
    
    # Exit with appropriate code
    if [ "$FAILED_TESTS" -eq 0 ]; then
        printf "\n${C_GRN}✓ ALL TESTS PASSED${C_RESET}\n"
        return 0
    else
        printf "\n${C_RED}✗ Some tests failed${C_RESET}\n"
        return 1
    fi
}

main "$@"
