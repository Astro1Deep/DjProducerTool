#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://raw.githubusercontent.com/Astro1Deep/DjProducerTool/main/scripts"
FILES=(
  "DJProducerTools_MultiScript_ES.sh"
  "DJProducerTools_MultiScript_EN.sh"
)

for f in "${FILES[@]}"; do
  url="${BASE_URL}/${f}"
  echo "Downloading ${f} from ${url}..."
  if ! curl -fsSL "${url}" -o "${f}"; then
    echo "Error: could not download ${f}."
    exit 1
  fi
  chmod +x "${f}" 2>/dev/null || true
done

echo "Done. Run ./DJProducerTools_MultiScript_ES.sh or ./DJProducerTools_MultiScript_EN.sh"
