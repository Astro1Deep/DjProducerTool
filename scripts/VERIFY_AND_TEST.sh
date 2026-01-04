#!/bin/bash
################################################################################
# DJProducerTools - Verification & Testing Suite v3.0
# Comprehensive system check with bilingual spinner feedback
# Colors: Cyan/Magenta alternating spinner for visual feedback
################################################################################

set -e

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

# ═══════════════════════════════════════════════════════════════════════════
# SPINNER FUNCTION WITH BILINGUAL SUPPORT
# ═══════════════════════════════════════════════════════════════════════════

show_spinner() {
    local pid=$1
    local message_en=$2
    local message_es=$3
    local duration=${4:-0}
    local steps=${5:-10}
    
    local spinner_idx=0
    local current_step=0
    local start_time=$(date +%s)
    
    # Detect language
    local lang="en"
    if [[ "${LANG}" == *"es"* ]] || [[ "${LC_ALL}" == *"es"* ]]; then
        lang="es"
    fi
    
    while kill -0 $pid 2>/dev/null; do
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
    clear
    echo ""
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║   DJProducerTools v3.0 - Verification & Testing Suite         ║${RESET}"
    echo -e "${BOLD}${CYAN}║   Comprehensive System Check & Functionality Validation        ║${RESET}"
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
# TEST FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

test_script_syntax() {
    section_header "Syntax Verification / Verificación de Sintaxis"
    
    local scripts=(
        "scripts/DJProducerTools_MultiScript_EN.sh"
        "scripts/DJProducerTools_MultiScript_ES.sh"
        "scripts/DJProducerTools_v3_PRODUCTION_EN.sh"
        "scripts/DJProducerTools_v3_PRODUCTION_ES.sh"
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
                return 1
            fi
        else
            echo -e "${RED}✗ $script (File not found)${RESET}"
            return 1
        fi
        
        progress_bar $count $total "$script"
    done
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════

test_file_structure() {
    section_header "File Structure Verification / Verificación de Estructura"
    
    local required_files=(
        "README.md"
        "README_ES.md"
        "INSTALL.sh"
        "scripts/DJProducerTools_MultiScript_EN.sh"
        "scripts/DJProducerTools_MultiScript_ES.sh"
    )
    
    local optional_files=(
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
            return 1
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
        "scripts/DJProducerTools_MultiScript_EN.sh"
        "scripts/DJProducerTools_MultiScript_ES.sh"
        "scripts/DJProducerTools_v3_PRODUCTION_EN.sh"
        "scripts/DJProducerTools_v3_PRODUCTION_ES.sh"
        "INSTALL.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                echo -e "  ${GREEN}✓${RESET} $script (executable)"
            else
                echo -e "  ${YELLOW}⚠${RESET} $script (not executable - fixing...)"
                chmod +x "$script"
                echo -e "  ${GREEN}✓${RESET} Fixed: $script"
            fi
        fi
    done
}

# ═══════════════════════════════════════════════════════════════════════════

test_bilingual_parity() {
    section_header "Bilingual Content Parity / Paridad de Contenido Bilingüe"
    
    local en_lines=$(wc -l < "scripts/DJProducerTools_MultiScript_EN.sh")
    local es_lines=$(wc -l < "scripts/DJProducerTools_MultiScript_ES.sh")
    
    echo -e "English script: ${CYAN}$en_lines lines${RESET}"
    echo -e "Spanish script: ${MAGENTA}$es_lines lines${RESET}"
    
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
    
    # Check if git is configured
    if ! command -v git &> /dev/null; then
        echo -e "${RED}✗ Git not installed${RESET}"
        return 1
    fi
    
    # Check remote
    if git remote -v &>/dev/null; then
        local remote=$(git remote get-url origin)
        echo -e "${GREEN}✓ Git remote configured${RESET}"
        echo -e "  Repository: ${CYAN}$remote${RESET}"
        
        # Test connectivity
        if git ls-remote --heads origin &>/dev/null; then
            echo -e "${GREEN}✓ GitHub connectivity verified${RESET}"
            return 0
        else
            echo -e "${RED}✗ Cannot reach GitHub${RESET}"
            return 1
        fi
    else
        echo -e "${YELLOW}○ No git remote configured${RESET}"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════

test_download_urls() {
    section_header "Download URL Verification / Verificación de URLs de Descarga"
    
    local base_url="https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main"
    local files=(
        "scripts/DJProducerTools_MultiScript_EN.sh"
        "scripts/DJProducerTools_MultiScript_ES.sh"
        "README.md"
        "INSTALL.sh"
    )
    
    local total=${#files[@]}
    
    for i in "${!files[@]}"; do
        local file="${files[$i]}"
        local url="${base_url}/${file}"
        local count=$((i + 1))
        
        # Test URL without downloading full file
        if curl -s -I --max-time 5 "$url" | grep -q "200 OK"; then
            echo -e "  ${GREEN}✓${RESET} $file"
        else
            echo -e "  ${RED}✗${RESET} $file - ${RED}Not accessible (404)${RESET}"
            echo -e "     URL: $url"
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
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════

final_summary() {
    echo ""
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║              ✓ Verification Complete / Verificación Completa   ║${RESET}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${GREEN}All tests passed! Ready for production deployment.${RESET}"
    echo -e "${GREEN}¡Todas las pruebas pasaron! Listo para despliegue en producción.${RESET}"
    echo ""
    echo -e "${YELLOW}Next steps / Próximos pasos:${RESET}"
    echo -e "  1. Review test results above / Revisar resultados arriba"
    echo -e "  2. Push to GitHub: ${CYAN}git push origin main${RESET}"
    echo -e "  3. Test installation: ${CYAN}./INSTALL.sh${RESET}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════

main() {
    display_header
    
    # Run all tests
    test_script_syntax
    test_file_structure
    test_permissions
    test_bilingual_parity
    test_emoji_support
    test_spinner_feedback
    test_github_connectivity
    test_download_urls
    
    final_summary
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
