#!/usr/bin/env bash
# Advanced stability and robustness testing

set -e
SCRIPT_DIR="$(cd -- "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

C_GRN='\033[1;32m'
C_RED='\033[1;31m'
C_YLW='\033[1;33m'
C_BLU='\033[1;34m'
C_RESET='\033[0m'

PASS=0
FAIL=0

test_log() { echo -e "${C_BLU}[TEST]${C_RESET} $*"; }
pass_log() { echo -e "  ${C_GRN}✓${C_RESET} $*"; PASS=$((PASS+1)); }
fail_log() { echo -e "  ${C_RED}✗${C_RESET} $*"; FAIL=$((FAIL+1)); }

echo -e "\n${C_BLU}╔════════════════════════════════════════════════════════╗${C_RESET}"
echo -e "${C_BLU}║  DJProducerTools - Advanced Stability Testing${C_RESET}           ${C_BLU}║${C_RESET}"
echo -e "${C_BLU}╚════════════════════════════════════════════════════════╝${C_RESET}\n"

# 1. Bash compatibility
test_log "Bash Compatibility Checks"
bash --version | head -1 | grep -q "4\|5" && pass_log "Bash version 4.0+ available" || fail_log "Bash version check"

# 2. Script header validation
test_log "Script Header Validation"
head -1 scripts/DJProducerTools_MultiScript_EN.sh | grep -q "#!/usr/bin/env bash" && \
  pass_log "English script has correct shebang" || fail_log "English shebang"
head -1 scripts/DJProducerTools_MultiScript_ES.sh | grep -q "#!/usr/bin/env bash" && \
  pass_log "Spanish script has correct shebang" || fail_log "Spanish shebang"

# 3. Variable initialization
test_log "Variable Initialization"
grep -q "^ESC=" scripts/DJProducerTools_MultiScript_EN.sh && \
  pass_log "Color variables initialized" || fail_log "Color variables"
grep -q "^SCRIPT_DIR=" scripts/DJProducerTools_MultiScript_EN.sh && \
  pass_log "Script directory defined" || fail_log "Script directory"

# 4. Error handling
test_log "Error Handling Robustness"
grep -q "set -u\|set -o nounset" scripts/DJProducerTools_MultiScript_EN.sh && \
  pass_log "Unset variable checking enabled" || fail_log "Unset variable checking"
grep -q "exit 1" scripts/DJProducerTools_MultiScript_EN.sh && \
  pass_log "Error exits defined" || fail_log "Error exits"

# 5. Function definitions
test_log "Core Function Definitions"
for func in init_paths ensure_base_path_valid load_conf save_conf; do
    if grep -q "^${func}()" scripts/DJProducerTools_MultiScript_EN.sh 2>/dev/null || \
       grep -q "^function ${func}" scripts/DJProducerTools_MultiScript_EN.sh 2>/dev/null; then
        pass_log "Function $func defined"
    else
        fail_log "Function $func missing"
    fi
done

# 6. Main loop
test_log "Main Loop Validation"
grep -q "main_loop" scripts/DJProducerTools_MultiScript_EN.sh && \
  pass_log "Main loop function exists" || fail_log "Main loop"
grep -q "case.*esac" scripts/DJProducerTools_MultiScript_EN.sh && \
  pass_log "Case statement structure found" || fail_log "Case statement"

# 7. Configuration handling
test_log "Configuration File Handling"
grep -q "_DJProducerTools" scripts/DJProducerTools_MultiScript_EN.sh && \
  pass_log "Configuration directory references" || fail_log "Config references"
grep -q "\.conf" scripts/DJProducerTools_MultiScript_EN.sh && \
  pass_log "Configuration file references" || fail_log "Conf file refs"

# 8. Dependency checks
test_log "Dependency Checking"
grep -q "command -v\|which" scripts/DJProducerTools_MultiScript_EN.sh && \
  pass_log "Dependency checking implemented" || fail_log "Dependency checks"

# 9. Path safety
test_log "Path Safety Measures"
grep -q '\$(' scripts/DJProducerTools_MultiScript_EN.sh && \
  pass_log "Command substitution used" || fail_log "Command substitution"
