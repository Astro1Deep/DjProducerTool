#!/bin/bash
#
# build_release_pack.sh
# Prepara un paquete de lanzamiento para subir a GitHub Releases.
#
# Este script hará lo siguiente:
# 1. Preguntará por la versión del lanzamiento.
# 2. Regenerará las capturas SVG de los menús (requiere termtosvg).
# 3. Construirá el instalador .pkg de macOS.
# 4. Creará un archivo .tar.gz con el código fuente limpio.
# 5. Agrupará todos los artefactos en una carpeta 'release/VERSION'.

set -e

# Re-ejecuta con bash si no se lanzó con bash (necesario para arrays asociativos)
if [ -z "${BASH_VERSION:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  exec bash "$0" "$@"
fi

# --- Configuración ---
APP_NAME="DJProducerTools"
DEFAULT_VERSION="1.0"
RELEASE_ROOT_DIR="release"

# --- Funciones ---
ensure_termtosvg() {
    if ! command -v termtosvg &> /dev/null; then
        echo "⚠️  Advertencia: 'termtosvg' no está instalado."
        echo "No se podrán regenerar las capturas de los menús."
        echo "Para instalarlo, ejecuta: pip install termtosvg"
        return 1
    fi
    return 0
}

# --- Inicio del Script ---
echo "📦 Creando paquete de lanzamiento para GitHub..."

# 1. Preguntar por la versión
read -p "Introduce el número de versión para este lanzamiento (ej: $DEFAULT_VERSION): " VERSION
if [ -z "$VERSION" ]; then
    VERSION="$DEFAULT_VERSION"
    echo "Usando versión por defecto: $VERSION"
fi

RELEASE_DIR="$RELEASE_ROOT_DIR/$VERSION"
SOURCE_ARCHIVE_NAME="${APP_NAME}_${VERSION}_source.tar.gz"
PKG_INSTALLER_NAME="${APP_NAME}_Installer.pkg"

# 2. Limpiar y crear directorio de lanzamiento
echo "🧹 Limpiando y preparando el directorio de lanzamiento..."
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# 3. Regenerar SVGs de los menús
if ensure_termtosvg; then
    echo "🎨 Regenerando capturas SVG de los menús..."
    if [ -f "docs/generate_menu_svgs.sh" ]; then
        bash docs/generate_menu_svgs.sh
    else
        echo "❌ Error: No se encuentra el script 'docs/generate_menu_svgs.sh'."
        exit 1
    fi
else
    echo "⏭️  Saltando regeneración de SVG."
fi

# 4. Construir el instalador .pkg
echo "🛠️  Construyendo el instalador .pkg de macOS..."
if [ -f "build_macos_pkg.sh" ]; then
    sed -i.bak "s/^VERSION=.*/VERSION=\"$VERSION\"/" build_macos_pkg.sh
    bash build_macos_pkg.sh
    mv build_macos_pkg.sh.bak build_macos_pkg.sh # Restaurar
    if [ -f "$PKG_INSTALLER_NAME" ]; then
        mv "$PKG_INSTALLER_NAME" "$RELEASE_DIR/"
        echo "✅ Instalador .pkg movido a $RELEASE_DIR/"
    else
        echo "❌ Error: No se encontró el instalador $PKG_INSTALLER_NAME."
        exit 1
    fi
else
    echo "❌ Error: No se encuentra el script 'build_macos_pkg.sh'."
    exit 1
fi

# 5. Crear archivo con el código fuente
echo "🗜️  Creando archivo tar.gz del código fuente..."
tar -czf "$RELEASE_DIR/$SOURCE_ARCHIVE_NAME" --exclude=".git" --exclude=".github" --exclude="_DJProducerTools" --exclude="build_pkg_staging" --exclude="$RELEASE_ROOT_DIR" --exclude="*.tmp" --exclude="*.bak" --exclude=".DS_Store" --exclude="*.swp" .
echo "✅ Archivo de código fuente creado en $RELEASE_DIR/"

# 6. Generar borrador de notas de la versión (Changelog)
echo "📝 Generando borrador del changelog..."
CHANGELOG_FILE="$RELEASE_DIR/CHANGELOG_DRAFT.md"
# Si no hay tags, usa el primer commit como base
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)

