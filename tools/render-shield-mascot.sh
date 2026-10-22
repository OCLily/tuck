#!/bin/sh
# Regenerates the shield's mascot asset from ShieldMascotIcon.swift. Run after changing the drawing;
# the extension itself never renders it (see tools/render-shield-mascot.swift).
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
out="$root/TuckShield/Assets.xcassets/ShieldMascot.imageset/ShieldMascot@3x.png"
bin=$(mktemp -d)/render-shield-mascot

swiftc -O -o "$bin" \
    "$root/Tuck/Color+Palette.swift" \
    "$root/Tuck/MascotGeometry.swift" \
    "$root/TuckShield/ShieldMascotIcon.swift" \
    "$root/tools/render-shield-mascot.swift"

"$bin" "$out"
