#!/usr/bin/env bash
# Fetch a subset of Pixelarticons SVGs (MIT) into vendor/pixelarticons/svg/.
# Usage: scripts/vendor_pixelarticons.sh <name1> <name2> ...
set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "usage: $0 <icon_name> [<icon_name> ...]" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/vendor/pixelarticons"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 --filter=blob:none --sparse \
    https://github.com/halfmage/pixelarticons "$TMP/pa" >/dev/null

cd "$TMP/pa"
git sparse-checkout init --no-cone >/dev/null
SPARSE_PATHS=("/LICENSE")
for n in "$@"; do
    SPARSE_PATHS+=("/svg/${n}.svg")
done
git sparse-checkout set --no-cone "${SPARSE_PATHS[@]}" >/dev/null

# Verify all requested icons exist
missing=()
for n in "$@"; do
    [[ -f "svg/${n}.svg" ]] || missing+=("$n")
done
if [[ ${#missing[@]} -gt 0 ]]; then
    echo "error: missing icons in Pixelarticons: ${missing[*]}" >&2
    exit 2
fi

mkdir -p "$DEST/svg"
cp LICENSE "$DEST/LICENSE"
for n in "$@"; do
    cp "svg/${n}.svg" "$DEST/svg/${n}.svg"
done

echo "vendored: $* → $DEST/svg/"
