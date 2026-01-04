#!/bin/bash
# build_macos_pkg.sh
# Crea una APP (.app) y un instalador .pkg para DJProducerTools
# Incluye generación de icono y opción de firma digital.

APP_NAME="DJProducerTools"
VERSION="1.0"
IDENTIFIER="com.astroonedeep.djproducertools"
INSTALL_LOC="/Applications" # El pkg instalará en /Applications/DJProducerTools/
OUTPUT_PKG="${APP_NAME}_Installer.pkg"
STAGING_DIR="build_pkg_staging"
PAYLOAD_DIR="$STAGING_DIR/payload"
INSTALL_ROOT="$PAYLOAD_DIR/$APP_NAME"
APP_BUNDLE="$INSTALL_ROOT/$APP_NAME.app"

 # --- SIGNING CONFIGURATION / CONFIGURACIÓN DE FIRMA ---
 # Uncomment and set your ID if you have an Apple Developer Account.
 # Descomenta y pon tu ID si tienes una cuenta de Apple Developer.
 # SIGNING_IDENTITY="Developer ID Installer: Your Name (XXXXXXXXXX)"
 
 # --- NOTARIZATION CONFIGURATION (Requires SIGNING_IDENTITY) ---
 # To notarize, you need an app-specific password from appleid.apple.com
 # Para notarizar, necesitas una contraseña específica de app desde appleid.apple.com
 # APPLE_ID_EMAIL="your-apple-id@example.com"
 # APPLE_ID_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"

echo "Building $OUTPUT_PKG..."

# Limpiar y crear estructura
rm -rf "$STAGING_DIR"
mkdir -p "$INSTALL_ROOT"
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
chmod +x "$APP_BUNDLE/Contents/Resources/"*.sh

# Crear carpetas de documentación y copiar archivos por idioma
DOCS_DIR_ES="$INSTALL_ROOT/Documentation_ES"
DOCS_DIR_EN="$INSTALL_ROOT/Documentation_EN"
mkdir -p "$DOCS_DIR_ES" "$DOCS_DIR_EN"
cp README_es.md GUIDE_es.md LICENSE_es.md "$DOCS_DIR_ES/" 2>/dev/null || echo "Advertencia: Faltan archivos de documentación en español."
cp README_en.md GUIDE_en.md LICENSE_en.md "$DOCS_DIR_EN/" 2>/dev/null || echo "Advertencia: Faltan archivos de documentación en inglés."
echo "Documentation copied."

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
pkgbuild --root "$PAYLOAD_DIR" \
         --identifier "$IDENTIFIER" \
         --version "$VERSION" \
         --install-location "$INSTALL_LOC" \
         ${SIGNING_IDENTITY:+--sign "$SIGNING_IDENTITY"} \
         "$OUTPUT_PKG"

 # 6. Notarize package (Optional, requires signing and credentials)
if [ -n "${SIGNING_IDENTITY:-}" ] && [ -n "${APPLE_ID_EMAIL:-}" ] && [ -n "${APPLE_ID_APP_PASSWORD:-}" ]; then
    echo "Submitting for notarization..."
    
    # Submit for notarization
    NOTARIZE_OUTPUT=$(xcrun altool --notarize-app \
        --file "$OUTPUT_PKG" \
        --primary-bundle-id "$IDENTIFIER" \
        --username "$APPLE_ID_EMAIL" \
        --password "$APPLE_ID_APP_PASSWORD" 2>&1)

    if [ $? -ne 0 ]; then
        echo "❌ Notarization submission failed:"
        echo "$NOTARIZE_OUTPUT"
        exit 1
    fi

    REQUEST_UUID=$(echo "$NOTARIZE_OUTPUT" | awk '/RequestUUID/ {print $3}')
    if [ -z "$REQUEST_UUID" ]; then
        echo "❌ Could not get RequestUUID from notarization submission."
        echo "$NOTARIZE_OUTPUT"
        exit 1
    fi

    echo "✅ Submitted for notarization. RequestUUID: $REQUEST_UUID"
    echo "🕒 Waiting for notarization to complete (this can take several minutes)..."

    # Poll for status
    while true; do
        sleep 60
        NOTARIZATION_STATUS=$(xcrun altool --notarization-info "$REQUEST_UUID" --username "$APPLE_ID_EMAIL" --password "$APPLE_ID_APP_PASSWORD" 2>&1)
        
        STATUS=$(echo "$NOTARIZATION_STATUS" | awk -F': ' '/Status:/ {print $2}')
        echo "   -> Current status: ${STATUS:-checking...}"

        if [ "$STATUS" == "success" ]; then
            echo "✅ Notarization successful."
            xcrun stapler staple "$OUTPUT_PKG"
            echo "✅ Stapler successful."
            break
        elif [ "$STATUS" == "invalid" ]; then
            echo "❌ Notarization failed."
            echo "$NOTARIZATION_STATUS"
            exit 1
        fi
    done
else
    echo "NOTE: Notarization skipped. To enable, set SIGNING_IDENTITY, APPLE_ID_EMAIL, and APPLE_ID_APP_PASSWORD."
fi

echo "Done. Installer created at: $PWD/$OUTPUT_PKG"
if [ -z "$SIGNING_IDENTITY" ]; then
    echo "NOTE: Package is unsigned. To avoid security warnings, right-click > Open to install."
fi