#!/usr/bin/env bash
# Progress bar, spinner, and debugging utilities for DJProducerTools
# Provides visual feedback during long-running operations

# Initialize progress variables
PROGRESS_CURRENT=0
PROGRESS_TOTAL=100
PROGRESS_START_TIME=$(date +%s)
SPINNER_PID=""

# Color codes
C_RESET='\033[0m'
C_RED='\033[1;31m'
C_GRN='\033[1;32m'
C_YLW='\033[1;33m'
C_BLU='\033[1;34m'
C_CYN='\033[1;36m'
C_PURP='\033[38;5;129m'
C_WHT='\033[1;37m'
C_GRAY='\033[0;37m'

# Ghost spinner frames with colors
GHOST_FRAMES=('◐' '◓' '◑' '◒')
GHOST_COLORS=("${C_PURP}" "${C_CYN}" "${C_GRN}" "${C_BLU}")

# Standard spinner frames
SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

# Start ghost spinner
start_ghost_spinner() {
    local message="${1:-Processing}"
    local frame_idx=0
    
    while true; do
        printf "\r${GHOST_COLORS[$frame_idx]}${GHOST_FRAMES[$frame_idx]}${C_RESET} ${message}   "
        frame_idx=$(( (frame_idx + 1) % ${#GHOST_FRAMES[@]} ))
        sleep 0.15
    done &
    
    SPINNER_PID=$!
}

# Stop spinner
stop_spinner() {
    if [ -n "$SPINNER_PID" ] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill $SPINNER_PID 2>/dev/null
        wait $SPINNER_PID 2>/dev/null
        printf "\r                                        \r"
        SPINNER_PID=""
    fi
}

# Show progress bar
progress_bar() {
    local current=$1
    local total=$2
    local label="${3:-Progress}"
    local bar_length=40
    
    PROGRESS_CURRENT=$current
    PROGRESS_TOTAL=$total
    
    local percent=$((current * 100 / total))
    local filled=$((bar_length * current / total))
    local empty=$((bar_length - filled))
    
    # Build bar
    local bar="${C_GRN}"
    for ((i = 0; i < filled; i++)); do bar+="█"; done
    bar+="${C_GRAY}"
    for ((i = 0; i < empty; i++)); do bar+="░"; done
    bar+="${C_RESET}"
    
    # Calculate elapsed and estimated time
    local now=$(date +%s)
    local elapsed=$((now - PROGRESS_START_TIME))
    local rate=$((current > 0 ? elapsed / current : 0))
    local remaining=$((rate * (total - current)))
    
    printf "\r${label}: ${bar} ${C_BLU}${percent}%%${C_RESET} [${current}/${total}] (${elapsed}s elapsed, ~${remaining}s remaining)  "
}

# Debug print
debug_print() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%H:%M:%S')
    
    case "$level" in
        INFO)
            printf "${C_BLU}[${timestamp}]${C_RESET} ${C_CYN}ℹ${C_RESET} ${message}\n" >&2
            ;;
        SUCCESS)
            printf "${C_BLU}[${timestamp}]${C_RESET} ${C_GRN}✓${C_RESET} ${message}\n" >&2
            ;;
        WARN)
            printf "${C_BLU}[${timestamp}]${C_RESET} ${C_YLW}⚠${C_RESET} ${message}\n" >&2
            ;;
        ERROR)
            printf "${C_BLU}[${timestamp}]${C_RESET} ${C_RED}✗${C_RESET} ${message}\n" >&2
            ;;
        DEBUG)
            if [ "${DEBUG_MODE:-0}" -eq 1 ]; then
                printf "${C_BLU}[${timestamp}]${C_RESET} ${C_PURP}⚙${C_RESET} ${message}\n" >&2
            fi
            ;;
        *)
            printf "${C_BLU}[${timestamp}]${C_RESET} ${message}\n" >&2
            ;;
    esac
}

# Trace function execution
trace_function() {
    local func_name="$1"
    local func_args="${@:2}"
    
    if [ "${DEBUG_MODE:-0}" -eq 1 ]; then
        debug_print DEBUG "→ Entering: ${C_PURP}${func_name}${C_RESET}(${func_args})"
    fi
}

# Trace function exit
trace_exit() {
    local func_name="$1"
    local exit_code="${2:-0}"
    
    if [ "${DEBUG_MODE:-0}" -eq 1 ]; then
        if [ $exit_code -eq 0 ]; then
            debug_print DEBUG "← Exiting: ${C_GRN}${func_name}${C_RESET} [code: $exit_code]"
        else
            debug_print DEBUG "← Exiting: ${C_RED}${func_name}${C_RESET} [code: $exit_code]"
        fi
    fi
}

# Measure function execution time
time_function() {
    local func_name="$1"
    shift
    local start=$(date +%s%N)
    
    debug_print INFO "Starting ${func_name}..."
    "$@"
    local exit_code=$?
    
    local end=$(date +%s%N)
    local duration=$((($end - $start) / 1000000))
    local ms=$((duration % 1000))
    local s=$(($duration / 1000))
    
    if [ $exit_code -eq 0 ]; then
        debug_print SUCCESS "${func_name} completed in ${s}.${ms}ms"
    else
        debug_print ERROR "${func_name} failed with code $exit_code (${s}.${ms}ms)"
    fi
    
    return $exit_code
}

# Show step in a multi-step process
step_start() {
    local step_num="$1"
    local total_steps="$2"
    local description="$3"
    
    printf "\n${C_BLU}▶${C_RESET} Step ${step_num}/${total_steps}: ${C_CYN}${description}${C_RESET}\n"
}

# Show step completion
step_complete() {
    local step_num="$1"
    local total_steps="$2"
    
    printf "${C_GRN}✓${C_RESET} Step ${step_num}/${total_steps} complete\n"
}

# Show live command execution with output
run_with_output() {
    local label="$1"
    shift
    local command="$@"
    
    debug_print INFO "Running: ${C_CYN}${command}${C_RESET}"
    eval "$command" 2>&1 | while IFS= read -r line; do
        printf "  ${C_GRAY}│${C_RESET} ${line}\n"
    done
    
    return ${PIPESTATUS[0]}
}

# Memory/resource usage tracker
check_resources() {
    local threshold_mb="${1:-500}"
    
    if command -v free >/dev/null 2>&1; then
        local free_mem=$(free -m | awk '/^Mem:/ {print $7}')
        if [ "$free_mem" -lt "$threshold_mb" ]; then
            debug_print WARN "Low memory: ${free_mem}MB available (threshold: ${threshold_mb}MB)"
            return 1
        fi
    fi
    return 0
}

# Cleanup spinners on exit
cleanup_progress() {
    stop_spinner
    printf "\n"
}

trap cleanup_progress EXIT

export -f start_ghost_spinner stop_spinner progress_bar debug_print
export -f trace_function trace_exit time_function step_start step_complete
export -f run_with_output check_resources
