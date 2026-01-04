#!/bin/bash
#
# DJProducerTools - Universal Installer v1.0
# Installs both English and Spanish versions
# Usage: ./install.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    
    printf "${BLUE}["
    printf "%${filled}s" | tr ' ' '='
    printf "%$((width-filled))s" | tr ' ' '-'
    printf "]${NC} ${percent}%% ($current/$total)\n"
}

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║        DJProducerTools Universal Installer              ║"
echo "║              Instalador Universal v1.0                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Get GitHub repo info
GITHUB_USER="Astro1Deep"
GITHUB_REPO="DjProducerTool"
GITHUB_BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Create directories
echo -e "${BLUE}Creating directories...${NC}"
mkdir -p ~/DJProducerTools/scripts
mkdir -p ~/DJProducerTools/docs
mkdir -p ~/DJProducerTools/bin

INSTALL_DIR=~/DJProducerTools

progress_bar 1 3

# Download scripts
echo -e "${BLUE}Downloading scripts...${NC}"

scripts=("DJProducerTools_MultiScript_EN.sh" "DJProducerTools_MultiScript_ES.sh")
script_count=${#scripts[@]}

for i in "${!scripts[@]}"; do
    script="${scripts[$i]}"
    progress_bar $((i + 1)) $script_count
    echo -ne "${BLUE}Downloading ${script}...${NC}\r"
    
    curl -fsSL "${BASE_URL}/scripts/${script}" -o "${INSTALL_DIR}/scripts/${script}" 2>/dev/null
    chmod +x "${INSTALL_DIR}/scripts/${script}"
    echo -e "${GREEN}✓ ${script} downloaded${NC}"
done

progress_bar 3 3

# Create quick start scripts
echo -e "${BLUE}Creating launch scripts...${NC}"

cat > "${INSTALL_DIR}/bin/dj-en" << 'ENEOF'
#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")/.."
./scripts/DJProducerTools_MultiScript_EN.sh "$@"
ENEOF

cat > "${INSTALL_DIR}/bin/dj-es" << 'ESEOF'
#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")/.."
./scripts/DJProducerTools_MultiScript_ES.sh "$@"
ESEOF

chmod +x "${INSTALL_DIR}/bin/dj-en"
chmod +x "${INSTALL_DIR}/bin/dj-es"

# Summary
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Installation Complete!                           ║${NC}"
echo -e "${GREEN}║         ¡Instalación Completada!                         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Location: ${INSTALL_DIR}${NC}"
echo ""
echo "To run the tools:"
echo "  dj-en      # English version"
echo "  dj-es      # Spanish version"
echo ""
