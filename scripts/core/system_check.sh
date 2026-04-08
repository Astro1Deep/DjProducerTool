#!/usr/bin/env bash
# System Diagnostic & Integrity Check
# Part of DJProducerTools Quantum Ecosystem

# set -e # Desactivado para evitar cierresfail

C_GRN='\033[1;32m'
C_RED='\033[1;31m'
C_YEL='\033[1;33m'
C_RST='\033[0m'

check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        printf "[${C_GRN}OK${C_RST}] %s: OK\n" "$1"
    else
        printf "[${C_RED}FAIL${C_RST}] %s: MISSING\n" "$1"
        return 1
    fi
}

get_os_info() {
    local os_name=$(uname -s)
    local os_ver=$(uname -r)
    local arch=$(uname -m)
    local cpu_info=""
    local ram_info=""
    local fs_info="FS: $(df -h / | awk 'NR==2 {print $1}')"

    if [[ "$os_name" == "Darwin" ]]; then
        cpu_info=$(sysctl -n machdep.cpu.brand_string)
        ram_info=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024) "GB"}')
    elif [[ "$os_name" == "Linux" ]]; then
        cpu_info=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
        ram_info=$(free -h | awk '/^Mem:/ {print $2}')
    fi

    echo "OS: $os_ver ($os_name)"
    echo "ARCH: $arch"
    echo "CPU: $cpu_info"
    echo "RAM: $ram_info"
    echo "$fs_info"
    echo ""
}

run_system_check() {
    echo "Running System Diagnostics..."
    get_os_info
    
    check_cmd brew || true
    check_cmd python3 || true
    check_cmd pip3 || true
    check_cmd ffprobe || true
    check_cmd rsync || true
    
    echo "---------------------------------------------------"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_system_check
fi
