#!/bin/bash
#
# DJProducerTools - Universal Installer v2.0
# Installs both English and Spanish versions
# Usage: curl -fsSL https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/INSTALL.sh | bash
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 9); do
            echo -ne "\r${spinstr:$i:1} "
            sleep $delay
        done
    done
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local msg="$3"
    local width=30
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    
    printf "${BLUE}[%-${width}s]${NC} ${percent}%% - ${msg}\n" | head -c $(($width + 1)) | tr '\n' ' '
    printf "%-${width}s" | head -c $filled | tr ' ' '=' > /dev/null 2>&1
    echo ""
}

# Header
clear
echo -e "${GREEN}"
cat << "HEADER"
╔════════════════════════════════════════════════════════════════╗
║         DJProducerTools - Universal Installer v2.0            ║
║    Instalador Universal para DJ Producer Tools v2.0           ║
╚════════════════════════════════════════════════════════════════╝
HEADER
echo -e "${NC}"

# GitHub configuration
GITHUB_USER="Astro1Deep"
GITHUB_REPO="DjProducerTool"
GITHUB_BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Installation directory
INSTALL_DIR="${HOME}/DJProducerTools"
mkdir -p "${INSTALL_DIR}/scripts" "${INSTALL_DIR}/docs" "${INSTALL_DIR}/bin"

echo -e "${BLUE}📦 Installation Directory: ${INSTALL_DIR}${NC}\n"

# Function to download with error handling
download_file() {
    local url=$1
    local dest=$2
    local name=$3
    
    echo -ne "${BLUE}⏳ Downloading ${name}...${NC}"
    
    if curl -fsSL "${url}" -o "${dest}" 2>/dev/null; then
        echo -e "\r${GREEN}✓ ${name}${NC}"
        return 0
    else
        echo -e "\r${RED}✗ Failed to download ${name}${NC}"
        echo -e "${YELLOW}  URL: ${url}${NC}"
        return 1
    fi
}

# Download main scripts
echo -e "\n${BLUE}=== Downloading Main Scripts ===${NC}\n"

download_file "${BASE_URL}/scripts/DJProducerTools_MultiScript_EN.sh" \
    "${INSTALL_DIR}/scripts/DJProducerTools_MultiScript_EN.sh" \
    "DJProducerTools_MultiScript_EN.sh"

download_file "${BASE_URL}/scripts/DJProducerTools_MultiScript_ES.sh" \
    "${INSTALL_DIR}/scripts/DJProducerTools_MultiScript_ES.sh" \
    "DJProducerTools_MultiScript_ES.sh"

# Make scripts executable
chmod +x "${INSTALL_DIR}/scripts"/*.sh

# Create convenience launchers
echo -e "\n${BLUE}=== Creating Launch Scripts ===${NC}\n"

cat > "${INSTALL_DIR}/bin/dj-en" << 'ENEOF'
#!/bin/bash
cd "$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)")"
exec ./scripts/DJProducerTools_MultiScript_EN.sh "$@"
ENEOF

cat > "${INSTALL_DIR}/bin/dj-es" << 'ESEOF'
#!/bin/bash
cd "$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)")"
exec ./scripts/DJProducerTools_MultiScript_ES.sh "$@"
ESEOF

cat > "${INSTALL_DIR}/bin/dj" << 'DEFAULTEOF'
#!/bin/bash
# Auto-detect system language
if [[ $LANG =~ es ]]; then
    exec "$(dirname "$0")/dj-es" "$@"
else
    exec "$(dirname "$0")/dj-en" "$@"
fi
DEFAULTEOF

chmod +x "${INSTALL_DIR}/bin"/*

# Create symlinks (optional)
echo -e "\n${BLUE}=== Setting up PATH shortcuts ===${NC}\n"

for script in dj dj-en dj-es; do
    if [ -w "/usr/local/bin" ]; then
        ln -sf "${INSTALL_DIR}/bin/${script}" /usr/local/bin/${script} 2>/dev/null && \
        echo -e "${GREEN}✓${NC} ${script} available globally" || echo -e "${YELLOW}⚠${NC} Could not create global link for ${script}"
    else
        echo -e "${YELLOW}⚠${NC} /usr/local/bin not writable. To use shortcuts, add to PATH:"
        echo -e "  ${BLUE}export PATH=\"${INSTALL_DIR}/bin:\$PATH\"${NC}"
        break
    fi
done

# Summary
echo ""
echo -e "${GREEN}"
cat << "SUMMARY"
╔════════════════════════════════════════════════════════════════╗
║              ✓ Installation Complete!                         ║
║              ✓ ¡Instalación Completada!                       ║
╚════════════════════════════════════════════════════════════════╝
SUMMARY
echo -e "${NC}"

echo -e "${BLUE}Location / Ubicación:${NC}"
echo "  ${INSTALL_DIR}"
echo ""
echo -e "${BLUE}Quick Start / Inicio Rápido:${NC}"
echo "  ${GREEN}dj${NC}           Auto-detect language"
echo "  ${GREEN}dj-en${NC}       Run English version"
echo "  ${GREEN}dj-es${NC}       Run Spanish version"
echo ""
echo -e "${BLUE}Or run directly / O ejecutar directamente:${NC}"
echo "  ${GREEN}${INSTALL_DIR}/scripts/DJProducerTools_MultiScript_EN.sh${NC}"
echo "  ${GREEN}${INSTALL_DIR}/scripts/DJProducerTools_MultiScript_ES.sh${NC}"
echo ""
echo -e "${YELLOW}Note: Add to ~/.zprofile or ~/.bash_profile if symlinks didn't work:${NC}"
echo "  ${BLUE}export PATH=\"${INSTALL_DIR}/bin:\$PATH\"${NC}"
echo ""
