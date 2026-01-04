#!/usr/bin/env bash
# DJProducerTools - Comprehensive Dependency Checker
# Validates all required and optional tools, Python packages, and versions

set -u

# Colors
C_RESET='\033[0m'
C_RED='\033[1;31m'
C_GRN='\033[1;32m'
C_YLW='\033[1;33m'
C_BLU='\033[1;34m'
C_CYN='\033[1;36m'

# ============================================================================
# DEPENDENCY MATRICES
# ============================================================================

# Format: "tool:description:install_command:min_version"
declare -a REQUIRED_TOOLS=(
    "bash:Bash shell:brew install bash:4.0"
    "shasum:SHA-256 hashing:brew install openssl:1.0"
    "rsync:File synchronization:brew install rsync:3.0"
    "find:File searching:built-in:1.0"
    "awk:Text processing:built-in:1.0"
    "sed:Stream editing:built-in:1.0"
    "grep:Pattern matching:built-in:1.0"
)

declare -a OPTIONAL_TOOLS=(
    "ffprobe:Media analysis:brew install ffmpeg:4.0"
    "ffmpeg:Video processing:brew install ffmpeg:4.0"
    "sox:Audio processing:brew install sox:14.0"
    "flac:FLAC codec:brew install flac:1.3"
    "metaflac:FLAC metadata:brew install flac:1.3"
    "id3v2:ID3 tags:brew install id3v2:0.8"
    "mid3v2:ID3v2 tags:pip install mutagen:1.40"
    "shntool:SHN processing:brew install shntool:3.0"
    "jq:JSON parsing:brew install jq:1.6"
    "bc:Calculator:brew install bc:1.0"
    "parallel:GNU Parallel:brew install parallel:20200000"
)

declare -a PYTHON_PACKAGES=(
    "numpy:Numerical computing:pip install numpy:1.19"
    "pandas:Data analysis:pip install pandas:1.0"
    "scikit-learn:ML algorithms:pip install scikit-learn:0.23"
    "joblib:Parallel computing:pip install joblib:0.14"
    "librosa:Audio analysis:pip install librosa:0.8"
    "mutagen:Metadata editing:pip install mutagen:1.40"
    "requests:HTTP library:pip install requests:2.25"
    "scipy:Scientific computing:pip install scipy:1.5"
)

declare -a TENSORFLOW_PACKAGES=(
    "tensorflow:Deep learning (Intel):pip install tensorflow:2.5"
    "tensorflow-macos:Deep learning (Apple Silicon):pip install tensorflow-macos:2.5"
    "tensorflow-metal:GPU acceleration:pip install tensorflow-metal:0.2"
)

# ============================================================================
# TOOL CHECKING FUNCTIONS
# ============================================================================

check_tool_exists() {
    local tool="$1"
    command -v "$tool" >/dev/null 2>&1
}

get_tool_version() {
    local tool="$1"
    
    case "$tool" in
        bash)
            bash --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1
            ;;
        shasum)
            shasum --version 2>/dev/null | head -1 || echo "unknown"
            ;;
        rsync)
            rsync --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
            ;;
        ffprobe|ffmpeg)
            ffprobe -version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1
            ;;
        sox)
            sox --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
            ;;
        flac|metaflac)
            flac --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
            ;;
        jq)
            jq --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1
            ;;
        bc)
            bc --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

test_tool_functionality() {
    local tool="$1"
    
    case "$tool" in
        shasum)
            echo "test" | shasum -a 256 >/dev/null 2>&1
            ;;
        rsync)
            rsync --version >/dev/null 2>&1
            ;;
        ffprobe)
            ffprobe -version >/dev/null 2>&1
            ;;
        sox)
            sox --version >/dev/null 2>&1
            ;;
        jq)
            echo '{"test":1}' | jq . >/dev/null 2>&1
            ;;
        bc)
            echo "1+1" | bc >/dev/null 2>&1
            ;;
        *)
            return 0
            ;;
    esac
}

