#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/screenshots docs/screenshots
swiftc -module-cache-path "${TMPDIR:-/tmp}/dockchord-clang-cache" Sources/DockChord/Appearance.swift Sources/DockChord/Models.swift Sources/DockChord/HotKeys.swift Sources/DockChord/Views.swift scripts/Screenshots.swift -o .build/screenshots/render
CAPTURE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dockchord-images.XXXXXX")
.build/screenshots/render "$CAPTURE_DIR"
cp "$CAPTURE_DIR/"*.png docs/screenshots/
