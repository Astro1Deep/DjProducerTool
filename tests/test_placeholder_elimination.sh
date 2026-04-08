#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0

pass() { printf "PASS %s\n" "$1"; }
fail() { printf "FAIL %s\n" "$1"; FAILURES=$((FAILURES + 1)); }

assert_match() {
  local label="$1"
  local pattern="$2"
  local file="$3"
  if [ ! -f "$file" ]; then
    fail "$label (file not found: $file)"
    return
  fi
  if rg -q "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label (pattern not found: $pattern in $file)"
  fi
}

assert_no_match() {
  local label="$1"
  local pattern="$2"
  local file="$3"
  if [ ! -f "$file" ]; then
    fail "$label (file not found: $file)"
    return
  fi
  if rg -q "$pattern" "$file"; then
    local hit
    hit="$(rg -n "$pattern" "$file" | head -n 1)"
    fail "$label (unexpected hit: $hit)"
  else
    pass "$label"
  fi
}

assert_function_contains() {
  local label="$1"
  local file="$2"
  local function_name="$3"
  local pattern="$4"
  local block
  block="$(sed -n "/^${function_name}()/,/^}/p" "$file" 2>/dev/null || true)"
  if [ -z "$block" ]; then
    fail "$label (function not found: ${function_name} in $file)"
    return
  fi
  if printf "%s" "$block" | rg -q "$pattern"; then
    pass "$label"
  else
    fail "$label (pattern not found in ${function_name}: $pattern)"
  fi
}

# 1) No placeholder markers in patched menu scripts
for script in \
  "$ROOT_DIR/app/DJProducerTools_MultiScript_ES.sh" \
  "$ROOT_DIR/DJProducerTools_MultiScript_ES.sh" \
  "$ROOT_DIR/DJProducerTools_Con_Opciones_IA.sh" \
  "$ROOT_DIR/DJProducerTools_MultiScript_EN.sh" \
  "$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh" \
  "$ROOT_DIR/scripts/DJProducerTools_MultiScript_EN.sh"
do
  script_label="${script#$ROOT_DIR/}"
  script_label="${script_label//\//_}"
  assert_no_match "placeholder_removed_${script_label}" "Pr[oó]ximamente|en desarrollo" "$script"
done

# 2) action_40 now runs real analyzer in canonical menu variants
assert_function_contains "smart_analysis_real_es_canonical" "$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh" "action_40_smart_analysis" "smart_analyzer.py"
assert_function_contains "smart_analysis_real_en_canonical" "$ROOT_DIR/scripts/DJProducerTools_MultiScript_EN.sh" "action_40_smart_analysis" "smart_analyzer.py"

# 3) Ollama analysis action now has deterministic context + fallback
assert_function_contains "ollama_context_build_canonical_es" "$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh" "action_ollama_music_analysis" "context_report=.*ollama_music_context"
assert_function_contains "ollama_fallback_canonical_es" "$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh" "action_ollama_music_analysis" "Ollama no instalado"

# Legacy compatibility script must delegate to canonical ES menu
assert_match "legacy_wrapper_targets_canonical" 'TARGET="\$ROOT_DIR/scripts/DJProducerTools_MultiScript_ES.sh"' "$ROOT_DIR/DJProducerTools_Con_Opciones_IA.sh"
assert_match "legacy_wrapper_exec" 'exec bash "\$TARGET" "\$@"' "$ROOT_DIR/DJProducerTools_Con_Opciones_IA.sh"
assert_no_match "legacy_wrapper_no_internal_ollama_action" "^action_ollama_music_analysis\\(" "$ROOT_DIR/DJProducerTools_Con_Opciones_IA.sh"

# 4) VERIFY script must not use the broken ..venv path
assert_no_match "verify_no_dotdot_venv" "\\.\\./?venv/bin/python" "$ROOT_DIR/tests/VERIFY_AND_TEST.sh"
assert_match "verify_has_detect_python_env" "detect_python_env\\(\\)" "$ROOT_DIR/tests/VERIFY_AND_TEST.sh"
assert_match "verify_honors_override_bin" "DJPT_PYTHON_BIN" "$ROOT_DIR/tests/VERIFY_AND_TEST.sh"
assert_match "verify_has_djpt_venv_priority" "REPO_ROOT/djpt_venv" "$ROOT_DIR/tests/VERIFY_AND_TEST.sh"

# 5) smart_analyzer executable smoke
tmp_dir="$(mktemp -d /tmp/djpt-smart-test-XXXX)"
out_json="$tmp_dir/out.json"
touch "$tmp_dir/a.mp3" "$tmp_dir/b.wav" "$tmp_dir/c.mov"
python3 "$ROOT_DIR/smart_analyzer.py" --base "$tmp_dir" --out "$out_json" >/dev/null
if [ -s "$out_json" ] && rg -q '"analysis_type": "SMART_ANALYSIS"' "$out_json"; then
  pass "smart_analyzer_smoke"
else
  fail "smart_analyzer_smoke"
fi
rm -rf "$tmp_dir"

if [ "$FAILURES" -ne 0 ]; then
  printf "\n%u checks failed\n" "$FAILURES"
  exit 1
fi

printf "\nAll placeholder-elimination checks passed.\n"
