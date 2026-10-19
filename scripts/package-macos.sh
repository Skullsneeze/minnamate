#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="aarch64-apple-darwin"
VERSION="$(sed -n 's/^version = "\([^"]*\)"$/\1/p' "$ROOT/Cargo.toml" | head -n 1)"
OUT="${1:-$ROOT/dist}"
APP="$OUT/Minnamate.app"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This script must run on macOS (it uses sips and iconutil)." >&2
    exit 1
fi

mkdir -p "$OUT" "$APP/Contents/MacOS" "$APP/Contents/Resources"
cargo build --manifest-path "$ROOT/Cargo.toml" --release -p minnamate-editor --target "$TARGET"
cp "$ROOT/target/$TARGET/release/minnamate" "$APP/Contents/MacOS/minnamate"

ICONSET="$WORK/Minnamate.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$ROOT/assets/logo.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -s format png -z "$double" "$double" "$ROOT/assets/logo.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Minnamate.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>minnamate</string>
    <key>CFBundleIconFile</key><string>Minnamate</string>
    <key>CFBundleIdentifier</key><string>org.minnamate.editor</string>
    <key>CFBundleName</key><string>Minnamate</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>11.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

chmod +x "$APP/Contents/MacOS/minnamate"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/Minnamate-macos-aarch64.zip"
echo "Created $APP and $OUT/Minnamate-macos-aarch64.zip"
