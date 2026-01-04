#!/usr/bin/env bash
set -e

echo "🎵 DJProducerTools Installation"
echo "================================"
echo ""

# Detect language
if [[ "$LANG" =~ ^es ]]; then
    SCRIPT="DJProducerTools_MultiScript_ES.sh"
    echo "Descargando versión en Español..."
else
    SCRIPT="DJProducerTools_MultiScript_EN.sh"
    echo "Downloading English version..."
fi

REPO="https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/scripts"
URL="$REPO/$SCRIPT"

echo "URL: $URL"
curl -fsSL "$URL" -o "$SCRIPT" && chmod +x "$SCRIPT" && echo "✅ Done!" || echo "❌ Error downloading"
