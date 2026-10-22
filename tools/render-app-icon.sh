#!/bin/sh
# Regenerates the app icon from tools/AppIconComposition.swift. Run after changing the drawing or
# Tuck/MascotSurfaces.swift, and commit the PNG with the change.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
out="$root/Tuck/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
bin=$(mktemp -d)/render-app-icon

swiftc -O -o "$bin" \
    "$root/Tuck/Color+Palette.swift" \
    "$root/Tuck/MascotGeometry.swift" \
    "$root/Tuck/MascotSurfaces.swift" \
    "$root/tools/AppIconComposition.swift" \
    "$root/tools/render-app-icon.swift"

"$bin" "$out"
