#!/usr/bin/env bash
# DJProducerTools - Complete Doctor/Diagnostics System
# Comprehensive health checks with auto-remediation and detailed reporting

set -u

# Colors
C_RESET='\033[0m'
C_RED='\033[1;31m'
C_GRN='\033[1;32m'
C_YLW='\033[1;33m'
C_BLU='\033[1;34m'
C_CYN='\033[1;36m'
C_PURP='\033[38;5;129m'

# Report file
REPORT_FILE="doctor_report_$(date +%Y%m%d_%H%M%S).html"
ISSUES_FOUND=0
ISSUES_FIXED=0

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_check() {
    printf "${C_BLU}▶${C_RESET} %s" "$1"
}

print_pass() {
    printf " ${C_GRN}✓${C_RESET} %s\n" "$1"
}

print_fail() {
    printf " ${C_RED}✗${C_RESET} %s\n" "$1"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
}

print_warn() {
    printf " ${C_YLW}⚠${C_RESET} %s\n" "$1"
}

print_info() {
    printf " ${C_CYN}ℹ${C_RESET} %s\n" "$1"
}

# ============================================================================
# ENVIRONMENT CHECKS
# ============================================================================

check_os_version() {
    print_check "OS Version"
    
    local os=$(uname -s)
    local version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    
    if [ "$os" = "Darwin" ]; then
        print_pass "$os $version"
        return 0
    else
        print_fail "Not macOS ($os)"
        return 1
    fi
}

check_bash_version() {
    print_check "Bash Version"
    
    local bash_version="${BASH_VERSION:-unknown}"
    
    if [[ "$bash_version" =~ ^[0-9] ]]; then
        local major=$(echo "$bash_version" | cut -d. -f1)
        if [ "$major" -ge 4 ]; then
            print_pass "Bash $bash_version"
            return 0
        else
            print_warn "Bash $bash_version (4.0+ recommended)"
            return 1
        fi
    else
        print_fail "Could not determine Bash version"
        return 1
    fi
}

check_shell_compatibility() {
    print_check "Shell Compatibility"
    
    local shell=$(echo $SHELL)
    
    if [[ "$shell" == *"bash"* ]] || [[ "$shell" == *"zsh"* ]]; then
        print_pass "$shell"
        return 0
    else
        print_warn "Unusual shell: $shell"
        return 1
    fi
}

check_path_configuration() {
    print_check "PATH Configuration"
    
    local path_count=$(echo "$PATH" | tr ':' '\n' | wc -l)
    
    if [ "$path_count" -gt 0 ]; then
        print_pass "$path_count directories in PATH"
        return 0
    else
        print_fail "PATH is empty"
        return 1
    fi
}

# ============================================================================
# TOOL CHECKS
# ============================================================================

check_required_tools() {
    print_check "Required Tools"
    
    local required=("bash" "shasum" "rsync" "find" "awk" "sed" "grep")
    local missing=0
    
    for tool in "${required[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing=$((missing + 1))
        fi
    done
    
    if [ "$missing" -eq 0 ]; then
        print_pass "All required tools present"
        return 0
    else
        print_fail "$missing required tools missing"
        return 1
    fi
}

check_optional_tools() {
    print_check "Optional Tools"
    
    local optional=("ffprobe" "sox" "flac" "jq" "bc")
    local available=0
    
    for tool in "${optional[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            available=$((available + 1))
        fi
    done
    
    print_info "$available/${#optional[@]} optional tools available"
    return 0
}

check_tool_versions() {
    print_check "Tool Versions"
    
    local tools_ok=0
    local tools_total=0
    
    for tool in shasum rsync ffprobe sox; do
        if command -v "$tool" >/dev/null 2>&1; then
            tools_total=$((tools_total + 1))
            local version=$("$tool" --version 2>/dev/null | head -1 || echo "unknown")
            if [ -n "$version" ] && [ "$version" != "unknown" ]; then
                tools_ok=$((tools_ok + 1))
            fi
        fi
    done
    
    if [ "$tools_ok" -eq "$tools_total" ]; then
        print_pass "All tool versions readable"
        return 0
    else
        print_warn "$tools_ok/$tools_total tool versions readable"
        return 1
    fi
}

# ============================================================================
# PYTHON CHECKS
# ============================================================================

