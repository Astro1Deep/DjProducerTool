#!/usr/bin/env bash
set -e

GITHUB_REPO="Astro1Deep/DjProducerTool" # Cambia esto a "TuUsuario/TuRepositorio"

echo "⬇️  Downloading DJProducerTools..."
mkdir -p DJProducerTools
cd DJProducerTools
for f in DJProducerTools_MultiScript_ES.sh DJProducerTools_MultiScript_EN.sh; do
  url="https://raw.githubusercontent.com/$GITHUB_REPO/main/$f"
  echo "   - Downloading $f..."
  curl -fsSL "$url" -o "$f"
  chmod +x "$f"
done
echo ""
echo "✅ Installation complete! Files are in the 'DJProducerTools' directory."
echo "   cd DJProducerTools"
echo "   Run ./DJProducerTools_MultiScript_ES.sh (Español) or ./DJProducerTools_MultiScript_EN.sh (English) to start."
