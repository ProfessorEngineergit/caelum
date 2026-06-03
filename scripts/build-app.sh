#!/bin/bash
# Builds Caelum.app — compiles via SwiftPM and assembles a menu-bar app bundle.
# Usage: scripts/build-app.sh [debug|release] [--universal]
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

CONFIG="${1:-release}"
UNIVERSAL="${2:-}"

# Ensure the icon exists.
[ -f "$DIR/Resources/AppIcon.icns" ] || bash "$DIR/scripts/make-icon.sh"

echo "▸ Building Caelum ($CONFIG)…"
if [ "$UNIVERSAL" = "--universal" ]; then
  swift build -c "$CONFIG" --arch arm64 --arch x86_64
  BIN="$DIR/.build/apple/Products/$( [ "$CONFIG" = release ] && echo Release || echo Debug )/Caelum"
  [ -f "$BIN" ] || BIN="$(swift build -c "$CONFIG" --arch arm64 --arch x86_64 --show-bin-path)/Caelum"
else
  swift build -c "$CONFIG"
  BIN="$(swift build -c "$CONFIG" --show-bin-path)/Caelum"
fi

APP="$DIR/dist/Caelum.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/Caelum"
cp "$DIR/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$DIR/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc sign (no Developer ID required; users right-click → Open on first launch).
codesign --force --deep --options runtime --sign - "$APP" >/dev/null 2>&1 \
  && echo "▸ Ad-hoc signed." || echo "▸ codesign unavailable — bundle left unsigned."

echo "✓ Built $APP"
