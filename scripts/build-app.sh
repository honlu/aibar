#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/aibar-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
swift build -c release --disable-sandbox --cache-path "${TMPDIR:-/tmp}/aibar-spm-cache"
APP="dist/AIbar.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/AIbar "$APP/Contents/MacOS/AIbar"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>AIbar</string>
<key>CFBundleDisplayName</key><string>AIbar</string>
<key>CFBundleIdentifier</key><string>com.honlu.aibar</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleExecutable</key><string>AIbar</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Add :AIbarAGYWorkingDirectory string $PWD" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
printf 'Built %s\n' "$APP"
