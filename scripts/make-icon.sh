#!/bin/bash
# Renders the Caelum app icon and builds Resources/AppIcon.icns.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
MASTER="$DIR/.build/icon-master.png"
ICONSET="$DIR/.build/AppIcon.iconset"

mkdir -p "$DIR/.build"
swift "$DIR/scripts/render-icon.swift" "$MASTER"

rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z "$s" "$s"           "$MASTER" --out "$ICONSET/icon_${s}x${s}.png"    >/dev/null
  sips -z "$((s*2))" "$((s*2))" "$MASTER" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$DIR/Resources/AppIcon.icns"
echo "Built $DIR/Resources/AppIcon.icns"