check_python_version() {
    print_check "Python Version"
    
    if ! command -v python3 >/dev/null 2>&1; then
        print_fail "Python 3 not found"
        return 1
    fi
    
    local py_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    local py_major=$(echo "$py_version" | cut -d. -f1)
    local py_minor=$(echo "$py_version" | cut -d. -f2)
    
    if [ "$py_major" -ge 3 ] && [ "$py_minor" -ge 8 ]; then
        print_pass "Python $py_version"
        return 0
    else
        print_fail "Python $py_version (3.8+ required)"
        return 1
    fi
}

check_python_venv() {
    print_check "Python venv Module"
    
    if python3 -m venv --help >/dev/null 2>&1; then
        print_pass "venv module available"
        return 0
    else
        print_fail "venv module not available"
        return 1
    fi
}

check_python_packages() {
    print_check "Python Packages"
    
    local packages=("numpy" "pandas" "scikit-learn" "librosa" "mutagen")
    local available=0
    
    for pkg in "${packages[@]}"; do
        if python3 -m pip show "$pkg" >/dev/null 2>&1; then
            available=$((available + 1))
        fi
    done
    
    print_info "$available/${#packages[@]} ML packages installed"
    return 0
}

check_pip_functionality() {
    print_check "pip Functionality"
    
    if python3 -m pip --version >/dev/null 2>&1; then
        local pip_version=$(python3 -m pip --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        print_pass "pip $pip_version"
        return 0
    else
        print_fail "pip not functional"
        return 1
    fi
}

# ============================================================================
# STATE CHECKS
# ============================================================================

check_state_directory() {
    print_check "State Directory (_DJProducerTools)"
    
    if [ -d "_DJProducerTools" ]; then
        local size=$(du -sh "_DJProducerTools" 2>/dev/null | cut -f1)
        print_pass "Exists ($size)"
        return 0
    else
        print_warn "Not found (will be created on first run)"
        return 1
    fi
}

check_config_files() {
    print_check "Configuration Files"
    
    if [ -f "_DJProducerTools/config/djpt.conf" ]; then
        print_pass "Config file present"
        return 0
    else
        print_warn "Config file not found (will be created)"
        return 1
    fi
}

check_artifact_integrity() {
    print_check "Artifact Integrity"
    
    local artifacts=0
    local total=0
    
    for artifact in "_DJProducerTools/reports/hash_index.tsv" \
                    "_DJProducerTools/reports/snapshot_hash_fast.tsv" \
                    "_DJProducerTools/plans/dupes_plan.tsv"; do
        total=$((total + 1))
        if [ -f "$artifact" ]; then
            artifacts=$((artifacts + 1))
        fi
    done
    
    print_info "$artifacts/$total key artifacts present"
    return 0
}

check_quarantine_status() {
    print_check "Quarantine System"
    
    if [ -d "_DJProducerTools/quarantine" ]; then
        local quar_count=$(find "_DJProducerTools/quarantine" -type f 2>/dev/null | wc -l)
        local quar_size=$(du -sh "_DJProducerTools/quarantine" 2>/dev/null | cut -f1)
        print_info "$quar_count files in quarantine ($quar_size)"
        return 0
    else
        print_warn "Quarantine directory not found"
        return 1
    fi
}

# ============================================================================
# DISK CHECKS
# ============================================================================

check_disk_space() {
    print_check "Disk Space"
    
    local available=$(df -h . 2>/dev/null | awk 'NR==2 {print $4}')
    local usage=$(df -h . 2>/dev/null | awk 'NR==2 {print $5}')
    
    if [ -n "$available" ]; then
        print_pass "$available available ($usage used)"
        return 0
    else
        print_fail "Could not determine disk space"
        return 1
    fi
}

check_disk_usage_trends() {
    print_check "Disk Usage Trends"
    
    if [ -d "_DJProducerTools" ]; then
        local state_size=$(du -sh "_DJProducerTools" 2>/dev/null | cut -f1)
        print_info "State directory: $state_size"
        return 0
    else
        print_info "No state directory yet"
        return 0
    fi
}

check_inode_usage() {
    print_check "Inode Usage"
    
    local inode_usage=$(df -i . 2>/dev/null | awk 'NR==2 {print $5}')
    
    if [ -n "$inode_usage" ]; then
        print_info "Inode usage: $inode_usage"
        return 0
    else
        print_warn "Could not determine inode usage"
        return 1
    fi
}

# ============================================================================
# PERMISSION CHECKS
# ============================================================================

check_file_permissions() {
    print_check "File Permissions"
    
    local scripts_ok=0
    
    for script in scripts/DJProducerTools_MultiScript_*.sh; do
        if [ -x "$script" ]; then
            scripts_ok=$((scripts_ok + 1))
        fi
    done
    
    if [ "$scripts_ok" -eq 2 ]; then
        print_pass "All scripts executable"
        return 0
    else
        print_warn "$scripts_ok/2 scripts executable"
        return 1
    fi
}

check_directory_permissions() {
    print_check "Directory Permissions"
    
    if [ -w "_DJProducerTools" ] 2>/dev/null || [ ! -d "_DJProducerTools" ]; then
        print_pass "State directory writable"
        return 0
    else
        print_fail "State directory not writable"
        return 1
    fi
}

check_write_access() {
    print_check "Write Access"
    
    local test_file="/tmp/djpt_write_test_$$"
    
    if touch "$test_file" 2>/dev/null; then
        rm -f "$test_file"
        print_pass "Write access OK"
        return 0
    else
        print_fail "No write access to /tmp"
        return 1
    fi
}

# ============================================================================
# PERFORMANCE CHECKS
# ============================================================================

benchmark_hash_speed() {
    print_check "Hash Performance"
    
    # Create a 10MB test file
    local test_file="/tmp/djpt_hash_test_$$"
    dd if=/dev/zero of="$test_file" bs=1M count=10 2>/dev/null
    
    local start=$(date +%s%N)
    shasum -a 256 "$test_file" >/dev/null 2>&1
    local end=$(date +%s%N)
    
    local duration=$(( (end - start) / 1000000 ))  # Convert to ms
    
    rm -f "$test_file"
    
    if [ "$duration" -lt 5000 ]; then
        print_pass "Hash speed: ${duration}ms (excellent)"
    elif [ "$duration" -lt 10000 ]; then
        print_pass "Hash speed: ${duration}ms (good)"
    else
        print_warn "Hash speed: ${duration}ms (slow)"
    fi
    
    return 0
}

benchmark_scan_speed() {
    print_check "Scan Performance"
    
    local test_dir="/tmp/djpt_scan_test_$$"
    mkdir -p "$test_dir"
    
    # Create 100 test files
    for i in {1..100}; do
        touch "$test_dir/file_$i.txt"
    done
    
    local start=$(date +%s%N)
    find "$test_dir" -type f >/dev/null 2>&1
    local end=$(date +%s%N)
    
    local duration=$(( (end - start) / 1000000 ))  # Convert to ms
    
    rm -rf "$test_dir"
    
    print_info "Scan speed: ${duration}ms for 100 files"
    return 0
}

benchmark_memory_usage() {
    print_check "Memory Usage"
    
    local mem_available=$(vm_stat 2>/dev/null | grep "Pages free" | awk '{print $3}' | tr -d '.')
    
    if [ -n "$mem_available" ]; then
        local mem_mb=$((mem_available / 256))  # Rough conversion
        print_info "Available memory: ~${mem_mb}MB"
        return 0
    else
        print_warn "Could not determine memory"
        return 1
    fi
}

# ============================================================================
# SECURITY CHECKS
# ============================================================================

check_safe_mode() {
    print_check "Safe Mode"
    
    if grep -q "SAFE_MODE=1" scripts/DJProducerTools_MultiScript_EN.sh; then
        print_pass "Safe mode enabled by default"
        return 0
    else
        print_warn "Safe mode may be disabled"
        return 1
    fi
}

check_locks() {
    print_check "Safety Locks"
    
    if grep -q "DJ_SAFE_LOCK" scripts/DJProducerTools_MultiScript_EN.sh; then
        print_pass "DJ_SAFE_LOCK implemented"
        return 0
    else
        print_fail "DJ_SAFE_LOCK not found"
        return 1
    fi
}

check_dryrun_mode() {
    print_check "Dry-Run Mode"
    
    if grep -q "DRYRUN_FORCE" scripts/DJProducerTools_MultiScript_EN.sh; then
        print_pass "Dry-run mode available"
        return 0
    else
        print_fail "Dry-run mode not found"
        return 1
    fi
}

check_quarantine_protection() {
    print_check "Quarantine Protection"
    
    if grep -q "QUAR_DIR" scripts/DJProducerTools_MultiScript_EN.sh; then
        print_pass "Quarantine system implemented"
        return 0
    else
        print_fail "Quarantine system not found"
        return 1
    fi
}

# ============================================================================
# BILINGUAL CHECKS
# ============================================================================

check_en_script() {
    print_check "English Script"
    
    if [ -f "scripts/DJProducerTools_MultiScript_EN.sh" ]; then
        local size=$(stat -f%z "scripts/DJProducerTools_MultiScript_EN.sh" 2>/dev/null || echo 0)
        if [ "$size" -gt 100000 ]; then
            print_pass "Present and substantial ($size bytes)"
            return 0
        else
            print_fail "File too small ($size bytes)"
            return 1
        fi
    else
        print_fail "Not found"
        return 1
    fi
}

check_es_script() {
    print_check "Spanish Script"
    
    if [ -f "scripts/DJProducerTools_MultiScript_ES.sh" ]; then
        local size=$(stat -f%z "scripts/DJProducerTools_MultiScript_ES.sh" 2>/dev/null || echo 0)
        if [ "$size" -gt 100000 ]; then
            print_pass "Present and substantial ($size bytes)"
            return 0
        else
            print_fail "File too small ($size bytes)"
            return 1
        fi
    else
        print_fail "Not found"
        return 1
    fi
}

check_translation_parity() {
    print_check "Translation Parity"
    
    local en_actions=$(grep -c "^action_" scripts/DJProducerTools_MultiScript_EN.sh 2>/dev/null || echo 0)
    local es_actions=$(grep -c "^action_" scripts/DJProducerTools_MultiScript_ES.sh 2>/dev/null || echo 0)
    
    if [ "$en_actions" -eq "$es_actions" ]; then
        print_pass "Both scripts have $en_actions actions"
        return 0
    else
        print_warn "Action count mismatch: EN=$en_actions, ES=$es_actions"
        return 1
    fi
}

# ============================================================================
# AUTO-REMEDIATION
# ============================================================================

remediate_missing_tools() {
    printf "\n${C_BLU}═══ Auto-Remediation: Missing Tools ===${C_RESET}\n"
    
    if ! command -v brew >/dev/null 2>&1; then
        printf "${C_YLW}⚠ Homebrew not found. Install from: https://brew.sh${C_RESET}\n"
        return 1
    fi
    
    local tools_to_install=("ffmpeg" "sox" "flac" "jq" "bc")
    
    for tool in "${tools_to_install[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            printf "Installing %s...\n" "$tool"
            if brew install "$tool" >/dev/null 2>&1; then
                printf "${C_GRN}✓${C_RESET} Installed %s\n" "$tool"
                ISSUES_FIXED=$((ISSUES_FIXED + 1))
            else
                printf "${C_RED}✗${C_RESET} Failed to install %s\n" "$tool"
            fi
        fi
    done
}

remediate_permissions() {
    printf "\n${C_BLU}═══ Auto-Remediation: Permissions ===${C_RESET}\n"
    
    for script in scripts/DJProducerTools_MultiScript_*.sh; do
        if [ ! -x "$script" ]; then
            printf "Making %s executable...\n" "$script"
            chmod +x "$script"
            printf "${C_GRN}✓${C_RESET} Fixed permissions\n"
            ISSUES_FIXED=$((ISSUES_FIXED + 1))
        fi
    done
}

remediate_state_corruption() {
    printf "\n${C_BLU}═══ Auto-Remediation: State Corruption ===${C_RESET}\n"
    
    if [ ! -d "_DJProducerTools" ]; then
        printf "Creating state directory...\n"
        mkdir -p "_DJProducerTools/config" "_DJProducerTools/reports" "_DJProducerTools/plans" "_DJProducerTools/logs" "_DJProducerTools/quarantine"
        printf "${C_GRN}✓${C_RESET} State directory created\n"
        ISSUES_FIXED=$((ISSUES_FIXED + 1))
    fi
}

# ============================================================================
# REPORT GENERATION
# ============================================================================

generate_html_report() {
    {
        cat <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>DJProducerTools - Doctor Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .section { background: white; margin: 20px 0; padding: 15px; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        .pass { color: #27ae60; font-weight: bold; }
        .fail { color: #e74c3c; font-weight: bold; }
        .warn { color: #f39c12; font-weight: bold; }
        .info { color: #3498db; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #34495e; color: white; }
    </style>
</head>
<body>
    <div class="header">
        <h1>DJProducerTools - Doctor Report</h1>
        <p>Generated: $(date '+%Y-%m-%d %H:%M:%S')</p>
    </div>
    
    <div class="section">
        <h2>System Information</h2>
        <table>
            <tr><td>OS:</td><td>$(uname -s) $(uname -m)</td></tr>
            <tr><td>Bash:</td><td>${BASH_VERSION}</td></tr>
            <tr><td>Python:</td><td>$(python3 --version 2>&1)</td></tr>
        </table>
    </div>
    
    <div class="section">
        <h2>Summary</h2>
        <p>Issues Found: <span class="fail">$ISSUES_FOUND</span></p>
        <p>Issues Fixed: <span class="pass">$ISSUES_FIXED</span></p>
    </div>
    
    <div class="section">
        <h2>Recommendations</h2>
        <ul>
            <li>Run comprehensive test suite: <code>bash tests/stage_by_stage_test.sh</code></li>
            <li>Check dependencies: <code>bash lib/dependency_checker.sh</code></li>
            <li>Review logs: <code>ls -la _DJProducerTools/logs/</code></li>
        </ul>
    </div>
</body>
</html>
EOF
    } > "$REPORT_FILE"
    
    printf "\n${C_GRN}✓${C_RESET} Report saved to: %s\n" "$REPORT_FILE"
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================

main() {
    printf "\n${C_BLU}╔════════════════════════════════════════════════════╗${C_RESET}\n"
    printf "${C_BLU}║     DJProducerTools - Complete Doctor Report      ║${C_RESET}\n"
    printf "${C_BLU}╚════════════════════════════════════════════════════╝${C_RESET}\n"
    
    printf "\n${C_CYN}=== Environment ===${C_RESET}\n"
    check_os_version
    check_bash_version
    check_shell_compatibility
    check_path_configuration
    
    printf "\n${C_CYN}=== Tools ===${C_RESET}\n"
    check_required_tools
    check_optional_tools
    check_tool_versions
    
    printf "\n${C_CYN}=== Python ===${C_RESET}\n"
    check_python_version
    check_python_venv
    check_python_packages
    check_pip_functionality
    
    printf "\n${C_CYN}=== State ===${C_RESET}\n"
    check_state_directory
    check_config_files
    check_artifact_integrity
    check_quarantine_status
    
    printf "\n${C_CYN}=== Disk ===${C_RESET}\n"
    check_disk_space
    check_disk_usage_trends
    check_inode_usage
    
    printf "\n${C_CYN}=== Permissions ===${C_RESET}\n"
    check_file_permissions
    check_directory_permissions
    check_write_access
    
    printf "\n${C_CYN}=== Performance ===${C_RESET}\n"
    benchmark_hash_speed
    benchmark_scan_speed
    benchmark_memory_usage
    
    printf "\n${C_CYN}=== Security ===${C_RESET}\n"
    check_safe_mode
    check_locks
    check_dryrun_mode
    check_quarantine_protection
    
    printf "\n${C_CYN}=== Bilingual ===${C_RESET}\n"
    check_en_script
    check_es_script
    check_translation_parity
    
    # Auto-remediation
    if [ "$ISSUES_FOUND" -gt 0 ]; then
        printf "\n${C_YLW}Found %d issues. Attempting auto-remediation...${C_RESET}\n" "$ISSUES_FOUND"
        remediate_missing_tools
        remediate_permissions
        remediate_state_corruption
    fi
    
    # Generate report
    generate_html_report
    
    printf "\n${C_BLU}═══ Summary ===${C_RESET}\n"
    printf "Issues Found: ${C_RED}%d${C_RESET}\n" "$ISSUES_FOUND"
    printf "Issues Fixed: ${C_GRN}%d${C_RESET}\n" "$ISSUES_FIXED"
}

main "$@"
