#!/bin/bash
# build_macos_pkg.sh
# Crea una APP (.app) y un instalador .pkg para DJProducerTools
# Incluye generación de icono y opción de firma digital.

APP_NAME="DJProducerTools"
VERSION="1.0"
IDENTIFIER="com.astroonedeep.djproducertools"
INSTALL_LOC="/Applications"
OUTPUT_PKG="${APP_NAME}_Installer.pkg"
STAGING_DIR="build_pkg_staging"
APP_BUNDLE="$STAGING_DIR/payload/$APP_NAME.app"

# --- CONFIGURACIÓN DE FIRMA (Descomenta y pon tu ID si tienes Apple Developer Account) ---
# SIGNING_IDENTITY="Developer ID Installer: Tu Nombre (XXXXXXXXXX)"

echo "Building $OUTPUT_PKG..."

# Limpiar y crear estructura
rm -rf "$STAGING_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 1. Crear el lanzador (Launcher Script)
# Este script se ejecutará al hacer doble clic en la App
cat <<'EOF' > "$APP_BUNDLE/Contents/MacOS/launcher"
#!/bin/bash
DIR=$(cd "$(dirname "$0")" && pwd)
RES="$DIR/../Resources"

# Diálogo simple para elegir idioma
LANG_CHOICE=$(osascript -e 'button returned of (display dialog "Select Language / Selecciona Idioma" buttons {"Español", "English"} default button "English" with title "DJProducerTools")')

if [ "$LANG_CHOICE" = "Español" ]; then
  SCRIPT="$RES/DJProducerTools_MultiScript_ES.sh"
else
  SCRIPT="$RES/DJProducerTools_MultiScript_EN.sh"
fi

# Abrir en Terminal
open -a Terminal "$SCRIPT"
EOF
chmod +x "$APP_BUNDLE/Contents/MacOS/launcher"

# 2. Crear Info.plist
cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$IDENTIFIER</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
</dict>
</plist>
EOF

# 3. Copiar recursos (Scripts y Docs)
echo "Copying resources..."
cp "DJProducerTools_MultiScript_ES.sh" "$APP_BUNDLE/Contents/Resources/"
cp "DJProducerTools_MultiScript_EN.sh" "$APP_BUNDLE/Contents/Resources/"
[ -f "README.md" ] && cp "README.md" "$APP_BUNDLE/Contents/Resources/"
[ -f "LICENSE" ] && cp "LICENSE" "$APP_BUNDLE/Contents/Resources/"
[ -f "GUIDE.md" ] && cp "GUIDE.md" "$APP_BUNDLE/Contents/Resources/"
chmod +x "$APP_BUNDLE/Contents/Resources/"*.sh

# 4. Generar Icono (Si existe icon.png)
if [ -f "icon.png" ]; then
    echo "Generating .icns from icon.png..."
    mkdir "$STAGING_DIR/icon.iconset"
    sips -z 16 16     icon.png --out "$STAGING_DIR/icon.iconset/icon_16x16.png" >/dev/null
    sips -z 32 32     icon.png --out "$STAGING_DIR/icon.iconset/icon_16x16@2x.png" >/dev/null
    sips -z 128 128   icon.png --out "$STAGING_DIR/icon.iconset/icon_128x128.png" >/dev/null
    sips -z 256 256   icon.png --out "$STAGING_DIR/icon.iconset/icon_128x128@2x.png" >/dev/null
    sips -z 512 512   icon.png --out "$STAGING_DIR/icon.iconset/icon_512x512.png" >/dev/null
    iconutil -c icns "$STAGING_DIR/icon.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "WARNING: icon.png not found. Using generic icon."
fi

# 5. Construir paquete
echo "Running pkgbuild..."
pkgbuild --root "$STAGING_DIR/payload" \
         --identifier "$IDENTIFIER" \
         --version "$VERSION" \
         --install-location "$INSTALL_LOC" \
         ${SIGNING_IDENTITY:+--sign "$SIGNING_IDENTITY"} \
         "$OUTPUT_PKG"

echo "Done. Installer created at: $PWD/$OUTPUT_PKG"
if [ -z "$SIGNING_IDENTITY" ]; then
    echo "NOTE: Package is unsigned. To avoid security warnings, right-click > Open to install."
fi