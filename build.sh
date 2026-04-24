#!/bin/bash
set -e

APP_NAME="LuminaMax"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR=".build/release"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🔨 Building ${APP_NAME}..."
swift build -c release 2>&1

echo "📦 Creating app bundle..."

# Remove old bundle if exists
rm -rf "${SCRIPT_DIR}/${BUNDLE_NAME}"

# Create bundle structure
mkdir -p "${SCRIPT_DIR}/${BUNDLE_NAME}/Contents/MacOS"
mkdir -p "${SCRIPT_DIR}/${BUNDLE_NAME}/Contents/Resources"

# Copy binary
cp "${SCRIPT_DIR}/${BUILD_DIR}/${APP_NAME}" "${SCRIPT_DIR}/${BUNDLE_NAME}/Contents/MacOS/"

# Copy Info.plist and AppIcon
cp "${SCRIPT_DIR}/Resources/Info.plist" "${SCRIPT_DIR}/${BUNDLE_NAME}/Contents/"
if [ -f "${SCRIPT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${SCRIPT_DIR}/Resources/AppIcon.icns" "${SCRIPT_DIR}/${BUNDLE_NAME}/Contents/Resources/"
fi

# Try to compile Metal shaders (optional - app has runtime fallback)
echo "🎨 Compiling Metal shaders..."
SHADER_SRC="${SCRIPT_DIR}/Sources/LuminaMax/Shaders.metal"
if [ -f "$SHADER_SRC" ]; then
    if xcrun metal -c "$SHADER_SRC" -o "${SCRIPT_DIR}/${BUNDLE_NAME}/Contents/Resources/Shaders.air" 2>/dev/null; then
        xcrun metallib "${SCRIPT_DIR}/${BUNDLE_NAME}/Contents/Resources/Shaders.air" -o "${SCRIPT_DIR}/${BUNDLE_NAME}/Contents/Resources/default.metallib" 2>/dev/null
        rm -f "${SCRIPT_DIR}/${BUNDLE_NAME}/Contents/Resources/Shaders.air"
        echo "✅ Metal shaders compiled successfully"
    else
        echo "⚠️  Metal Toolchain nicht verfügbar - Shader werden zur Laufzeit kompiliert"
        echo "   (Installiere mit: xcodebuild -downloadComponent MetalToolchain)"
    fi
else
    echo "⚠️  No Metal shader source found, will use runtime compilation fallback"
fi

# Create a minimal PkgInfo
echo -n "APPL????" > "${SCRIPT_DIR}/${BUNDLE_NAME}/Contents/PkgInfo"

echo ""
echo "✅ ${BUNDLE_NAME} wurde erfolgreich erstellt!"
echo "📍 Pfad: ${SCRIPT_DIR}/${BUNDLE_NAME}"
echo ""
echo "🚀 Starte mit: open ${SCRIPT_DIR}/${BUNDLE_NAME}"
echo ""
echo "⚠️  Hinweis: Die App ist nicht signiert. Beim ersten Start:"
echo "   1. Rechtsklick auf die App → 'Öffnen'"
echo "   2. Oder: Systemeinstellungen → Datenschutz & Sicherheit → 'Trotzdem öffnen'"
