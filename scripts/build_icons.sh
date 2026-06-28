#!/usr/bin/env bash
# Rasterize vendor/pixelarticons/svg/*.svg → textures/packermod_icon_<name>_<size>.png
# Recolors paths to white (Pixelarticons uses currentColor) for dark theme contrast.
# Usage: scripts/build_icons.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/vendor/pixelarticons/svg"
DST="$REPO_ROOT/textures"

if [[ ! -d "$SRC" ]]; then
    echo "error: $SRC not found; run scripts/vendor_pixelarticons.sh first" >&2
    exit 1
fi

mkdir -p "$DST"

STYLE="$(mktemp --suffix=.css)"
trap 'rm -f "$STYLE"' EXIT
cat >"$STYLE" <<'CSS'
path { fill: #FFFFFF; stroke: #FFFFFF; }
CSS

shopt -s nullglob
count=0
for svg in "$SRC"/*.svg; do
    name="$(basename "$svg" .svg)"
    for entry in sm:24 md:48 lg:72; do
        label="${entry%:*}"
        px="${entry#*:}"
        out="$DST/packermod_icon_${name}_${label}.png"
        rsvg-convert --stylesheet="$STYLE" -w "$px" -h "$px" "$svg" -o "$out"
        count=$((count + 1))
    done
done

echo "rasterized $count PNGs into $DST/"
