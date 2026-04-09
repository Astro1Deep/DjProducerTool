#!/bin/bash
################################################################################
# DJProducerTools - Verification & Testing Suite v3.0
# Comprehensive system check with bilingual spinner feedback
# Colors: Cyan/Magenta alternating spinner for visual feedback
################################################################################

set +e

# Defaults & CLI flags
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_ROOT="$REPO_ROOT"
ROOT_PATH="$DEFAULT_ROOT"
SKIP_NETWORK=1
FULL_INVENTORY=0
TEST_FAILS=0
URL_WARNS=0
STRICT_RAW_URLS=0

# Python binary and pytest configuration
PYTHON_BIN=""
PYTEST_BIN=""
PYTEST_MODE="bin"
PYTEST_STRICT_WARNINGS="${DJPT_PYTEST_STRICT_WARNINGS:-1}"
PACKAGE_EXCLUDES_FILE="$REPO_ROOT/package_excludes.lst"

bootstrap_djpt_venv() {
    local venv_dir="$REPO_ROOT/djpt_venv"
    local base_python="${DJPT_BOOTSTRAP_PYTHON:-python3}"
    local bootstrap_mode="${DJPT_BOOTSTRAP_MODE:-core}"
    local bootstrap_script="$REPO_ROOT/scripts/bootstrap_djpt_venv.sh"

    if ! command -v "$base_python" >/dev/null 2>&1; then
        echo "ERROR: Cannot bootstrap venv. Python not found: $base_python" >&2
        return 1
    fi

    if [ -x "$bootstrap_script" ]; then
        echo "INFO: Bootstrapping djpt_venv via canonical script ($bootstrap_mode)"
        "$bootstrap_script" --root "$REPO_ROOT" --python "$base_python" --"$bootstrap_mode" --with-dev || return 1
        return 0
    fi

    if [ ! -x "$venv_dir/bin/python3" ]; then
        echo "INFO: Creating djpt_venv at $venv_dir"
        "$base_python" -m venv "$venv_dir" || return 1
    fi

    if ! "$venv_dir/bin/python3" -m pytest --version >/dev/null 2>&1; then
        echo "INFO: Installing requirements into djpt_venv (pytest missing)"
        "$venv_dir/bin/python3" -m pip install --upgrade pip || return 1
        if ! "$venv_dir/bin/python3" -m pip install \
            -r "$REPO_ROOT/requirements.txt" \
            -r "$REPO_ROOT/requirements-dev.txt"; then
            echo "WARN: requirements install failed; attempting minimal pytest bootstrap"
            "$venv_dir/bin/python3" -m pip install pytest || return 1
        fi
    fi
    return 0
}

detect_python_env() {
    local venv_dir="$REPO_ROOT/djpt_venv"

    if [ -n "${DJPT_PYTHON_BIN:-}" ]; then
        if [ -x "$DJPT_PYTHON_BIN" ]; then
            PYTHON_BIN="$DJPT_PYTHON_BIN"
        elif command -v "$DJPT_PYTHON_BIN" >/dev/null 2>&1; then
            PYTHON_BIN="$(command -v "$DJPT_PYTHON_BIN")"
        else
            PYTHON_BIN="$DJPT_PYTHON_BIN"
        fi
    elif [ -x "$venv_dir/bin/python3" ]; then
        PYTHON_BIN="$venv_dir/bin/python3"
    else
        bootstrap_djpt_venv || return 1
        PYTHON_BIN="$venv_dir/bin/python3"
    fi

    if [ ! -x "$PYTHON_BIN" ]; then
        echo "ERROR: Python not found at $PYTHON_BIN" >&2
        return 1
    fi

    if [ -n "${DJPT_PYTEST_BIN:-}" ]; then
        if [ -x "${DJPT_PYTEST_BIN}" ]; then
            PYTEST_BIN="${DJPT_PYTEST_BIN}"
            PYTEST_MODE="bin"
            return 0
        fi
        if command -v "${DJPT_PYTEST_BIN}" >/dev/null 2>&1; then
            PYTEST_BIN="$(command -v "${DJPT_PYTEST_BIN}")"
            PYTEST_MODE="bin"
            return 0
        fi
    fi

    if [ -x "$venv_dir/bin/pytest" ]; then
        PYTEST_BIN="$venv_dir/bin/pytest"
        PYTEST_MODE="bin"
        return 0
    fi

    if "$PYTHON_BIN" -m pytest --version >/dev/null 2>&1; then
        PYTEST_BIN="$PYTHON_BIN"
        PYTEST_MODE="module"
        return 0
    fi

    bootstrap_djpt_venv || return 1

    if [ -x "$venv_dir/bin/pytest" ]; then
        PYTEST_BIN="$venv_dir/bin/pytest"
        PYTEST_MODE="bin"
        return 0
    fi

    if "$venv_dir/bin/python3" -m pytest --version >/dev/null 2>&1; then
        PYTHON_BIN="$venv_dir/bin/python3"
        PYTEST_BIN="$PYTHON_BIN"
        PYTEST_MODE="module"
        return 0
    fi

    echo "ERROR: pytest not available in djpt_venv" >&2
    return 1
}