# Define los tipos de commit y sus cabeceras para el changelog
declare -A commit_groups
commit_groups=(
    ["feat"]="✨ Features"
    ["fix"]="🐛 Bug Fixes"
    ["docs"]="📚 Documentation"
    ["style"]="💅 Styles"
    ["refactor"]="♻️ Code Refactoring"
    ["perf"]="⚡ Performance Improvements"
    ["test"]="🧪 Tests"
    ["build"]="📦 Build System"
    ["ci"]="🤖 Continuous Integration"
    ["chore"]="🧹 Chores"
)

# Archivos temporales para cada grupo
for type in "${!commit_groups[@]}"; do
    >"$RELEASE_DIR/${type}.tmp"
done
>"$RELEASE_DIR/other.tmp"

# Lee cada commit y lo clasifica
COMMIT_COUNT=$(git rev-list --count "$LATEST_TAG"..HEAD 2>/dev/null || echo 0)
if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo "⚠️  No hay commits nuevos desde el último tag ($LATEST_TAG). El changelog estará vacío."
    echo "# Borrador de Notas de Versión para v$VERSION" > "$CHANGELOG_FILE"
    echo "" >> "$CHANGELOG_FILE"
    echo "No hay cambios desde la última versión." >> "$CHANGELOG_FILE"
else
git log "$LATEST_TAG"..HEAD --pretty=format:"%s" | while IFS= read -r commit_msg; do
    matched=0
    for type in "${!commit_groups[@]}"; do
        if [[ "$commit_msg" =~ ^$type(\(.*\))?: ]]; then
            message=$(echo "$commit_msg" | sed -E "s/^$type(\(.*\))?:\s*//")
            echo "- $message" >> "$RELEASE_DIR/${type}.tmp"
            matched=1
            break
        fi
    done
    if [ "$matched" -eq 0 ]; then
        echo "- $commit_msg" >> "$RELEASE_DIR/other.tmp"
    fi
done

# Construye el archivo de changelog final
{
    echo "# Borrador de Notas de Versión para v$VERSION"
    echo ""
    echo "**Por favor, edita este archivo antes de publicarlo.**"
    echo ""
    for type in "${!commit_groups[@]}"; do
        if [ -s "$RELEASE_DIR/${type}.tmp" ]; then
            echo "### ${commit_groups[$type]}"
            echo ""
            cat "$RELEASE_DIR/${type}.tmp"
            echo ""
        fi
    done
    if [ -s "$RELEASE_DIR/other.tmp" ]; then
        echo "### Otros Cambios"
        echo ""
        cat "$RELEASE_DIR/other.tmp"
        echo ""
    fi
} > "$CHANGELOG_FILE"
fi

