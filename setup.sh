#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="MarkdownPreview"
APP_PATH="/Applications/$APP_NAME.app"

echo "→ Checking dependencies..."
if ! command -v swiftc &>/dev/null; then
    echo "Error: swiftc not found. Run: xcode-select --install"
    exit 1
fi

if [ -d "$APP_PATH" ]; then
    echo "→ Removing previous installation..."
    rm -rf "$APP_PATH"
fi

echo "→ Creating app bundle structure..."
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

echo "→ Compiling Swift app (first run may take ~15 seconds)..."
swiftc "$SCRIPT_DIR/MDPreview.swift" \
    -framework Cocoa -framework WebKit \
    -o "$APP_PATH/Contents/MacOS/$APP_NAME"

echo "→ Installing preview script..."
cp "$SCRIPT_DIR/preview.sh" "$APP_PATH/Contents/Resources/preview.sh"
chmod +x "$APP_PATH/Contents/Resources/preview.sh"

echo "→ Generating app icon..."
ICONSET_DIR=$(swift "$SCRIPT_DIR/make_icon.swift" /tmp/MarkdownPreview.iconset)
iconutil -c icns "$ICONSET_DIR" -o "$APP_PATH/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"

echo "→ Writing Info.plist..."
cat > "$APP_PATH/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MarkdownPreview</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.markdownpreview</string>
    <key>CFBundleName</key>
    <string>MarkdownPreview</string>
    <key>CFBundleDisplayName</key>
    <string>MarkdownPreview</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Markdown Document</string>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>md</string>
            </array>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
        </dict>
    </array>
</dict>
</plist>
PLIST

echo "→ Removing quarantine flag..."
xattr -cr "$APP_PATH"

echo "→ Registering with Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_PATH"

echo ""
echo "✓ $APP_NAME installed to $APP_PATH"
echo ""
echo "First-time setup (if not already done):"
echo "  Right-click any .md file → Get Info → Open With"
echo "  → select MarkdownPreview → click 'Change All'"
