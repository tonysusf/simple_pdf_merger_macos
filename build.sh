#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
build_dir="${1:-build}"
app="$build_dir/Simple PDF Merger.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
sdk="$(xcrun --sdk macosx --show-sdk-path)"

for architecture in arm64 x86_64; do
    xcrun swiftc -O -sdk "$sdk" -target "$architecture-apple-macosx14.0" \
        -module-cache-path "$build_dir/ModuleCache" \
        Sources/*.swift -o "$build_dir/SimplePDFMerger-$architecture"
done

xcrun lipo -create "$build_dir"/SimplePDFMerger-{arm64,x86_64} \
    -output "$app/Contents/MacOS/SimplePDFMerger"
cp Info.plist "$app/Contents/Info.plist"
cp LICENSE Assets/AppIcon.icns "$app/Contents/Resources/"
codesign --force --sign - "$app"
printf 'Built %s\n' "$app"
