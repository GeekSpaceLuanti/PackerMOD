#!/usr/bin/env bash
# Usage: scripts/build_bgimg.sh [theme_name]
# Reads mainmenu/ui/themes/<theme>.bgimg.yml, emits SVG via bgimg_emit.lua,
# then rasterizes each SVG to textures/<name>.png with rsvg-convert.
# Mirrors the pipeline shape used by scripts/build_icons.sh.
set -euo pipefail

THEME="${1:-synthwave}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
YML="$REPO_ROOT/mainmenu/ui/themes/$THEME.bgimg.yml"
DST="$REPO_ROOT/textures"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [[ ! -f "$YML" ]]; then
    echo "build_bgimg: theme yaml not found: $YML" >&2
    exit 1
fi

(cd "$REPO_ROOT" && lua scripts/bgimg_emit.lua "$YML" "$TMP")

count=0
for svg in "$TMP"/*.svg; do
    name="$(basename "$svg" .svg)"
    rsvg-convert "$svg" -o "$DST/${name}.png"
    echo "  $DST/${name}.png"
    count=$((count + 1))
done
echo "build_bgimg: rasterized $count PNG(s) for theme '$THEME'"
