#!/usr/bin/env bash
set -euo pipefail

configuration="${1:-debug}"
case "$configuration" in
  debug)
    swift_configuration="debug"
    ;;
  release)
    swift_configuration="release"
    ;;
  *)
    echo "usage: $0 [debug|release]" >&2
    exit 64
    ;;
esac

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

swift build -c "$swift_configuration" --product ClipCanvas
swift build -c "$swift_configuration" --product clipcanvas-mcp
bin_path="$(swift build -c "$swift_configuration" --show-bin-path)"
app_path="$repo_root/build/ClipCanvas.app"

rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$app_path/Contents/Helpers"
cp "$repo_root/Configuration/Info.plist" "$app_path/Contents/Info.plist"
cp "$bin_path/ClipCanvas" "$app_path/Contents/MacOS/ClipCanvas"
cp "$bin_path/clipcanvas-mcp" "$app_path/Contents/Helpers/clipcanvas-mcp"

iconset="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$iconset"
for spec in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"; do
  size="${spec%% *}"
  filename="${spec#* }"
  sips -z "$size" "$size" "$repo_root/Assets/AppIcon.png" \
    --out "$iconset/$filename" >/dev/null
done
iconutil -c icns "$iconset" -o "$app_path/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$iconset")"

resource_bundle="$bin_path/ClipCanvas_ClipCanvasApp.bundle"
if [[ -d "$resource_bundle" ]]; then
  cp -R "$resource_bundle" "$app_path/Contents/Resources/"
  for localization in "$resource_bundle"/*.lproj; do
    if [[ -d "$localization" ]]; then
      cp -R "$localization" "$app_path/Contents/Resources/"
    fi
  done
fi

codesign --force --deep --sign - "$app_path" >/dev/null
echo "$app_path"
