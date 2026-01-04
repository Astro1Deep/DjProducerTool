#!/usr/bin/env bash

################################################################################
# DJProducerTools Installer for macOS
# 
# Usage: ./install_djpt.sh
#
# This installer downloads and sets up DJProducerTools from GitHub
################################################################################

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Configuration
readonly REPO="Astro1Deep/DjProducerTool"
readonly GITHUB_RAW="https://raw.githubusercontent.com/$REPO/main"
readonly INSTALL_DIR="${HOME}/.local/bin"
readonly SCRIPTS=("DJProducerTools_MultiScript_EN.sh" "DJProducerTools_MultiScript_ES.sh")

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                                    ║${NC}"
echo -e "${BLUE}║  🎧 DJProducerTools Installer                                      ║${NC}"
echo -e "${BLUE}║  Professional DJ Production Suite for macOS                        ║${NC}"
echo -e "${BLUE}║                                                                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download scripts
echo -e "${BLUE}Downloading DJProducerTools...${NC}"
for script in "${SCRIPTS[@]}"; do
    url="$GITHUB_RAW/$script"
    echo "  Fetching: $script..."
    if curl -fsSL "$url" -o "$INSTALL_DIR/$script"; then
        chmod +x "$INSTALL_DIR/$script"
        echo -e "  ${GREEN}✓${NC} $script"
    else
        echo -e "  ${RED}✗${NC} Failed to download $script"
        exit 1
    fi
done

# Verify installation
echo ""
echo -e "${BLUE}Verifying installation...${NC}"
for script in "${SCRIPTS[@]}"; do
    if [ -x "$INSTALL_DIR/$script" ]; then
        echo -e "  ${GREEN}✓${NC} $script is ready"
    fi
done

# Create alias in current directory (fallback)
echo ""
echo -e "${BLUE}Setting up local scripts...${NC}"
for script in "${SCRIPTS[@]}"; do
    if [ ! -f "./$script" ]; then
        cp "$INSTALL_DIR/$script" "./$script"
        echo -e "  ${GREEN}✓${NC} Copied $script to current directory"
    fi
done

echo ""
echo -e "${GREEN}✓ Installation complete!${NC}"
echo ""
echo "📍 Available locations:"
echo "   Local: ./$SCRIPTS[0]"
echo "   System: $INSTALL_DIR/$SCRIPTS[0]"
echo ""
echo "🚀 To get started:"
echo ""
echo "   # Run English version"
echo "   ./${SCRIPTS[0]}"
echo ""
echo "   # Run Spanish version"
echo "   ./${SCRIPTS[1]}"
echo ""
echo "📚 For help and documentation:"
echo "   GitHub: https://github.com/$REPO"
echo ""

