#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Capture the actual fork's player inventory with a disposable WSL/Xvfb client.
set -euo pipefail
width="${WIN_W:-1280}"
height="${WIN_H:-800}"
if [[ "${PACKERBASE_XVFB:-}" != 1 ]]; then
    exec xvfb-run -a -s "-screen 0 ${width}x${height}x24 -nolisten tcp" env PACKERBASE_XVFB=1 bash "$0" "$@"
fi
repo="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-$repo/.screenshots/packerbase_inventory.png}"
view="${2:-inventory}"
case "$view" in inventory|recipes|settings) ;; *) echo "Unknown view: $view" >&2; exit 2 ;; esac
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
printf 'gameid = packerbase\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_packer_visual = true\n' > "$run_dir/world/world.mt"
printf 'name = packer_visual\ndepends = packer_ui\n' > "$run_dir/world/worldmods/packer_visual/mod.conf"
cat > "$run_dir/world/worldmods/packer_visual/init.lua" <<'LUA'
core.register_on_joinplayer(function(player)
    core.after(1, function()
        assert(player:get_inventory():get_size("main") == 36)
        assert(player:hud_get_hotbar_itemcount() == 9)
        for i = 1, 36 do player:get_inventory():set_stack("main", i, "default:stone " .. i) end
        player:set_physics_override({gravity = 0})
        player:set_pos({x = 0, y = 5, z = 0})
        local view = core.settings:get("packer_visual_view")
        if view ~= "inventory" then
            local recipes = "mtg_craftguide:craftguide"
            local settings = "packer_ui:settings"
            local context = sfinv.get_or_create_context(player)
            sfinv.set_page(player, recipes)
            local page = sfinv.pages[recipes]
            page:on_player_receive_fields(player, context, {search = true, filter = "default:torch"})
            local fs = player:get_inventory_formspec()
            assert(fs:find("formspec_version[6]", 1, true))
            assert(fs:find(";default:torch;packer_item_1;", 1, true))
            page:on_player_receive_fields(player, context, {packer_item_1 = true})
            assert(player:get_inventory_formspec():find(";default:torch 4;", 1, true))
            page:on_player_receive_fields(player, context, {packer_recipe_mode = true})
            page:on_player_receive_fields(player, context, {packer_recipe_mode = true})
            assert(player:get_inventory_formspec():find(";default:torch 4;", 1, true))
            page:on_player_receive_fields(player, context, {search = true, filter = ""})
            assert(player:get_inventory_formspec():find(";packer_item_32;", 1, true))
            if view == "settings" then
                local index = assert(table.indexof(context.nav, settings))
                assert(index > 0)
                page:on_player_receive_fields(player, context, {["packer_page_" .. index] = true})
                assert(sfinv.get_page(player) == settings)
                local settings_page = sfinv.pages[settings]
                settings_page:on_player_receive_fields(player, context, {packer_color_contrast = true})
                assert(player:get_meta():get_int("packer_ui:high_contrast") == 1)
                settings_page:on_player_receive_fields(player, context, {packer_color_normal = true})
                assert(player:get_meta():get_int("packer_ui:high_contrast") == 0)
            end
        end
        core.log("action", "PackerMOD Base visual inventory verified: 36 slots, hotbar 9")
    end)
end)
LUA
printf 'screen_w = %s\nscreen_h = %s\npacker_visual_view = %s\nkeymap_inventory = KEY_KEY_E\nlanguage = ja\nfullscreen = false\nenable_sound = false\nmg_name = singlenode\nmenu_clouds = false\n' \
    "$width" "$height" "$view" > "$run_dir/config"
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
xdotool windowfocus "$window" key e
xdotool mousemove --window "$window" 8 48
sleep 1
import -window "$window" "$out"
cp "$run_dir/engine.log" "$out.log"
if grep -E 'ERROR\[|Could not open file of image|Invalid use' "$out.log"; then exit 1; fi
echo "$out"