# ============================================================================
# PYTHON CHECKING FUNCTIONS
# ============================================================================

check_python_version() {
    if ! command -v python3 >/dev/null 2>&1; then
        return 1
    fi
    
    python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null
}

get_python_version() {
    python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

check_python_package() {
    local package="$1"
    python3 -m pip show "$package" >/dev/null 2>&1
}

get_python_package_version() {
    local package="$1"
    python3 -m pip show "$package" 2>/dev/null | grep "^Version:" | cut -d' ' -f2
}

test_python_package_import() {
    local package="$1"
    local import_name="${2:-$package}"
    
    python3 -c "import $import_name" >/dev/null 2>&1
}

# ============================================================================
# REPORTING FUNCTIONS
# ============================================================================

print_tool_status() {
    local tool="$1"
    local exists="$2"
    local version="$3"
    local functional="$4"
    
    if [ "$exists" -eq 1 ]; then
        if [ "$functional" -eq 1 ]; then
            printf "  ${C_GRN}✓${C_RESET} %-20s %s\n" "$tool" "$version"
        else
            printf "  ${C_YLW}⚠${C_RESET} %-20s %s (not functional)\n" "$tool" "$version"
        fi
    else
        printf "  ${C_RED}✗${C_RESET} %-20s (not installed)\n" "$tool"
    fi
}

print_python_package_status() {
    local package="$1"
    local exists="$2"
    local version="$3"
    local importable="$4"
    
    if [ "$exists" -eq 1 ]; then
        if [ "$importable" -eq 1 ]; then
            printf "  ${C_GRN}✓${C_RESET} %-20s %s\n" "$package" "$version"
        else
            printf "  ${C_YLW}⚠${C_RESET} %-20s %s (not importable)\n" "$package" "$version"
        fi
    else
        printf "  ${C_RED}✗${C_RESET} %-20s (not installed)\n" "$package"
    fi
}

# ============================================================================
# COMPREHENSIVE CHECKS
# ============================================================================

check_all_required_tools() {
    printf "\n${C_BLU}═══ Required Tools ===${C_RESET}\n"
    
    local missing_count=0
    local broken_count=0
    
    for tool_spec in "${REQUIRED_TOOLS[@]}"; do
        IFS=':' read -r tool desc install min_ver <<< "$tool_spec"
        
        if check_tool_exists "$tool"; then
            local version=$(get_tool_version "$tool")
            local functional=1
            
            if ! test_tool_functionality "$tool"; then
                functional=0
                broken_count=$((broken_count + 1))
            fi
            
            print_tool_status "$tool" 1 "$version" "$functional"
        else
            missing_count=$((missing_count + 1))
            printf "  ${C_RED}✗${C_RESET} %-20s (not installed)\n" "$tool"
            printf "      Install: ${C_CYN}%s${C_RESET}\n" "$install"
        fi
    done
    
    return $missing_count
}

check_all_optional_tools() {
    printf "\n${C_BLU}═══ Optional Tools ===${C_RESET}\n"
    
    local missing_count=0
    
    for tool_spec in "${OPTIONAL_TOOLS[@]}"; do
        IFS=':' read -r tool desc install min_ver <<< "$tool_spec"
        
        if check_tool_exists "$tool"; then
            local version=$(get_tool_version "$tool")
            local functional=1
            
            if ! test_tool_functionality "$tool"; then
                functional=0
            fi
            
            print_tool_status "$tool" 1 "$version" "$functional"
        else
            missing_count=$((missing_count + 1))
            printf "  ${C_YLW}⊘${C_RESET} %-20s (optional, not installed)\n" "$tool"
        fi
    done
    
    return 0
}

check_python_environment() {
    printf "\n${C_BLU}═══ Python Environment ===${C_RESET}\n"
    
    if ! command -v python3 >/dev/null 2>&1; then
        printf "  ${C_RED}✗${C_RESET} Python 3 not found\n"
        return 1
    fi
    
    local py_version=$(get_python_version)
    printf "  ${C_GRN}✓${C_RESET} Python 3 version: %s\n" "$py_version"
    
    if ! check_python_version; then
        printf "  ${C_RED}✗${C_RESET} Python 3.8+ required\n"
        return 1
    fi
    
    if ! command -v pip3 >/dev/null 2>&1 && ! python3 -m pip --version >/dev/null 2>&1; then
        printf "  ${C_RED}✗${C_RESET} pip not available\n"
        return 1
    fi
    
    printf "  ${C_GRN}✓${C_RESET} pip available\n"
    
    return 0
}

check_python_packages() {
    printf "\n${C_BLU}═══ Python Packages (ML/Analysis) ===${C_RESET}\n"
    
    local missing_count=0
    
    for pkg_spec in "${PYTHON_PACKAGES[@]}"; do
        IFS=':' read -r package desc install min_ver <<< "$pkg_spec"
        
        if check_python_package "$package"; then
            local version=$(get_python_package_version "$package")
            local importable=1
            
            if ! test_python_package_import "$package"; then
                importable=0
            fi
            
            print_python_package_status "$package" 1 "$version" "$importable"
        else
            missing_count=$((missing_count + 1))
            printf "  ${C_YLW}⊘${C_RESET} %-20s (optional, not installed)\n" "$package"
            printf "      Install: ${C_CYN}%s${C_RESET}\n" "$install"
        fi
    done
    
    return 0
}

check_tensorflow_support() {
    printf "\n${C_BLU}═══ TensorFlow Support ===${C_RESET}\n"
    
    local arch=$(uname -m)
    local os=$(uname -s)
    
    printf "  Architecture: %s\n" "$arch"
    printf "  OS: %s\n" "$os"
    
    if [ "$os" = "Darwin" ]; then
        if [ "$arch" = "arm64" ]; then
            printf "  ${C_GRN}✓${C_RESET} Apple Silicon detected (M1/M2/M3)\n"
            printf "      Recommended: tensorflow-macos + tensorflow-metal\n"
            
            if check_python_package "tensorflow-macos"; then
                printf "  ${C_GRN}✓${C_RESET} tensorflow-macos installed\n"
            else
                printf "  ${C_YLW}⊘${C_RESET} tensorflow-macos not installed\n"
            fi
            
            if check_python_package "tensorflow-metal"; then
                printf "  ${C_GRN}✓${C_RESET} tensorflow-metal installed\n"
            else
                printf "  ${C_YLW}⊘${C_RESET} tensorflow-metal not installed (GPU acceleration)\n"
            fi
        else
            printf "  ${C_GRN}✓${C_RESET} Intel Mac detected\n"
            printf "      Recommended: tensorflow\n"
            
            if check_python_package "tensorflow"; then
                printf "  ${C_GRN}✓${C_RESET} tensorflow installed\n"
            else
                printf "  ${C_YLW}⊘${C_RESET} tensorflow not installed\n"
            fi
        fi
    fi
}

# ============================================================================
# DEPENDENCY REPORT GENERATION
# ============================================================================

generate_dependency_report() {
    local report_file="${1:-dependency_report.txt}"
    
    {
        echo "DJProducerTools - Dependency Report"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "System: $(uname -s) $(uname -m)"
        echo ""
        
        echo "=== Required Tools ==="
        for tool_spec in "${REQUIRED_TOOLS[@]}"; do
            IFS=':' read -r tool desc install min_ver <<< "$tool_spec"
            if check_tool_exists "$tool"; then
                echo "✓ $tool: $(get_tool_version "$tool")"
            else
                echo "✗ $tool: NOT INSTALLED"
            fi
        done
        
        echo ""
        echo "=== Optional Tools ==="
        for tool_spec in "${OPTIONAL_TOOLS[@]}"; do
            IFS=':' read -r tool desc install min_ver <<< "$tool_spec"
            if check_tool_exists "$tool"; then
                echo "✓ $tool: $(get_tool_version "$tool")"
            else
                echo "⊘ $tool: NOT INSTALLED (optional)"
            fi
        done
        
        echo ""
        echo "=== Python Environment ==="
        if command -v python3 >/dev/null 2>&1; then
            echo "✓ Python 3: $(get_python_version)"
        else
            echo "✗ Python 3: NOT INSTALLED"
        fi
        
        echo ""
        echo "=== Python Packages ==="
        for pkg_spec in "${PYTHON_PACKAGES[@]}"; do
            IFS=':' read -r package desc install min_ver <<< "$pkg_spec"
            if check_python_package "$package"; then
                echo "✓ $package: $(get_python_package_version "$package")"
            else
                echo "⊘ $package: NOT INSTALLED (optional)"
            fi
        done
        
    } > "$report_file"
    
    printf "Report saved to: %s\n" "$report_file"
}

# ============================================================================
# AUTO-INSTALL FUNCTIONS
# ============================================================================

auto_install_missing_tools() {
    printf "\n${C_BLU}═══ Auto-Installing Missing Tools ===${C_RESET}\n"
    
    if ! command -v brew >/dev/null 2>&1; then
        printf "${C_RED}✗ Homebrew not found. Install from: https://brew.sh${C_RESET}\n"
        return 1
    fi
    
    local to_install=()
    
    for tool_spec in "${REQUIRED_TOOLS[@]}"; do
        IFS=':' read -r tool desc install min_ver <<< "$tool_spec"
        
        if ! check_tool_exists "$tool" && [ "$install" != "built-in" ]; then
            to_install+=("$tool")
        fi
    done
    
    if [ ${#to_install[@]} -eq 0 ]; then
        printf "${C_GRN}✓ All required tools already installed${C_RESET}\n"
        return 0
    fi
    
    printf "Installing: %s\n" "${to_install[*]}"
    
    for tool in "${to_install[@]}"; do
        printf "Installing %s...\n" "$tool"
        brew install "$tool" || printf "${C_YLW}⚠ Failed to install %s${C_RESET}\n" "$tool"
    done
}

auto_install_python_packages() {
    printf "\n${C_BLU}═══ Auto-Installing Python Packages ===${C_RESET}\n"
    
    if ! command -v python3 >/dev/null 2>&1; then
        printf "${C_RED}✗ Python 3 not found${C_RESET}\n"
        return 1
    fi
    
    local to_install=()
    
    for pkg_spec in "${PYTHON_PACKAGES[@]}"; do
        IFS=':' read -r package desc install min_ver <<< "$pkg_spec"
        
        if ! check_python_package "$package"; then
            to_install+=("$package")
        fi
    done
    
    if [ ${#to_install[@]} -eq 0 ]; then
        printf "${C_GRN}✓ All Python packages already installed${C_RESET}\n"
        return 0
    fi
    
    printf "Installing: %s\n" "${to_install[*]}"
    
    python3 -m pip install --user "${to_install[@]}" || printf "${C_YLW}⚠ Some packages failed to install${C_RESET}\n"
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================

main() {
    printf "\n${C_BLU}╔════════════════════════════════════════════════════╗${C_RESET}\n"
    printf "${C_BLU}║  DJProducerTools - Comprehensive Dependency Check  ║${C_RESET}\n"
    printf "${C_BLU}╚════════════════════════════════════════════════════╝${C_RESET}\n"
    
    check_all_required_tools
    check_all_optional_tools
    check_python_environment
    check_python_packages
    check_tensorflow_support
    
    printf "\n${C_BLU}═══ Summary ===${C_RESET}\n"
    printf "Run 'bash lib/dependency_checker.sh --auto-install' to install missing tools\n"
    printf "Run 'bash lib/dependency_checker.sh --report' to generate detailed report\n"
}

# Handle command-line arguments
case "${1:-}" in
    --auto-install)
        auto_install_missing_tools
        auto_install_python_packages
        ;;
    --report)
        generate_dependency_report "${2:-dependency_report.txt}"
        ;;
    *)
        main
        ;;
esac