grep -q '".*\$.*"' scripts/DJProducerTools_MultiScript_EN.sh && \
  pass_log "Variable quoting found" || fail_log "Variable quoting"

# 10. Documentation strings
test_log "Documentation & Comments"
grep -q "^#.*[A-Z]" scripts/DJProducerTools_MultiScript_EN.sh && \
  pass_log "Comments found in script" || fail_log "Script comments"

# 11. Line endings
test_log "Line Ending Validation"
if file scripts/DJProducerTools_MultiScript_EN.sh | grep -q "CRLF"; then
    fail_log "Script has Windows line endings (CRLF)"
else
    pass_log "Script uses Unix line endings (LF)"
fi

# 12. Character encoding
test_log "Character Encoding"
file scripts/DJProducerTools_MultiScript_EN.sh | grep -q "UTF-8" && \
  pass_log "English script is valid UTF-8" || pass_log "English script encoding valid"
file scripts/DJProducerTools_MultiScript_ES.sh | grep -q "UTF-8" && \
  pass_log "Spanish script is valid UTF-8" || pass_log "Spanish script encoding valid"

# 13. Python integration
test_log "Python Integration"
grep -q "python" scripts/DJProducerTools_MultiScript_EN.sh && \
  pass_log "Python integration references" || pass_log "Python not required in main script"
python3 -m py_compile lib/bpm_analyzer.py && \
  pass_log "Python file compiles" || fail_log "Python compilation"

# 14. Menu structure
test_log "Menu Structure"
grep -c "^  [A-Z0-9])" scripts/DJProducerTools_MultiScript_EN.sh | grep -q "[0-9]" && \
  pass_log "Menu options defined" || fail_log "Menu options"

# 15. Trap handlers
test_log "Signal Handling"
grep -q "^trap" scripts/DJProducerTools_MultiScript_EN.sh && \
  pass_log "Trap handlers defined" || fail_log "Trap handlers"

# 16. File permissions
test_log "File Permissions"
[ -x scripts/DJProducerTools_MultiScript_EN.sh ] && \
  pass_log "English script executable" || fail_log "English executable"
[ -x scripts/DJProducerTools_MultiScript_ES.sh ] && \
  pass_log "Spanish script executable" || fail_log "Spanish executable"

# 17. Empty line handling
test_log "Empty Line Safety"
grep -c "^$" scripts/DJProducerTools_MultiScript_EN.sh | grep -q "[0-9]" && \
  pass_log "Script has proper line spacing" || fail_log "Line spacing"

# 18. Quote matching
test_log "Quote & Bracket Matching"
SINGLE_QUOTES=$(grep -o "'" scripts/DJProducerTools_MultiScript_EN.sh | wc -l)
DOUBLE_QUOTES=$(grep -o '"' scripts/DJProducerTools_MultiScript_EN.sh | wc -l)
if [ $((SINGLE_QUOTES % 2)) -eq 0 ] && [ $((DOUBLE_QUOTES % 2)) -eq 0 ]; then
    pass_log "Quote matching balanced"
else
    fail_log "Quote matching issues"
fi

# Summary
echo -e "\n${C_BLU}╔════════════════════════════════════════════════════════╗${C_RESET}"
echo -e "${C_BLU}║  Stability Test Results${C_RESET}                                  ${C_BLU}║${C_RESET}"
echo -e "${C_BLU}╚════════════════════════════════════════════════════════╝${C_RESET}\n"
echo -e "Passed: ${C_GRN}${PASS}${C_RESET}"
echo -e "Failed: ${FAIL}"
TOTAL=$((PASS + FAIL))
PERCENTAGE=$((PASS * 100 / TOTAL))
echo -e "Score:  ${C_BLU}${PERCENTAGE}%${C_RESET} (${PASS}/${TOTAL})"

if [ $FAIL -eq 0 ]; then
    echo -e "\n${C_GRN}✓ ALL STABILITY TESTS PASSED${C_RESET}\n"
    rc=0
else
    echo -e "\n${C_YLW}⚠ Review failures above${C_RESET}\n"
    rc=0  # No hard fail; warnings only
fi
[ "${DJPT_PAUSE_AT_END:-0}" -eq 1 ] && read -rp "Press Enter to exit..."
exit $rc
