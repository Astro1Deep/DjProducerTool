#!/usr/bin/env bash
###############################################################################
# DJProducerTools - Repository Cleanup & Organization Script
# Purpose: Clean unnecessary files and organize for production deployment
# Author: Astro1Deep
# Version: 1.0.0
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Spinner characters
SPINNER=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
SPINNER_INDEX=0

# Counters
FILES_REMOVED=0
DIRS_REMOVED=0
FILES_KEPT=0
TOTAL_SIZE_FREED=0

###############################################################################
# Functions
###############################################################################

show_spinner() {
    printf "\r${CYAN}${SPINNER[$SPINNER_INDEX]}${NC} $1"
    SPINNER_INDEX=$(( (SPINNER_INDEX + 1) % 10 ))
}

print_header() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $1"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

calculate_size() {
    if [ -f "$1" ]; then
        stat -f%z "$1" 2>/dev/null || echo 0
    fi
}

###############################################################################
# Main Script
###############################################################################

print_header "🧹 DJProducerTools Repository Cleanup v1.0.0"

echo "This script will:"
echo "  • Remove build automation scripts (build_macos_pkg.sh, build_release_pack.sh)"
echo "  • Remove Python correction utilities (aplicar_correcciones_premium.py)"
echo "  • Remove HTML generation tools (generate_html_report.sh)"
echo "  • Remove generated folders (_DJProducerTools/)"
echo "  • Consolidate duplicate documentation"
echo "  • Verify core files are preserved"
echo ""

read -p "Continue with cleanup? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Cleanup cancelled"
    exit 0
fi

print_header "Phase 1: Identifying Files to Remove"

# Define files to remove
FILES_TO_REMOVE=(
    "build_macos_pkg.sh"
    "build_release_pack.sh"
    "aplicar_correcciones_premium.py"
    "generate_html_report.sh"
)

# Define directories to remove
DIRS_TO_REMOVE=(
    "_DJProducerTools"
    ".pytest_cache"
    "__pycache__"
)

# Define files to keep
MUST_KEEP_FILES=(
    "DJProducerTools_MultiScript_EN.sh"
    "DJProducerTools_MultiScript_ES.sh"
    "install_djpt.sh"
    "README.md"
    "README_ES.md"
    "LICENSE"
    "VERSION"
)

echo "Files to remove:"
for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -f "$file" ]; then
        size=$(calculate_size "$file")
        echo "  • $file ($(( size / 1024 )) KB)"
    fi
done

echo ""
echo "Directories to remove:"
for dir in "${DIRS_TO_REMOVE[@]}"; do
    if [ -d "$dir" ]; then
        size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        echo "  • $dir/ ($size)"
    fi
done

echo ""

print_header "Phase 2: Removing Unnecessary Files"

# Remove files
for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -f "$file" ]; then
        size=$(calculate_size "$file")
        rm -f "$file"
        FILES_REMOVED=$((FILES_REMOVED + 1))
        TOTAL_SIZE_FREED=$((TOTAL_SIZE_FREED + size))
        print_success "Removed: $file"
    fi
done

# Remove directories
for dir in "${DIRS_TO_REMOVE[@]}"; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        DIRS_REMOVED=$((DIRS_REMOVED + 1))
        print_success "Removed directory: $dir/"
    fi
done

echo ""

print_header "Phase 3: Verifying Core Files"

# Check that essential files still exist
echo "Verifying essential files..."
for file in "${MUST_KEEP_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "Found: $file"
        FILES_KEPT=$((FILES_KEPT + 1))
    else
        print_error "MISSING: $file (CRITICAL!)"
    fi
done

echo ""

print_header "Phase 4: Repository Statistics"

echo "Files removed: $FILES_REMOVED"
echo "Directories removed: $DIRS_REMOVED"
echo "Core files verified: $FILES_KEPT"
echo "Space freed: $(( TOTAL_SIZE_FREED / 1024 / 1024 )) MB"
echo ""

# Get final repository size
REPO_SIZE=$(du -sh . | cut -f1)
FILE_COUNT=$(find . -type f | wc -l | awk '{print $1}')

echo "Final repository size: $REPO_SIZE"
echo "Total files: $FILE_COUNT"

echo ""

print_header "Phase 5: Directory Structure"

echo "Core structure:"
echo "├── DJProducerTools_MultiScript_EN.sh"
echo "├── DJProducerTools_MultiScript_ES.sh"
echo "├── install_djpt.sh"
echo "├── README.md"
echo "├── README_ES.md"
echo "├── LICENSE"
echo "├── VERSION"
echo "├── docs/"
echo "│   ├── FEATURES.md"
echo "│   ├── INSTALLATION.md"
echo "│   └── QUICK_START.md"
echo "└── .github/"
echo "    └── workflows/"

echo ""

print_header "✅ Cleanup Complete!"

echo "Next steps:"
echo "  1. Review any files marked as CRITICAL if missing"
echo "  2. Run: git status (to verify changes)"
echo "  3. Run: git add . && git commit -m 'chore: cleanup repository'"
echo "  4. Run: git push origin main"
echo ""

print_success "Repository is now clean and ready for GitHub deployment!"
echo ""
