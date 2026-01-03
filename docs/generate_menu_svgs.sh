#!/bin/bash
#
# Genera automáticamente las capturas SVG de los menús para la documentación.
# Requiere 'termtosvg', que puedes instalar con: pip install termtosvg

set -e

SCRIPT_DIR="$(cd -- "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

# --- Requisito ---
if ! command -v termtosvg &> /dev/null; then
    echo "Error: 'termtosvg' no está instalado."
    echo "Por favor, instálalo para continuar:"
    echo "  pip install termtosvg"
    exit 1
fi

echo "✅ 'termtosvg' encontrado."

# --- Generar SVG para el script en Español ---
echo "🎨 Generando SVG para el menú en Español..."
(
  # Ejecutamos en un subshell para evitar que las funciones/variables
  # interfieran con la siguiente ejecución.
  source ./DJProducerTools_MultiScript_ES.sh
  print_header
  print_menu
) | termtosvg -o docs/menu_es_full.svg
echo "   -> Creado en docs/menu_es_full.svg"

# --- Generar SVG para el script en Inglés ---
echo "🎨 Generando SVG para el menú en Inglés..."
(
  source ./DJProducerTools_MultiScript_EN.sh
  print_header
  print_menu
) | termtosvg -o docs/menu_en_full.svg
echo "   -> Creado en docs/menu_en_full.svg"

echo "✨ ¡Proceso completado!"