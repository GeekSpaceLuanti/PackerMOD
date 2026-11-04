#!/usr/bin/env bash
# Build the pinned engine once in the user's cache; never alter an installed game.
set -euo pipefail
for tool in cmake g++ curl tar busted xvfb-run xdotool import; do
    command -v "$tool" >/dev/null || { echo "Missing dependency: $tool. See docs/visual-tests.md." >&2; exit 1; }
done
version=5.16.1
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/packermod-tools"
mkdir -p "$cache_dir"
if [[ ! -d "$cache_dir/luanti-$version" ]]; then
    curl -fLsS "https://github.com/luanti-org/luanti/archive/refs/tags/$version.tar.gz" \
        -o "$cache_dir/luanti.tar.gz"
    tar -xzf "$cache_dir/luanti.tar.gz" -C "$cache_dir"
fi
cmake -S "$cache_dir/luanti-$version" -B "$cache_dir/build" \
    -DCMAKE_BUILD_TYPE=Release -DRUN_IN_PLACE=TRUE -DBUILD_SERVER=FALSE \
    -DBUILD_UNITTESTS=FALSE -DENABLE_SOUND=FALSE -DENABLE_GETTEXT=FALSE -DENABLE_LEVELDB=FALSE
cmake --build "$cache_dir/build" -j "${BUILD_JOBS:-4}"
echo "Engine ready: $cache_dir/luanti-$version/bin/luanti"
