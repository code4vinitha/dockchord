#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
VARIANT="${1:-strict}"
case "$VARIANT" in
  strict) ENTITLEMENTS=Configuration/Sandbox.entitlements; DOCK_ACCESS=false ;;
  dock) ENTITLEMENTS=Configuration/SandboxDock.entitlements; DOCK_ACCESS=true ;;
  *) print -u2 'Usage: scripts/build-sandbox-app.sh [strict|dock]'; exit 2 ;;
esac
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/dockchord-clang-cache"
swift build -c release --disable-sandbox
OUTPUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dockchord-sandbox-app.XXXXXX")
APP="$OUTPUT_DIR/DockChord Sandbox.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" dist
cp .build/release/DockChord "$APP/Contents/MacOS/DockChord"
cp Resources/PrivacyInfo.xcprivacy "$APP/Contents/Resources/"
python3 - "$APP" "$VARIANT" "$DOCK_ACCESS" <<'PY'
import plistlib, sys
from pathlib import Path
app, variant, allow = sys.argv[1:]
info = {'CFBundleName': 'DockChord Sandbox', 'CFBundleDisplayName': 'DockChord Sandbox',
        'CFBundleIdentifier': 'io.github.code4vinitha.dockchord.prototype.' + variant,
        'CFBundleExecutable': 'DockChord', 'CFBundlePackageType': 'APPL',
        'CFBundleVersion': '1', 'CFBundleShortVersionString': '1.0.0',
        'LSMinimumSystemVersion': '13.0', 'LSUIElement': True,
        'NSHighResolutionCapable': True, 'LSApplicationCategoryType': 'public.app-category.productivity',
        'DockChordAllowsDockPreferences': allow == 'true'}
with (Path(app) / 'Contents/Info.plist').open('wb') as f: plistlib.dump(info, f)
PY
codesign --force --sign - --options runtime --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --strict "$APP"
printf '%s\n' "$APP" > "dist/sandbox-$VARIANT-path.txt"
printf 'Sandbox prototype (%s): %s\n' "$VARIANT" "$APP"
printf 'Quit other DockChord copies before testing global shortcuts.\n'
