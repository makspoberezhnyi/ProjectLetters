#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR/LettersApp"

echo "🔨 Building LettersApp..."
swift build -c release

APP_DIR="$DIR/Letters.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$APP_DIR/Contents/Frameworks"

cp "$DIR/LettersApp/.build/release/LettersApp" "$APP_DIR/Contents/MacOS/Letters"
if [ -f "$DIR/../core/letters_core/target/release/libletters_core.dylib" ]; then
    cp "$DIR/../core/letters_core/target/release/libletters_core.dylib" "$APP_DIR/Contents/Frameworks/"
fi

cat <<EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Letters</string>
    <key>CFBundleIdentifier</key>
    <string>com.projectletters.Letters</string>
    <key>CFBundleName</key>
    <string>Letters</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "✅ Successfully bundled Letters.app at: $APP_DIR"