# Limpia archivos temporales
rm -f "$RELEASE_DIR"/*.tmp

echo "✅ Borrador del changelog creado en $CHANGELOG_FILE"

# 7. Crear archivos con la documentación por idioma
echo "📚 Creando archivos .zip de la documentación..."
DOCS_EN_NAME="${APP_NAME}_${VERSION}_documentation_EN.zip"
DOCS_ES_NAME="${APP_NAME}_${VERSION}_documentation_ES.zip"
zip -j "$RELEASE_DIR/$DOCS_EN_NAME" README_en.md GUIDE_en.md LICENSE_en.md "$CHANGELOG_FILE" > /dev/null
zip -j "$RELEASE_DIR/$DOCS_ES_NAME" README_es.md GUIDE_es.md LICENSE_es.md "$CHANGELOG_FILE" > /dev/null
echo "✅ Archivos de documentación creados."

# 8. Publicar en GitHub (Opcional)
echo ""
if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "NOTA: GITHUB_TOKEN no está configurado. Saltando publicación automática en GitHub."
    echo "      Para habilitarlo, exporta GITHUB_TOKEN con un token de acceso personal."
else
    read -p "🚀 ¿Publicar automáticamente el release v$VERSION en GitHub? (y/N): " publish_ans
    if [[ "$publish_ans" =~ ^[yY]$ ]]; then
        echo "   -> Publicando en el repositorio: $GITHUB_REPO"

        if ! command -v jq &> /dev/null; then
            echo "   ⚠️  Advertencia: 'jq' no está instalado. Se intentará parsear con awk, pero puede ser menos fiable."
            echo "      Para instalarlo: brew install jq"
        fi

        echo "   -> Creando y pusheando tag git v$VERSION..."
        git tag -a "v$VERSION" -m "Release v$VERSION"
        git push origin "v$VERSION"

        echo "   -> Creando el release en GitHub..."
        CHANGELOG_BODY=$(sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g' -e 's/"/\\"/g' < "$CHANGELOG_FILE")
        JSON_PAYLOAD=$(printf '{"tag_name": "v%s", "name": "v%s", "body": "%s", "draft": false, "prerelease": false}' "$VERSION" "$VERSION" "$CHANGELOG_BODY")

        API_RESPONSE=$(curl -s -L \
          -X POST \
          -H "Accept: application/vnd.github+json" \
          -H "Authorization: Bearer $GITHUB_TOKEN" \
          -H "X-GitHub-Api-Version: 2022-11-28" \
          "https://api.github.com/repos/$GITHUB_REPO/releases" \
          -d "$JSON_PAYLOAD")

        if command -v jq &> /dev/null; then
            UPLOAD_URL=$(echo "$API_RESPONSE" | jq -r .upload_url)
        else
            UPLOAD_URL=$(echo "$API_RESPONSE" | grep '"upload_url"' | awk -F'"' '{print $4}')
        fi

        if [ -z "$UPLOAD_URL" ] || [ "$UPLOAD_URL" == "null" ]; then
            echo "   ❌ Error: No se pudo crear el release en GitHub. Respuesta de la API:"
            echo "$API_RESPONSE"
            exit 1
        fi
        echo "   -> Release creado. Subiendo artefactos..."

        for asset in "$RELEASE_DIR"/*; do
            if [ -f "$asset" ]; then
                ASSET_NAME=$(basename "$asset")
                echo "      -> Subiendo: $ASSET_NAME..."
                UPLOAD_URL_ASSET="${UPLOAD_URL%\{?name,label\}}?name=${ASSET_NAME}"

                curl -s -L \
                  -X POST \
                  -H "Accept: application/vnd.github+json" \
                  -H "Authorization: Bearer $GITHUB_TOKEN" \
                  -H "X-GitHub-Api-Version: 2022-11-28" \
                  -H "Content-Type: application/octet-stream" \
                  "$UPLOAD_URL_ASSET" \
                  --data-binary "@$asset" > /dev/null
            fi
        done
        echo "✅ ¡Release publicado en GitHub con éxito!"
    fi
fi

# 9. Finalización
echo ""
echo "✨ ¡Paquete de lanzamiento completado!"
echo "-------------------------------------"
echo "Los artefactos para subir a GitHub están en: $PWD/$RELEASE_DIR"
echo ""
echo "Contenido:"
ls -l "$RELEASE_DIR"
echo ""
if [[ ! "$publish_ans" =~ ^[yY]$ ]]; then
    echo "Próximos pasos:"
    echo "1. Ve a la página de tu repositorio en GitHub."
    echo "2. Haz clic en 'Releases' -> 'Draft a new release'."
    echo "3. Usa '$VERSION' como tag y título del lanzamiento."
    echo "4. **Edita el archivo '$CHANGELOG_FILE'** y copia su contenido en la descripción del release."
    echo "5. Sube los archivos que están en la carpeta '$RELEASE_DIR/'."
    echo "6. ¡Publica el lanzamiento!"
fi

# Abrir el borrador del changelog para edición final
if [ -f "$CHANGELOG_FILE" ]; then
    open "$CHANGELOG_FILE"
fi