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
bin_path="$(swift build -c "$swift_configuration" --show-bin-path)"
app_path="$repo_root/build/ClipCanvas.app"

rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$repo_root/Configuration/Info.plist" "$app_path/Contents/Info.plist"
cp "$bin_path/ClipCanvas" "$app_path/Contents/MacOS/ClipCanvas"

resource_bundle="$bin_path/ClipCanvas_ClipCanvasApp.bundle"
if [[ -d "$resource_bundle" ]]; then
  cp -R "$resource_bundle" "$app_path/Contents/Resources/"
fi

codesign --force --deep --sign - "$app_path" >/dev/null
echo "$app_path"
