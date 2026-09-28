#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/checks
swiftc -module-cache-path "${TMPDIR:-/tmp}/dockchord-clang-cache" Sources/DockChord/Models.swift Tests/DockChordTests/ModelTests.swift -o .build/checks/ModelTests
.build/checks/ModelTests
