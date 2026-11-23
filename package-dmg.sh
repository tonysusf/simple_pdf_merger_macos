#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
app_name="Simple PDF Merger"
dmg="build/$app_name.dmg"
staging="$(mktemp -d "${TMPDIR:-/tmp}/simple-pdf-merger.XXXXXX")"
trap 'rm -rf -- "$staging"' EXIT

./build.sh "$staging/build"
mkdir "$staging/contents"
mv "$staging/build/$app_name.app" "$staging/contents/"
ln -s /Applications "$staging/contents/Applications"
hdiutil create -srcfolder "$staging/contents" -volname "$app_name" \
    -fs HFS+ -format UDZO "$staging/$app_name.dmg"
mkdir -p build
mv -f "$staging/$app_name.dmg" "$dmg"
printf 'Packaged %s\n' "$dmg"
