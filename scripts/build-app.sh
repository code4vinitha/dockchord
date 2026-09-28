#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/dockchord-clang-cache"
swift build -c release --disable-sandbox
APP="$PWD/dist/DockChord.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/DockChord "$APP/Contents/MacOS/DockChord"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>DockChord</string>
<key>CFBundleDisplayName</key><string>DockChord</string>
<key>CFBundleIdentifier</key><string>io.github.kishoregv.dockchord</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleExecutable</key><string>DockChord</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Remove Finder metadata from the generated bundle before signing.
xattr -cr "$APP"
codesign --force --sign - "$APP"
printf 'Built %s\n' "$APP"
