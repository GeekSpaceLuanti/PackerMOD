#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Verify native selection and measure the 9-slot HUD in a disposable client.
set -euo pipefail
view="${1:-standard}"
case "$view" in
    standard) width=1280; height=800; density=1; max_width=1 ;;
    tall) width=1916; height=2041; density=1.5; max_width=1 ;;
    wrapped) width=720; height=560; density=1; max_width=0.55 ;;
    *) echo "Unknown hotbar view: $view" >&2; exit 2 ;;
esac
if [[ "${PACKER_HOTBAR_XVFB:-}" != 1 ]]; then
    exec xvfb-run -a -s "-screen 0 ${width}x${height}x24 -nolisten tcp" \
        env PACKER_HOTBAR_XVFB=1 bash "$0" "$@"
fi
repo="$(cd "$(dirname "$0")/.." && pwd)"
out="${2:-$repo/.screenshots/packerbase_hotbar_$view}"
runner="${LUANTI_BIN:-${XDG_CACHE_HOME:-$HOME/.cache}/packermod-tools/luanti-5.16.1/bin/luanti}"
run="$(mktemp -d -t packer-hotbar.XXXXXX)"
pid=""
cleanup() {
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
    rm -rf -- "$run"
}
trap cleanup EXIT
user="$run/user"
world="$run/world"
fixture="$world/worldmods/packer_hotbar_test"
mkdir -p "$user/bin" "$user/games" "$fixture" "$(dirname "$out")"
root="$(cd "$(dirname "$runner")/.." && pwd)"
if [[ -d "$root/builtin" ]]; then
    cp "$runner" "$user/bin/luanti"
    runner="$user/bin/luanti"
    for asset in builtin client textures fonts locale settingtypes.txt; do
        [[ ! -e "$root/$asset" ]] || ln -s "$root/$asset" "$user/$asset"
    done
fi
ln -s "$repo/games/packerbase" "$user/games/packerbase"
printf 'gameid = packerbase\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_packer_hotbar_test = true\n' > "$world/world.mt"
printf 'name = packer_hotbar_test\ndepends = packer_core\n' > "$fixture/mod.conf"
cat > "$fixture/init.lua" <<'LUA'
local player, previous
core.register_on_joinplayer(function(joined)
    core.after(1, function()
        assert(joined:hud_get_hotbar_itemcount() == 9)
        for i = 1, 9 do joined:get_inventory():set_stack("main", i, "default:stone " .. i) end
        joined:set_physics_override({gravity = 0})
        joined:set_pos(vector.new(0, 5, 0))
        joined:set_sky({type = "plain", base_color = "#506579", clouds = false})
        joined:set_sun({visible = false, sunrise_visible = false})
        joined:set_moon({visible = false})
        joined:set_stars({visible = false})
        joined:set_breath(7)
        local counts = {hotbar = 0, health = 0, breath = 0}
        for _, hud in pairs(joined:hud_get_all()) do
            if hud.type == "hotbar" then counts.hotbar = counts.hotbar + 1 end
            if hud.type == "statbar" and hud.text == "heart.png" then counts.health = counts.health + 1 end
            if hud.type == "statbar" and hud.text == "bubble.png" then counts.breath = counts.breath + 1 end
        end
        assert(counts.hotbar == 1 and counts.health == 1 and counts.breath == 1, "HUD element missing or duplicated")
        player = joined
    end)
end)
core.register_globalstep(function()
    if not player then return end
    if player:get_breath() ~= 7 then player:set_breath(7) end
    local index = player:get_wield_index()
    if index ~= previous then
        previous = index
        core.log("action", "PackerMOD hotbar selected " .. index)
    end
end)
LUA
cat > "$run/config" <<EOF
screen_w = $width
screen_h = $height
display_density_factor = $density
gui_scaling = 1.25
hud_hotbar_max_width = $max_width
enable_sound = false
enable_damage = true
mg_name = singlenode
static_spawnpoint = (0,1,0)
show_debug = false
EOF
log="$run/engine.log"
touch "$log"
LUANTI_USER_PATH="$user" LUANTI_GAME_PATH="$user/games" \
    "$runner" --go --world "$world" --name HotbarProbe --port "$((31000 + RANDOM % 28000))" \
    --config "$run/config" --logfile "$log" > "$run/output.log" 2>&1 &
pid=$!
wait_for() {
    for _ in $(seq 1 240); do
        if grep -q "$1" "$log"; then return; fi
        kill -0 "$pid" 2>/dev/null || break
        if grep -q 'ERROR\[' "$log"; then break; fi
        sleep 0.15
    done
    cat "$log" >&2
    echo "Missing engine marker: $1" >&2
    exit 1
}
wait_for 'PackerMOD hotbar selected 1'
window="$(xdotool search --pid "$pid" --onlyvisible | head -1)"
xdotool windowfocus --sync "$window"
for slot in 1 5 9; do
    xdotool key "$slot"
    wait_for "PackerMOD hotbar selected $slot"
    sleep 0.3
    import -window "$window" "$out-$slot.png"
done
xdotool key F1
sleep 0.3
import -window "$window" "$out-hidden.png"
python3 "$repo/scripts/test_base_game_hotbar.py" "$out" "$view"
