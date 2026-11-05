#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Capture the actual fork's player inventory with a disposable WSL/Xvfb client.
set -euo pipefail
if [[ "${PACKERBASE_XVFB:-}" != 1 ]]; then
    exec xvfb-run -a -s '-screen 0 1280x800x24 -nolisten tcp' env PACKERBASE_XVFB=1 bash "$0" "$@"
fi
repo="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-$repo/.screenshots/packerbase_inventory.png}"
runner="${LUANTI_BIN:-${XDG_CACHE_HOME:-$HOME/.cache}/packermod-tools/luanti-5.16.1/bin/luanti}"
run_dir="$(mktemp -d -t packerbase-visual.XXXXXX)"
pid=""
cleanup() {
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
    rm -rf -- "$run_dir"
}
trap cleanup EXIT
root="$(cd "$(dirname "$runner")/.." && pwd)"
mkdir -p "$run_dir/user/bin" "$run_dir/user/games" "$run_dir/world/worldmods/packer_visual" "$(dirname "$out")"
cp "$runner" "$run_dir/user/bin/luanti"
for asset in builtin client textures fonts locale settingtypes.txt; do
    [[ ! -e "$root/$asset" ]] || ln -s "$root/$asset" "$run_dir/user/$asset"
done
ln -s "$repo/games/packerbase" "$run_dir/user/games/packerbase"
printf 'gameid = packerbase\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nload_mod_packer_visual = true\n' > "$run_dir/world/world.mt"
printf 'name = packer_visual\ndepends = packer_core\n' > "$run_dir/world/worldmods/packer_visual/mod.conf"
cat > "$run_dir/world/worldmods/packer_visual/init.lua" <<'LUA'
core.register_on_joinplayer(function(player)
    core.after(1, function()
        assert(player:get_inventory():get_size("main") == 36)
        assert(player:hud_get_hotbar_itemcount() == 9)
        for i = 1, 36 do player:get_inventory():set_stack("main", i, "default:stone " .. i) end
        player:set_physics_override({gravity = 0})
        player:set_pos({x = 0, y = 5, z = 0})
        core.show_formspec(player:get_player_name(), "packer_visual:inventory", player:get_inventory_formspec())
        core.log("action", "PackerMOD Base visual inventory verified: 36 slots, hotbar 9")
    end)
end)
LUA
printf 'screen_w = 1280\nscreen_h = 800\nfullscreen = false\nenable_sound = false\nmg_name = singlenode\nmenu_clouds = false\n' > "$run_dir/config"
LUANTI_USER_PATH="$run_dir/user" LUANTI_GAME_PATH="$run_dir/user/games" \
    "$run_dir/user/bin/luanti" --go --world "$run_dir/world" --name PackerVisual \
    --config "$run_dir/config" --logfile "$run_dir/engine.log" > "$run_dir/console.log" 2>&1 &
pid=$!
window=""
for attempt in $(seq 1 120); do
    window="$(xdotool search --pid "$pid" --onlyvisible 2>/dev/null | head -1 || true)"
    if [[ -n "$window" ]] && grep -q 'PackerMOD Base visual inventory verified' "$run_dir/engine.log"; then break; fi
    kill -0 "$pid" 2>/dev/null || { cat "$run_dir/console.log"; exit 1; }
    sleep 0.25
done
grep -q 'PackerMOD Base visual inventory verified' "$run_dir/engine.log" || { cat "$run_dir/console.log"; exit 1; }
if grep -E 'ERROR\[|Could not open file of image|Invalid use' "$run_dir/engine.log"; then exit 1; fi
sleep 1
import -window "$window" "$out"
cp "$run_dir/engine.log" "$out.log"
echo "$out"