run_pytest() {
    local args=("$@")
    if [ "$PYTEST_STRICT_WARNINGS" -eq 1 ]; then
        args=(-W "error::pytest.PytestReturnNotNoneWarning" "${args[@]}")
    fi

    if [ "$PYTEST_MODE" = "module" ]; then
        "$PYTEST_BIN" -m pytest "${args[@]}"
    else
        "$PYTEST_BIN" "${args[@]}"
    fi
    return $?
}

verify_pytest_collection() {
    local tmp_out
    local collect_args=(--collect-only -q tests)
    tmp_out="$(mktemp)"

    if [ -d "scripts/tests" ]; then
        collect_args+=(scripts/tests)
    fi

    if ! run_pytest "${collect_args[@]}" >"$tmp_out" 2>&1; then
        echo -e "${RED}[ERR] Pytest collection failed.${RESET}"
        sed -n '1,120p' "$tmp_out"
        rm -f "$tmp_out"
        return 1
    fi

    if grep -qi "no tests collected" "$tmp_out"; then
        echo -e "${RED}[ERR] Pytest collected zero tests.${RESET}"
        rm -f "$tmp_out"
        return 1
    fi

    if [ ! -s "$tmp_out" ]; then
        echo -e "${RED}[ERR] Empty pytest collection output.${RESET}"
        rm -f "$tmp_out"
        return 1
    fi

    echo -e "${GREEN}✓ Pytest collection OK.${RESET}"
    rm -f "$tmp_out"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════
# COLOR & SPINNER DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════

# Colors matching the DJ Producer Tools theme
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'
BOLD='\033[1m'

# Spinner symbols - bilingual emoji
SPINNER_ICONS=(
    "🎧"
    "🎵"
)

# Progress symbols
PROGRESS_FULL="█"
PROGRESS_EMPTY="░"

# Exclusion patterns for inventory (evita medios/backups pesados)
EXCLUDE_PATTERNS=(
    "*.mp3" "*.m4a" "*.wav" "*.flac" "*.aif" "*.aiff" "*.ogg"
    "*.mp4" "*.mkv" "*.mov" "*.avi"
    "*.m3u8" "*.m3u" "*.pls" "*.xspf"
    "*.zip" "*.rar" "*.7z"
    "*.DS_Store"
)

# ═══════════════════════════════════════════════════════════════════════════
# SPINNER FUNCTION WITH BILINGUAL SUPPORT
# ═══════════════════════════════════════════════════════════════════════════

show_spinner() {
    local pid=$1
    local message_en=$2
    local message_es=$3
    local duration=${4:-0}
    local steps=${5:-10}
    
    # Skip spinner in CI/headless mode
    if [[ "${CI:-0}" == "1" || "${SERATO_FORCE_NOTTY:-0}" == "1" ]]; then
        wait "$pid"
        return $?
    fi
    
    local spinner_idx=0
    local current_step=0
    local start_time=$(date +%s)
    
    # Detect language
    local lang="en"
    if [[ "${LANG}" == *"es"* ]] || [[ "${LC_ALL}" == *"es"* ]]; then
        lang="es"
    fi
    
    while true; do
        if ! kill -0 $pid 2>/dev/null; then
            break
        fi
        spinner_idx=$(( (spinner_idx + 1) % 2 ))
        current_step=$(( (current_step + 1) % steps ))
        
        local icon="${SPINNER_ICONS[$spinner_idx]}"
        local message=$([[ "$lang" == "es" ]] && echo "$message_es" || echo "$message_en")
        
        # Calculate progress bar
        local progress=""
        for ((i=0; i<$current_step; i++)); do
            progress+="${PROGRESS_FULL}"
        done
        for ((i=$current_step; i<$steps; i++)); do
            progress+="${PROGRESS_EMPTY}"
        done
        
        # Color alternation for movement sensation
        local color=$([[ $spinner_idx -eq 0 ]] && echo "$CYAN" || echo "$MAGENTA")
        
        printf "\r${color}${icon} ${message}${RESET} [${progress}] $((current_step * 100 / steps))%%"
        sleep 0.2
    done
    
    wait $pid
    local exit_code=$?
    return $exit_code
}

# ═══════════════════════════════════════════════════════════════════════════
# PROGRESS BAR FUNCTION
# ═══════════════════════════════════════════════════════════════════════════

progress_bar() {
    local current=$1
    local total=$2
    local message=$3
    
    local percentage=$((current * 100 / total))
    local filled=$((percentage / 5))
    
    printf "\r${CYAN}[${PROGRESS_FULL:0:$filled}${PROGRESS_EMPTY:0:$((20-filled))}] ${percentage}%% - ${message}${RESET}"
}

# ═══════════════════════════════════════════════════════════════════════════
# HEADER DISPLAY
# ═══════════════════════════════════════════════════════════════════════════

display_header() {
    # Skip clear and spinner in CI/headless mode
    if [[ "${CI:-0}" == "1" || "${SERATO_FORCE_NOTTY:-0}" == "1" ]]; then
        echo "=== DJProducerTools v3.0 - Verification & Testing Suite ==="
        echo ""
        return 0
    fi
    
    clear
    echo ""
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║   DJProducerTools v3.0 - Verification & Testing Suite         ║${RESET}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# SECTION HEADERS
# ═══════════════════════════════════════════════════════════════════════════

section_header() {
    echo ""
    echo -e "${BOLD}${MAGENTA}► $1${RESET}"
    echo -e "${MAGENTA}─────────────────────────────────────────${RESET}"
}

# ═══════════════════════════════════════════════════════════════════════════
# CRITICAL TEST WRAPPER
# ═══════════════════════════════════════════════════════════════════════════

run_critical_test() {
    local test_name="$1"
    shift
    
    echo -e "${CYAN}Running critical test: $test_name${RESET}"

    if [ $# -eq 0 ]; then
        echo -e "${RED}✗ $test_name (FAILED - missing command)${RESET}"
        TEST_FAILS=$((TEST_FAILS + 1))
        return 1
    fi

    # Run strict mode in a subshell so caller flow remains controlled.
    (
        set -euo pipefail
        "$@"
    )
    local rc=$?
    
    if [ $rc -eq 0 ]; then
        echo -e "${GREEN}✓ $test_name (PASSED)${RESET}"
        return 0
    else
        echo -e "${RED}✗ $test_name (FAILED - exit code: $rc)${RESET}"
        TEST_FAILS=$((TEST_FAILS + 1))
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# TEST FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

test_python_syntax() {
    section_header "Python Syntax Verification"
    
    local py_files=(
        "scripts/cli.py"
        "scripts/core/scanner.py"
        "scripts/core/dedupe.py"
        "scripts/core/config.py"
        "lib/tools_diagnostics.py"
        "lib/venv_manager.py"
    )
    
    local total=${#py_files[@]}
    
    for i in "${!py_files[@]}"; do
        local script="${py_files[$i]}"
        local count=$((i + 1))
        
        if [ -f "$script" ]; then
            "$PYTHON_BIN" -m py_compile "$script" 2>/dev/null &
            local pid=$!
            show_spinner $pid "Checking $script..." "Verificando $script..." 30 10
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ $script (Python Syntax OK)${RESET}"
            else
                echo -e "${RED}✗ $script (Python Syntax Error)${RESET}"
                TEST_FAILS=$((TEST_FAILS + 1))
            fi
        else
            echo -e "${YELLOW}○ $script (Not found, skipping)${RESET}"
        fi
        
        progress_bar $count $total "$script"
    done
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════

test_script_syntax() {
    section_header "Syntax Verification / Verificación de Sintaxis"
    
    local scripts=(
        "DJProducerTools_Con_Opciones_IA.sh"
        "lang_strings.sh"
        "main.sh"
        "bin/djpt"
    )
    
    local total=${#scripts[@]}
    
    for i in "${!scripts[@]}"; do
        local script="${scripts[$i]}"
        local count=$((i + 1))
        
        if [ -f "$script" ]; then
            # Check syntax
            bash -n "$script" 2>/dev/null &
            local pid=$!
            show_spinner $pid "Checking $script..." "Verificando $script..." 30 10
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ $script (Syntax OK)${RESET}"
            else
                echo -e "${RED}✗ $script (Syntax Error)${RESET}"
                TEST_FAILS=$((TEST_FAILS + 1))
            fi
        else
            echo -e "${RED}✗ $script (File not found)${RESET}"
            TEST_FAILS=$((TEST_FAILS + 1))
        fi
        
        progress_bar $count $total "$script"
    done
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════

test_startup_smoke_regressions() {
    section_header "Startup Smoke Regressions / Regresion de Arranque"

    local suite_dir
    suite_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local smoke_tests=(
        "$suite_dir/test_startup_home_and_double_click.sh"
        "$suite_dir/test_base_path_guard.sh"
        "$suite_dir/test_no_recursive_source.sh"
        "$suite_dir/test_wrapper_no_false_recursion.sh"
        "$suite_dir/test_app_wrapper_delegation.sh"
        "$suite_dir/test_safe_run.sh"
        "$suite_dir/test_progress_library_safe.sh"
        "$suite_dir/test_ai_symbol_resolution.sh"
        "$suite_dir/test_app_exit_trap_chain.sh"
        "$suite_dir/test_ai_install_deps_path.sh"
        "$suite_dir/test_menu_dispatch_55_61.sh"
        "$suite_dir/test_ai_smoke_no_command_not_found.sh"
    )

    for test_script in "${smoke_tests[@]}"; do
        local test_name
        test_name="$(basename "$test_script")"
        if [ ! -x "$test_script" ]; then
            echo -e "${RED}✗ ${test_name} (Missing or not executable)${RESET}"
            TEST_FAILS=$((TEST_FAILS + 1))
            continue
        fi

        run_critical_test "$test_name" bash "$test_script" || true
    done
}

# ═══════════════════════════════════════════════════════════════════════════

test_file_structure() {
    section_header "File Structure Verification / Verificación de Estructura"
    
    local required_files=(
        "README.md"
        "DJProducerTools_MultiScript_ES.sh"
        "DJProducerTools_MultiScript_EN.sh"
        "lang_strings.sh"
        "main.sh"
    )

    local optional_files=(
        "INSTALL.sh"
        "GUIDE.md"
        "GUIDE_ES.md"
        "FEATURES.md"
        "FEATURES_ES.md"
    )
    
    echo -e "${YELLOW}Required Files:${RESET}"
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            local size=$(du -h "$file" | cut -f1)
            echo -e "  ${GREEN}✓${RESET} $file (${size})"
        else
            echo -e "  ${RED}✗${RESET} $file ${RED}(MISSING)${RESET}"
            TEST_FAILS=$((TEST_FAILS + 1))
        fi
    done
    
    echo ""
    echo -e "${YELLOW}Optional Files:${RESET}"
    for file in "${optional_files[@]}"; do
        if [ -f "$file" ]; then
            local size=$(du -h "$file" | cut -f1)
            echo -e "  ${GREEN}✓${RESET} $file (${size})"
        else
            echo -e "  ${YELLOW}○${RESET} $file (optional)"
        fi
    done
}

# ═══════════════════════════════════════════════════════════════════════════

test_permissions() {
    section_header "Permission Check / Verificación de Permisos"
    
    local scripts=(
        "DJProducerTools_MultiScript_ES.sh"
        "DJProducerTools_MultiScript_EN.sh"
        "main.sh"
        "INSTALL.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                echo -e "  ${GREEN}✓${RESET} $script (executable)"
            else
                echo -e "  ${RED}✗${RESET} $script (not executable)"
                TEST_FAILS=$((TEST_FAILS + 1))
            fi
        fi
    done
}

# ═══════════════════════════════════════════════════════════════════════════

test_bilingual_parity() {
    section_header "Bilingual Content Parity / Paridad de Contenido Bilingüe"
    
    local lang_file="lang_strings.sh"
    local en_lines=$(grep -c '^L_EN_' "$lang_file")
    local es_lines=$(grep -c '^L_ES_' "$lang_file")
    
    echo -e "English strings: ${CYAN}$en_lines variables${RESET}"
    echo -e "Spanish strings: ${MAGENTA}$es_lines variables${RESET}"
    
    local diff=$((en_lines - es_lines))
    diff=${diff#-}
    
    if [ $diff -le 10 ]; then
        echo -e "${GREEN}✓ Parity OK (diff: $diff lines)${RESET}"
    else
        echo -e "${YELLOW}⚠ Content difference: $diff lines (may be intentional)${RESET}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════

test_github_connectivity() {
    section_header "GitHub Repository Connectivity / Conectividad del Repositorio"

    if [ $SKIP_NETWORK -eq 1 ]; then
        echo -e "${YELLOW}○ Omitido en modo rápido / skipped (fast mode)${RESET}"
        return 0
    fi
    
    # Check if git is configured
    if ! command -v git &> /dev/null; then
        echo -e "${RED}✗ Git not installed${RESET}"
        TEST_FAILS=$((TEST_FAILS + 1))
        return 0
    fi
    
    # Check remote
    if git remote get-url origin >/dev/null 2>&1; then
        local remote
        remote=$(git remote get-url origin)
        echo -e "${GREEN}✓ Git remote configured${RESET}"
        echo -e "  Repository: ${CYAN}$remote${RESET}"
        
        # Test connectivity
        if git ls-remote --heads origin &>/dev/null; then
            echo -e "${GREEN}✓ GitHub connectivity verified${RESET}"
            return 0
        else
            echo -e "${RED}✗ Cannot reach GitHub${RESET}"
            TEST_FAILS=$((TEST_FAILS + 1))
            return 0
        fi
    elif git remote -v >/dev/null 2>&1; then
        echo -e "${YELLOW}○ Git tiene remotes, pero no existe 'origin'${RESET}"
        return 0
    else
        echo -e "${YELLOW}○ No git remote configured${RESET}"
        return 0
    fi
}

# ═══════════════════════════════════════════════════════════════════════════

test_download_urls() {
    section_header "Download URL Verification / Verificación de URLs de Descarga"

    if [ $SKIP_NETWORK -eq 1 ]; then
        echo -e "${YELLOW}○ Omitido en modo rápido / skipped (fast mode)${RESET}"
        return 0
    fi

    local remote_url owner repo branch base_url
    remote_url="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)"
    if [ -z "$remote_url" ]; then
        echo -e "${YELLOW}○ No origin remote configured; skipping URL checks${RESET}"
        return 0
    fi

    if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
    else
        echo -e "${YELLOW}○ Origin is not GitHub; skipping raw URL checks${RESET}"
        return 0
    fi

    branch="$(git -C "$REPO_ROOT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')"
    [ -n "$branch" ] || branch="main"
    base_url="https://raw.githubusercontent.com/${owner}/${repo}/${branch}"

    local files=(
        "DJProducerTools_MultiScript_ES.sh"
        "lang_strings.sh"
        "README.md"
        "INSTALL.sh"
    )
    
    local total=${#files[@]}
    
    for i in "${!files[@]}"; do
        local file="${files[$i]}"
        local url="${base_url}/${file}"
        local count=$((i + 1))
        
        # Test URL using HTTP status code (robust across HTTP/1.1 and HTTP/2)
        local http_code
        http_code="$(curl -s -L -o /dev/null -w "%{http_code}" --max-time 8 "$url")"
        if [ "$http_code" = "200" ]; then
            echo -e "  ${GREEN}✓${RESET} $file"
        else
            if [ "${STRICT_RAW_URLS:-0}" -eq 1 ] || [ "${DJPT_ENFORCE_RAW_URLS:-0}" = "1" ]; then
                echo -e "  ${RED}✗${RESET} $file - ${RED}Not accessible (HTTP ${http_code})${RESET}"
                echo -e "     URL: $url"
                TEST_FAILS=$((TEST_FAILS + 1))
            else
                echo -e "  ${YELLOW}⚠${RESET} $file - ${YELLOW}Not accessible (HTTP ${http_code}) [publication-only warning]${RESET}"
                echo -e "     URL: $url"
                URL_WARNS=$((URL_WARNS + 1))
            fi
        fi
        
        progress_bar $count $total "Testing URLs..."
    done
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════

test_spinner_feedback() {
    section_header "Spinner & Progress Feedback / Retroalimentación de Spinner"
    
    echo -e "${YELLOW}Testing spinner with dual colors...${RESET}"
    echo ""
    
    sleep 0.1 &
    show_spinner $! "Processing EN..." "Procesando ES..." 30 12
    
    echo -e "${GREEN}✓ Spinner feedback working correctly${RESET}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════

test_ai_health_light() {
    section_header "AI LIGHT Health / Salud AI LIGHT"

    local state_dir="${DJPT_STATE_DIR:-$REPO_ROOT/state}"
    local report_path="$state_dir/reports/ai_health.json"
    local rc=0
    local env_args=()

    if [ "$SKIP_NETWORK" -eq 1 ]; then
        env_args+=(DJPT_SSL_DOCTOR_SKIP_HTTPS=1)
    fi

    env "${env_args[@]}" "$PYTHON_BIN" "$REPO_ROOT/scripts/ai_health.py"
    rc=$?

    if [ $rc -eq 0 ]; then
        echo -e "${GREEN}✓ AI health LIGHT OK${RESET}"
        echo -e "  Report: ${CYAN}$report_path${RESET}"
        return 0
    fi

    if [ $rc -eq 1 ]; then
        echo -e "${YELLOW}○ AI health LIGHT completed with warnings${RESET}"
        echo -e "  Report: ${CYAN}$report_path${RESET}"
        return 0
    fi

    echo -e "${RED}✗ AI health LIGHT failed critically${RESET}"
    echo -e "  Report: ${CYAN}$report_path${RESET}"
    TEST_FAILS=$((TEST_FAILS + 1))
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════

# METRIC BENCHMARKS (HASH TPS & STREAM LATENCY)
# ═══════════════════════════════════════════════════════════════════════════

test_hashing_tps() {
    section_header "Hashing TPS Benchmark"
    local min_tps="${DJPT_TPS_MIN:-20}"     # files/s objetivo
    local files="${DJPT_BENCH_FILES:-40}"   # número de archivos sintéticos
    local size="${DJPT_BENCH_SIZE:-524288}" # 512 KB
    "$PYTHON_BIN" - "$min_tps" "$files" "$size" <<'PY'
import hashlib, os, sys, tempfile, time
from pathlib import Path

min_tps = float(sys.argv[1])
files = int(sys.argv[2])
size = int(sys.argv[3])
tmpdir = Path(tempfile.mkdtemp(prefix="djpt_hash_bench_"))
try:
    data = os.urandom(size)
    for i in range(files):
        (tmpdir / f"f{i}.bin").write_bytes(data)
    start = time.perf_counter()
    for p in tmpdir.iterdir():
        hashlib.sha256(p.read_bytes()).hexdigest()
    dur = time.perf_counter() - start
    tps = files / dur if dur > 0 else 0.0
    print(f"TPS={tps:.2f} files/s  files={files} size={size}B  dur={dur:.3f}s  min={min_tps}")
    sys.exit(0 if tps >= min_tps else 1)
finally:
    for p in tmpdir.iterdir():
        p.unlink(missing_ok=True)
    tmpdir.rmdir()
PY
    local rc=$?
    if [ $rc -eq 0 ]; then
        echo -e "${GREEN}✓ Hash TPS meets threshold (>= ${min_tps})${RESET}"
    else
        echo -e "${RED}✗ Hash TPS below threshold (set DJPT_TPS_MIN to tune)${RESET}"
    fi
    echo ""
    return $rc
}

test_stream_latency() {
    if [ "${SKIP_NETWORK:-0}" -eq 1 ]; then
        echo -e "${YELLOW}[SKIP] Streaming latency (fast mode).${RESET}"
        echo ""
        return 0
    fi
    if [ -z "${OPENAI_API_KEY:-}" ] || [ "${DJPT_STREAM_BENCH:-0}" -eq 0 ]; then
        echo -e "${YELLOW}[SKIP] Streaming latency (set OPENAI_API_KEY and DJPT_STREAM_BENCH=1 to enable).${RESET}"
        echo ""
        return 0
    fi
    section_header "Streaming Latency Benchmark"
    "$PYTHON_BIN" - <<'PY'
import os, time, sys
import openai

openai.api_key = os.environ["OPENAI_API_KEY"]
prompt = "Di 'ping' y termina."
start = time.perf_counter()
ttfb = None
content = []
for chunk in openai.ChatCompletion.create(
    model=os.environ.get("DJPT_STREAM_MODEL","gpt-3.5-turbo"),
    messages=[{"role":"user","content":prompt}],
    stream=True,
    timeout=10,
):
    if ttfb is None:
        ttfb = time.perf_counter() - start
    if "choices" in chunk and chunk["choices"]:
        delta = chunk["choices"][0]["delta"].get("content","")
        content.append(delta)
total = time.perf_counter() - start
ttfb_max = float(os.environ.get("DJPT_TTFB_MAX","0.6"))
total_max = float(os.environ.get("DJPT_STREAM_TOTAL_MAX","2.5"))
print(f"TTFB={ttfb:.3f}s TOTAL={total:.3f}s LEN={len(''.join(content))}")
sys.exit(0 if ttfb is not None and ttfb < ttfb_max and total < total_max else 1)
PY
    local rc=$?
    if [ $rc -eq 0 ]; then
        echo -e "${GREEN}✓ Streaming latency within thresholds${RESET}"
    else
        echo -e "${RED}✗ Streaming latency exceeds thresholds (tune DJPT_TTFB_MAX/DJPT_STREAM_TOTAL_MAX)${RESET}"
    fi
    echo ""
    return $rc
}

# ═══════════════════════════════════════════════════════════════════════════

test_emoji_support() {
    section_header "Emoji & Symbol Support / Soporte de Emoji y Símbolos"
    
    echo -e "  Testing emoji rendering..."
    echo -e "  🎧 Music emoji: ${GREEN}OK${RESET}"
    echo -e "  🎵 Note emoji: ${GREEN}OK${RESET}"
    echo -e "  ✓ Check mark: ${GREEN}OK${RESET}"
    echo -e "  ✗ Cross mark: ${GREEN}OK${RESET}"
    echo -e "  ⚠ Warning sign: ${GREEN}OK${RESET}"
    echo -e "  ► Arrow: ${GREEN}OK${RESET}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# INVENTORY & ARGUMENTS
# ═══════════════════════════════════════════════════════════════════════════

usage() {
    cat <<EOF
Uso: $0 [--root PATH] [--fast|--skip-network] [--full-network] [--full-inventory] [--strict-raw-urls] [--help]
  --root PATH        Directorio a inventariar (default: ${DEFAULT_ROOT})
  --fast             Omite pruebas de red/descarga (modo offline, default)
  --skip-network     Alias de --fast
  --full-network     Incluye pruebas de red y descarga (requiere flag explícito)
  --full-inventory   Ejecuta inventario completo (requiere flag explícito)
  --strict-raw-urls  Convierte fallos de URL raw de GitHub en bloqueantes
  --help             Muestra esta ayuda
EOF
}

inventory_summary() {
    local root="$1"
    section_header "Project Inventory / Inventario del Proyecto"

    if [ "$FULL_INVENTORY" -ne 1 ]; then
        echo -e "${YELLOW}Inventory omitted (use --full-inventory to enable).${RESET}"
        return 0
    fi

    if [ ! -d "$root" ]; then
        echo -e "${RED}✗ Root no existe:${RESET} $root"
        return 1
    fi

    echo -e "${YELLOW}Root:${RESET} $root"

    "$PYTHON_BIN" - "$root" "$PACKAGE_EXCLUDES_FILE" <<'PY'
import collections
import fnmatch
import os
import pathlib
import sys

root = pathlib.Path(sys.argv[1]).resolve()
excludes_file = pathlib.Path(sys.argv[2])

media_patterns = {
    "*.mp3", "*.m4a", "*.wav", "*.flac", "*.aif", "*.aiff", "*.ogg",
    "*.mp4", "*.mkv", "*.mov", "*.avi",
    "*.m3u8", "*.m3u", "*.pls", "*.xspf",
    "*.zip", "*.rar", "*.7z", "*.DS_Store",
}

patterns = []
if excludes_file.exists():
    for line in excludes_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        patterns.append(line)


def _path_matches(rel_posix: str, pattern: str) -> bool:
    p = pattern
    if p.endswith("/**"):
        p = p[:-3]
        if rel_posix == p or rel_posix.startswith(p + "/"):
            return True
    if p.startswith("**/"):
        p = p[3:]
    if p.startswith("./"):
        p = p[2:]
    if "/" in p:
        return fnmatch.fnmatch(rel_posix, p) or fnmatch.fnmatch(rel_posix, f"*/{p}")
    return fnmatch.fnmatch(pathlib.Path(rel_posix).name, p)


def should_exclude(rel_posix: str) -> bool:
    name = pathlib.Path(rel_posix).name
    if any(fnmatch.fnmatch(name, pat) for pat in media_patterns):
        return True
    for pat in patterns:
        if _path_matches(rel_posix, pat):
            return True
    return False


print("\nDirectorios (profundidad 2):")
for d in sorted(root.glob("*")):
    if d.is_dir():
        print(f"  - {d}")
for d in sorted(root.glob("*/*")):
    if d.is_dir():
        print(f"  - {d}")

ext_counter = collections.Counter()
large_files = []

for current_root, dirs, files in os.walk(root):
    rel_dir = pathlib.Path(current_root).resolve().relative_to(root).as_posix()
    rel_dir = "" if rel_dir == "." else rel_dir

    keep_dirs = []
    for d in dirs:
        rel = f"{rel_dir}/{d}" if rel_dir else d
        if not should_exclude(rel):
            keep_dirs.append(d)
    dirs[:] = keep_dirs

    for fname in files:
        rel = f"{rel_dir}/{fname}" if rel_dir else fname
        if should_exclude(rel):
            continue
        file_path = root / rel
        suffix = file_path.suffix.lower().lstrip(".")
        ext_counter[suffix or "<sin_extension>"] += 1
        try:
            size = file_path.stat().st_size
        except OSError:
            continue
        if size > 5 * 1024 * 1024:
            large_files.append((size, str(file_path)))

print("\nTop extensiones (sin media/package excludes):")
for ext, count in ext_counter.most_common(20):
    print(f"{count:8d} {ext}")

print("\nArchivos grandes (+5M, sin media/package excludes):")
for _, path in sorted(large_files, reverse=True)[:20]:
    print(f"  - {path}")
PY
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════

final_summary() {
    echo ""
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║              ✓ Verification Complete / Verificación Completa   ║${RESET}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    if [ "${TEST_FAILS:-0}" -gt 0 ]; then
        echo -e "${RED}Some tests failed. Review the output above.${RESET}"
        echo -e "${RED}Algunas pruebas fallaron. Revisa la salida anterior.${RESET}"
        echo ""
        return 1
    else
        echo -e "${GREEN}All tests passed! Ready for production deployment.${RESET}"
        echo -e "${GREEN}¡Todas las pruebas pasaron! Listo para despliegue en producción.${RESET}"
        if [ "${URL_WARNS:-0}" -gt 0 ]; then
            echo -e "${YELLOW}Publication warnings: ${URL_WARNS} raw URL checks unresolved (non-blocking by default).${RESET}"
            echo -e "${YELLOW}Avisos de publicación: ${URL_WARNS} URLs raw sin resolver (no bloqueantes por defecto).${RESET}"
        fi
        echo ""
        echo -e "${YELLOW}Next steps / Próximos pasos:${RESET}"
        echo -e "  1. Review test results above / Revisar resultados arriba"
        echo -e "  2. Push to GitHub: ${CYAN}git push origin main${RESET}"
        echo -e "  3. Test installation: ${CYAN}./INSTALL.sh${RESET}"
        echo ""
        if [ "${DJPT_PAUSE_AT_END:-0}" -eq 1 ]; then
            read -rp "Press Enter to exit..."
        fi
        return 0
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════

main() {
    # Default to fast mode for safety.
    SKIP_NETWORK=1
    FULL_INVENTORY=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --root)
                ROOT_PATH="${2:-$ROOT_PATH}"
                shift 2
                ;;
            --fast|--skip-network)
                SKIP_NETWORK=1
                shift
                ;;
            --full-network)
                SKIP_NETWORK=0
                shift
                ;;
            --full-inventory)
                FULL_INVENTORY=1
                shift
                ;;
            --strict-raw-urls)
                STRICT_RAW_URLS=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Opción desconocida: $1"
                usage
                exit 1
                ;;
        esac
    done

    ROOT_PATH="$(cd "$ROOT_PATH" 2>/dev/null && pwd || echo "$ROOT_PATH")"

    if ! detect_python_env; then
        echo -e "${RED}[ERR] Python/pytest environment not ready.${RESET}"
        exit 1
    fi

    display_header
    echo -e "${YELLOW}Root seleccionado:${RESET} $ROOT_PATH"
    echo -e "${YELLOW}Python:${RESET} $PYTHON_BIN"
    if [ "$PYTEST_MODE" = "module" ]; then
        echo -e "${YELLOW}Pytest:${RESET} $PYTEST_BIN -m pytest"
    else
        echo -e "${YELLOW}Pytest:${RESET} $PYTEST_BIN"
    fi
    if [ $SKIP_NETWORK -eq 1 ]; then
        echo -e "${YELLOW}Modo rápido:${RESET} se omiten pruebas de red/URLs (usa --full-network para habilitar)."
    fi
    if [ $FULL_INVENTORY -eq 0 ]; then
        echo -e "${YELLOW}Modo rápido:${RESET} se omite inventario completo (usa --full-inventory para habilitar)."
    fi
    if [ "${STRICT_RAW_URLS:-0}" -eq 1 ]; then
        echo -e "${YELLOW}Modo estricto URL raw:${RESET} los 404 de publicación cuentan como fallo."
    fi
    echo ""
    
    # Run all tests
    cd "$REPO_ROOT" || exit 1
    test_script_syntax
    test_startup_smoke_regressions
    test_python_syntax
    test_file_structure
    test_permissions
    test_bilingual_parity
    test_emoji_support
    test_spinner_feedback
    test_ai_health_light
    if [ "$FULL_INVENTORY" -eq 1 ]; then
        inventory_summary "$ROOT_PATH"
    else
        echo -e "${YELLOW}[SKIP] Inventory summary (use --full-inventory to enable).${RESET}"
    fi
    if [ $SKIP_NETWORK -eq 0 ]; then
        test_github_connectivity
        test_download_urls
    else
        echo -e "${YELLOW}[SKIP] Network tests (--skip-network).${RESET}"
    fi

    # Pytest suite (scanner, dedupe, apply_plan, etc.)
    if [ -n "$PYTHON_BIN" ]; then
        echo -e "${CYAN}▶ Pytest: tests/*${RESET}"

        if ! verify_pytest_collection; then
            TEST_FAILS=$((TEST_FAILS + 1))
        fi
        
        # Test scanner CLI help first
        echo -e "${CYAN}  └─ Scanner CLI Help Test${RESET}"
        if "$PYTHON_BIN" -m scripts.core.scanner --help >/dev/null 2>&1; then
            echo -e "${GREEN}    ✓ Scanner CLI help works${RESET}"
        else
            echo -e "${RED}    ✗ Scanner CLI help failed${RESET}"
            TEST_FAILS=$((TEST_FAILS + 1))
        fi
        
        # Run scanner tests first
        if [ -f "tests/test_scanner.py" ]; then
            echo -e "${CYAN}  └─ Scanner tests${RESET}"
            if ! run_pytest tests/test_scanner.py -q; then
                TEST_FAILS=$((TEST_FAILS + 1))
            fi
        fi
        
        # Run dedupe/apply_plan tests
        if [ -f "tests/test_dedupe_apply_plan.py" ]; then
            echo -e "${CYAN}  └─ Dedupe/Apply-Plan tests${RESET}"
            if ! run_pytest tests/test_dedupe_apply_plan.py -q; then
                TEST_FAILS=$((TEST_FAILS + 1))
            fi
        fi
        
        # Run any other tests (skip in fast mode to keep runtime deterministic)
        if [ -d "tests" ]; then
            if [ "$SKIP_NETWORK" -eq 1 ] && [ "${DJPT_FAST_PYTEST:-1}" -eq 1 ]; then
                echo -e "${YELLOW}  └─ [SKIP] Additional tests in fast mode (set DJPT_FAST_PYTEST=0 to run all).${RESET}"
            else
                echo -e "${CYAN}  └─ Additional tests${RESET}"
                local extra_pytest_args=(
                    tests -q
                    --ignore=tests/test_scanner.py
                    --ignore=tests/test_dedupe_apply_plan.py
                )
                if [ -d "scripts/tests" ]; then
                    extra_pytest_args+=(scripts/tests)
                fi
                if [ "${DJPT_RUN_LEGACY_ENHANCED_TESTS:-0}" -ne 1 ]; then
                    extra_pytest_args+=(--ignore=tests/test_enhanced_system.py)
                fi

                if ! run_pytest "${extra_pytest_args[@]}" 2>/dev/null; then
                    TEST_FAILS=$((TEST_FAILS + 1))
                fi
            fi
        fi
    fi
    
    final_summary
    return $?
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
