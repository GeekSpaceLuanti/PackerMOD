#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Disposable headless integration test; no installed worlds are touched.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
game="$repo/games/packerbase"
lua "$game/tests/api.lua" "$game"
runner="${LUANTI_BIN:-${XDG_CACHE_HOME:-$HOME/.cache}/packermod-tools/luanti-5.16.1/bin/luanti}"
[[ -x "$runner" ]] || { echo 'Set LUANTI_BIN to a Luanti binary' >&2; exit 1; }
run_dir="$(mktemp -d -t packerbase-test.XXXXXX)"
trap 'rm -rf -- "$run_dir"' EXIT
runner_root="$(cd "$(dirname "$runner")/.." && pwd)"
mkdir -p "$run_dir/user/bin" "$run_dir/user/games" "$run_dir/world/worldmods/packer_smoke"
if [[ -d "$runner_root/builtin" ]]; then
    cp "$runner" "$run_dir/user/bin/luanti"
    for asset in builtin client textures fonts locale settingtypes.txt; do
        [[ ! -e "$runner_root/$asset" ]] || ln -s "$runner_root/$asset" "$run_dir/user/$asset"
    done
    runner="$run_dir/user/bin/luanti"
fi
ln -s "$game" "$run_dir/user/games/packerbase"
cp "$game/tests/smoke/init.lua" "$run_dir/world/worldmods/packer_smoke/init.lua"
cp -R "$repo/examples/packerbase/bundled_mods/packerbase_example" "$run_dir/world/worldmods/"
printf 'name = packer_smoke\ndepends = packer_core, default\n' > "$run_dir/world/worldmods/packer_smoke/mod.conf"
printf 'gameid = packerbase\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_packer_smoke = true\nload_mod_packerbase_example = true\n' > "$run_dir/world/world.mt"
for pass in 1 2; do
    printf 'port = 0\nserver_announce = false\nmg_name = singlenode\npacker_smoke_expected = %s\n' "$pass" > "$run_dir/config"
    LUANTI_USER_PATH="$run_dir/user" LUANTI_GAME_PATH="$run_dir/user/games" \
        timeout 45 "$runner" --server --world "$run_dir/world" --config "$run_dir/config" \
        --logfile "$run_dir/pass-$pass.log" > "$run_dir/output-$pass.log" 2>&1 || {
        cat "$run_dir/output-$pass.log"; exit 1;
    }
    grep -q "PackerMOD Base smoke pass $pass" "$run_dir/pass-$pass.log"
    grep -q "PackerMOD Base example: world start $pass" "$run_dir/pass-$pass.log"
    if grep -q 'ERROR\[' "$run_dir/pass-$pass.log"; then cat "$run_dir/pass-$pass.log"; exit 1; fi
done
echo 'PackerMOD Base headless startup, map/metadata/ModStorage save and restart passed'
