#!/usr/bin/env bash
# 🧬 SYSTEM PROFILER & ENVIRONMENT DIAGNOSTIC (GENIUS EDITION)
# Autor: IA Architect
# Propósito: Autoconsciencia del sistema (Hardware, OS, Dependencias, Contexto)

# set -u # Desactivado para evitar cierres

# Colores (Compatibles con el sistema cuántico)
C_GRN='\033[32m'
C_RED='\033[31m'
C_YLW='\033[33m'
C_BLU='\033[34m'
C_RST='\033[0m'
C_BOLD='\033[1m'

# ==============================================================================
# 1. HARDWARE & OS SENSORS
# ==============================================================================

get_os_info() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "$(sw_vers -productVersion) (macOS)"
    else
        if [ -f /etc/os-release ]; then
            grep PRETTY_NAME /etc/os-release | cut -d'"' -f2
        else
            uname -sr
        fi
    fi
}

get_cpu_info() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sysctl -n machdep.cpu.brand_string
    else
        grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | xargs
    fi
}

get_ram_info() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local bytes=$(sysctl -n hw.memsize)
        echo "$bytes bytes ($(echo "$bytes / 1024 / 1024 / 1024" | bc) GB)"
    else
        free -h | awk '/^Mem:/ {print $2}'
    fi
}

get_fs_info() {
    # Espacio libre en el disco actual
    df -h . | awk 'NR==2 {print $4 " free on " $1}'
}

# ==============================================================================
# 2. DEPENDENCY SCANNERS
# ==============================================================================

check_dep() {
    local cmd="$1"
    local name="$2"
    if command -v "$cmd" &> /dev/null; then
        echo "OK"
        return 0
    else
        echo "MISSING"
        return 1
    fi
}

check_clt() {
    if xcode-select -p &> /dev/null; then
        echo "OK"
    else
        echo "MISSING"
    fi
}

# ==============================================================================
# 3. CONTEXT AWARENESS (MOTHER STRUCTURE)
# ==============================================================================

analyze_structure() {
    local root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    local status="UNKNOWN"
    local details=""

    if [ -d "$root_dir/.quantum_state" ] && [ -f "$root_dir/djpt_quantum_launcher.sh" ]; then
        if [ -d "$root_dir/_archive" ]; then
            status="QUANTUM_EVOLVED"
            details="(Sistema actualizado desde versión previa)"
        else
            status="FRESH_QUANTUM"
            details="(Instalación limpia detectada)"
        fi
    elif [ -f "$root_dir/DJProducerTools_MultiScript_ES.sh" ]; then
        status="LEGACY_DETECTED"
        details="(Estructura antigua presente)"
    else
        status="FRESH_INSTALL"
        details="(Sin rastros previos)"
    fi
    echo "$status $details"
}

# ==============================================================================
# 🚀 MAIN DIAGNOSTIC ROUTINE
# ==============================================================================

run_diagnostics() {
    echo ""
    echo -e "${C_BOLD}📊 SYSTEM DIAGNOSTICS (GENIUS PROFILER)${C_RST}"
    echo "=================================================="
    
    # Detección
    local os_ver=$(get_os_info)
    local arch=$(uname -m)
    local cpu=$(get_cpu_info)
    local ram=$(get_ram_info)
    local fs=$(get_fs_info)
    local structure=$(analyze_structure)

    # Output formateado estilo Genio
    echo -e "${C_BLU}OS:${C_RST}   $os_ver"
    echo -e "${C_BLU}ARCH:${C_RST} $arch"
    echo -e "${C_BLU}CPU:${C_RST}  $cpu"
    echo -e "${C_BLU}RAM:${C_RST}  $ram"
    echo -e "${C_BLU}FS:${C_RST}   $fs"
    echo -e "${C_BLU}MODE:${C_RST} $structure"
    echo ""

    # Dependencias
    local deps=("brew:brew" "python3:python3" "pip3:pip" "ffprobe:ffprobe" "rsync:rsync")
    local all_ok=true

    for d in "${deps[@]}"; do
        IFS=":" read -r cmd label <<< "$d"
        local status=$(check_dep "$cmd" "$label")
        if [ "$status" == "OK" ]; then
            echo -e "[${C_GRN}OK${C_RST}] $label: OK"
        else
            echo -e "[${C_RED}XX${C_RST}] $label: MISSING"
            all_ok=false
        fi
    done

    # Check especial CLT
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local clt_status=$(check_clt)
        if [ "$clt_status" == "OK" ]; then
             echo -e "[${C_GRN}OK${C_RST}] CLT: OK"
        else
             echo -e "[${C_RED}XX${C_RST}] CLT: MISSING (Run xcode-select --install)"
             all_ok=false
        fi
    fi

    echo "=================================================="
    
    if [ "$all_ok" = false ]; then
        echo -e "${C_YLW}⚠️  ADVERTENCIA: Faltan dependencias críticas. El sistema podría no funcionar al 100%.${C_RST}"
        # No salimos (exit 1) para permitir que el script padre decida si continuar o intentar instalar
        return 1
    else
        return 0
    fi
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_diagnostics
fi
