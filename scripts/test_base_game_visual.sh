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
case "$view" in inventory|recipes|settings|interaction|legacy|creative) ;; *) echo "Unknown view: $view" >&2; exit 2 ;; esac
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
local function interaction(player)
    local inv = player:get_inventory()
    inv:set_stack("main", 1, "default:tree")
    local window = assert(core.get_player_window_information(player:get_player_name()))
    local pixels = math.min(window.size.x / window.max_formspec_size.x,
        window.size.y / window.max_formspec_size.y)
    local function target(stage, fs, x, y, w, h)
        local fw, fh = fs:match("size%[([%d.]+),([%d.]+)%]")
        x = (window.size.x - fw * pixels) / 2 + (x + w / 2) * pixels
        y = (window.size.y - fh * pixels) / 2 + (y + h / 2) * pixels
        core.log("action", ("PackerMOD click %s %d %d"):format(stage, x, y))
    end
    local stage = "open"
    local fs = player:get_inventory_formspec()
    target("book", fs, fs:match("button%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);packer_book_toggle;"))
    local function check()
        local current = player:get_inventory_formspec()
        if stage == "open" and current:find("field_close_on_enter[filter;false]", 1, true) then
            target("item", current, current:match(
                "item_image_button%[([%d.]+),([%d.]+);([%d.]+),([%d.]+);[^;]+;packer_item_1;"))
            stage = "selected"
        elseif stage == "selected" and current:find("packer_recipe_mode", 1, true) then
            local x, y = current:match("list%[current_player;main;([%d.]+),([%d.]+);9,1;0%]")
            local slot = current:match("style_type%[list;size=([%d.]+),")
            target("inventory", current, x, y, slot, slot)
            stage = "craft"
        elseif stage == "craft" and inv:get_stack("craft", 1):get_name() == "default:tree" then
            assert(inv:get_stack("main", 1):is_empty())
            core.log("action", "PackerMOD mouse recipe and shift-click craft verified")
            return
        end
        core.after(0.1, check)
    end
    core.after(0.1, check)
end

core.register_on_joinplayer(function(player)
    core.after(1, function()
        local view = core.settings:get("packer_visual_view")
        if view == "legacy" then
            local context = sfinv.get_or_create_context(player)
            assert(table.indexof(context.nav, "mtg_craftguide:craftguide") > 0)
            assert(not player:get_inventory_formspec():find("packer_book_toggle", 1, true))
            sfinv.set_page(player, "mtg_craftguide:craftguide")
            assert(player:get_inventory_formspec():find("field[0.3,4.2;", 1, true))
            core.log("action", "PackerMOD Base visual inventory verified: legacy recipe and crafting pages")
            return
        end
        assert(player:get_inventory():get_size("main") == 36)
        assert(player:hud_get_hotbar_itemcount() == 9)
        for i = 1, 36 do player:get_inventory():set_stack("main", i, "default:stone " .. i) end
        player:set_physics_override({gravity = 0})
        player:set_pos({x = 0, y = 5, z = 0})
        local crafting = "sfinv:crafting"
        local recipes = "mtg_craftguide:craftguide"
        local settings = "packer_ui:settings"
        local context = sfinv.get_or_create_context(player)
        local page = sfinv.pages[crafting]
        sfinv.set_page(player, crafting)
        local fs = player:get_inventory_formspec()
        assert(fs:find("packer_book_toggle", 1, true))
        assert(fs:find("list[current_player;craft;", 1, true))
        assert(fs:find("list[current_player;craftpreview;", 1, true))
        assert(fs:find("listring[current_player;main]listring[current_player;craft]", 1, true))
        assert(not fs:find("field_close_on_enter[filter;false]", 1, true))
        if view == "interaction" then
            interaction(player)
        elseif view == "creative" then
            local index = table.indexof(context.nav, "creative:all")
            assert(index > 0)
            page:on_player_receive_fields(player, context, {["packer_page_" .. index] = true})
            assert(sfinv.get_page(player) == "creative:all")
            assert(player:get_inventory_formspec():find("list[detached:creative_", 1, true))
            assert(table.indexof(context.nav, crafting) > 0)
            sfinv.set_page(player, crafting)
            assert(player:get_inventory_formspec():find("packer_book_toggle", 1, true))
        elseif view ~= "inventory" then
            assert(table.indexof(context.nav, recipes) == -1)
            sfinv.set_page(player, recipes)
            assert(player:get_inventory_formspec():find("field_close_on_enter[filter;false]", 1, true))
            sfinv.pages[recipes]:on_player_receive_fields(player, context, {packer_book_toggle = true})
            assert(sfinv.get_page(player) == crafting)
            page:on_player_receive_fields(player, context, {packer_book_toggle = true})
            assert(sfinv.get_page(player) == crafting)
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
            assert(player:get_inventory_formspec():find(";packer_item_21;", 1, true))
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
printf 'gui_scaling = %s\n' "${PACKERBASE_GUI_SCALING:-1}" >> "$run_dir/config"
[[ "$view" != legacy ]] || printf 'packer_java_inventory = false\n' >> "$run_dir/config"
[[ "$view" != creative ]] || printf 'creative_mode = true\n' >> "$run_dir/config"
LUANTI_USER_PATH="$run_dir/user" LUANTI_GAME_PATH="$run_dir/user/games" \
    "$run_dir/user/bin/luanti" --go --world "$run_dir/world" --name PackerVisual --port "$((31000 + RANDOM % 28000))" \
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
if [[ "$view" == interaction ]]; then
    sleep 1
    for stage in book item inventory; do
        for attempt in $(seq 1 60); do
            coords="$(grep "PackerMOD click $stage " "$run_dir/engine.log" | tail -1 | sed "s/.*PackerMOD click $stage //" || true)"
            [[ -n "$coords" ]] && break
            sleep 0.1
        done
        [[ -n "$coords" ]] || { import -window "$window" "$out"; cat "$run_dir/engine.log"; exit 1; }
        read -r x y <<< "$coords"
        xdotool mousemove --window "$window" "$x" "$y"
        if [[ "$stage" == inventory ]]; then
            xdotool keydown Shift_L click 1 keyup Shift_L
        else
            xdotool click 1
        fi
        sleep 0.3
    done
    for attempt in $(seq 1 60); do
        grep -q 'PackerMOD mouse recipe and shift-click craft verified' "$run_dir/engine.log" && break
        sleep 0.1
    done
    grep -q 'PackerMOD mouse recipe and shift-click craft verified' "$run_dir/engine.log" || { cat "$run_dir/engine.log"; exit 1; }
fi
xdotool mousemove --window "$window" 8 48
sleep 1
import -window "$window" "$out"
cp "$run_dir/engine.log" "$out.log"
if grep -E 'ERROR\[|Could not open file of image|Invalid use' "$out.log"; then exit 1; fi
echo "$out"
