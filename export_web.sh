#!/usr/bin/env bash
# Exports the Web build into build/web and zips it as build/farming-web.zip.
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT:-flatpak run org.godotengine.Godot}"

# Clear the old build but keep build/web/.git (the GitHub Pages repo lives there).
mkdir -p build/web && find build/web -mindepth 1 -not -path 'build/web/.git' -not -path 'build/web/.git/*' -delete
$GODOT --headless --path . --export-release "Web" "$PWD/build/web/index.html"
# Godot always writes its (now empty) boot splash next to the page; nothing references it.
rm -f build/web/index.png
cp static/fonts/Monocraft.ttf build/web/Monocraft.ttf   # loading page uses the in-game font
rm -f build/farming-web.zip
(cd build/web && zip -q -r ../farming-web.zip . -x '.git/*' '.git')
echo "Exported $(du -sh --exclude=.git build/web | cut -f1) to build/web, zipped as build/farming-web.zip"
