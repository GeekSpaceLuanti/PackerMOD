#!/usr/bin/env bash
# Deterministic engine screenshots under Xvfb, using disposable user data only.
# Usage: LUANTI_BIN=/path/to/luanti bash scripts/screenshot_mainmenu.sh [view] [png]
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
view="${1:-library}"
out="${2:-$repo_root/.screenshots/$view.png}"
width="${WIN_W:-1280}"
height="${WIN_H:-800}"
if [[ "${PACKERMOD_XVFB:-}" != 1 ]]; then
    exec xvfb-run -a -s "-screen 0 ${width}x${height}x24 -nolisten tcp" \
        env PACKERMOD_XVFB=1 bash "$0" "$view" "$out"
fi
runner="${LUANTI_BIN:-luanti}"
if ! command -v "$runner" >/dev/null && [[ -z "${LUANTI_BIN:-}" ]]; then
    runner="${XDG_CACHE_HOME:-$HOME/.cache}/packermod-tools/luanti-5.16.1/bin/luanti"
fi
command -v "$runner" >/dev/null || { echo "Luanti not found: set LUANTI_BIN" >&2; exit 1; }
count=3
page=1
subtab=""
modal=""
step=details
language=ja
native_settings=false
engine_setting=""
settings_tab=general
settings_group=""
gui_scale=1
button_scale=1
gui_size=standard
font_size=18
show_expert=false
show_developer=false
main_script="$repo_root/mainmenu/init.lua"
ready_marker="PackerMOD: menu ready"
case "$view" in
    operations_test) main_script="$repo_root/scripts/operations_smoke_mainmenu.lua"; ready_marker="PackerMOD: operation matrix verified" ;;
    library) ;;
    contentdb_live) main_script="$repo_root/scripts/contentdb_smoke_mainmenu.lua"; ready_marker="PackerMOD: live ContentDB verified" ;;
    contentdb_catalog) main_script="$repo_root/scripts/contentdb_catalog_mainmenu.lua"; ready_marker="PackerMOD: ContentDB catalog ready" ;;
    mods_search|modal_create_mods_search)
        main_script="$repo_root/scripts/mod_catalog_smoke_mainmenu.lua"
        ready_marker="PackerMOD: live MOD thumbnail verified"
        if [[ "$view" == mods_search ]]; then subtab=mods; else step=mods; fi ;;
    library_esc_test) subtab=worlds; main_script="$repo_root/scripts/menu_esc_smoke_mainmenu.lua" ;;
    library_empty) count=0 ;;
    library_many) count=7 ;;
    library_page2) count=7; page=2 ;;
    worlds|multi|mods|info) subtab="$view" ;;
    worlds_empty) subtab=worlds ;;
    modal_world_create|modal_world_delete) subtab=worlds; modal="${view#modal_}" ;;
    gui_controls_test|settings_interaction|settings_scale_interaction) view=gui_controls_test; main_script="$repo_root/scripts/gui_probe_mainmenu.lua"; modal=settings; settings_tab=audio ;;
    info_scroll_end) subtab=info ;;
    detail_resize) subtab=worlds ;;
    modal_pack_delete) subtab=worlds; modal=pack_delete ;;
    pack_delete_test) main_script="$repo_root/scripts/gui_probe_mainmenu.lua"; subtab=info; modal=pack_delete ;;
    modal_create_mods) modal=create; step=mods ;;
    modal_create_game) modal=create; step=game ;;
    native_settings) native_settings=true ;;
    settings_ui_test) main_script="$repo_root/scripts/settings_ui_smoke_mainmenu.lua"; ready_marker="PackerMOD: settings UI verified" ;;
    modal_create_scale_large) modal=create; gui_size=large; gui_scale=1.5; button_scale=1.5; font_size=24 ;;
    worlds_scale_large) subtab=worlds; gui_size=large; gui_scale=1.5; button_scale=1.5; font_size=24 ;;
    settings_resize) modal=settings; gui_size=large; gui_scale=1.5; button_scale=1.5; font_size=24 ;;
    settings_size_dropdown|settings_scale_dropdown) main_script="$repo_root/scripts/gui_probe_mainmenu.lua"; modal=settings; gui_size=large; gui_scale=1.5; button_scale=1.5; font_size=24 ;;
    settings_scale_large) modal=settings; gui_size=large; gui_scale=1.5; button_scale=1.5; font_size=24 ;;
    library_scale_large) count=7; gui_size=large; gui_scale=1.5; button_scale=1.5; font_size=24 ;;
    settings_keymap) modal=settings; settings_tab=keymap ;;
    settings_keymap_end) modal=settings; settings_tab=keymap; settings_group=Hotbar ;;
    settings_expert) modal=settings; settings_tab=graphics; show_expert=true ;;
    settings_controls) modal=settings; settings_tab=controls ;;
    settings_graphics) modal=settings; settings_tab=graphics ;;
    settings_audio) modal=settings; settings_tab=audio ;;
    settings_interface) modal=settings; settings_tab=interface ;;
    settings_world) modal=settings; settings_tab=world ;;
    settings_advanced) modal=settings; settings_tab=advanced; show_developer=true ;;
    world_settings_test) main_script="$repo_root/scripts/world_settings_smoke_mainmenu.lua"; ready_marker="PackerMOD: world isolation verified" ;;
    world_settings|world_physics|world_terrain|world_hosting) main_script="$repo_root/scripts/world_settings_preview_mainmenu.lua"; settings_tab="${view#world_}" ;;
    settings_movement) modal=settings; settings_tab=keymap; settings_group=Movement ;;
    settings_actions) modal=settings; settings_tab=keymap; settings_group=Actions ;;
    settings_hotbar) modal=settings; settings_tab=keymap; settings_group=Hotbar ;;
    engine_settings_test) main_script="$repo_root/scripts/engine_settings_smoke_mainmenu.lua"; ready_marker="PackerMOD: engine settings verified" ;;
    engine_settings_bool) modal=settings; engine_setting=autojump ;;
    engine_settings_enum) modal=settings; engine_setting=video_driver ;;
    engine_settings_keys) modal=settings; engine_setting=keymap_forward ;;
    engine_settings_noise|engine_settings_noise_end) main_script="$repo_root/scripts/world_settings_preview_mainmenu.lua"; engine_setting=mg_biome_np_heat ;;
    engine_settings_vector) main_script="$repo_root/scripts/world_settings_preview_mainmenu.lua"; engine_setting=mgfractal_scale ;;
    engine_settings_flags) main_script="$repo_root/scripts/world_settings_preview_mainmenu.lua"; engine_setting=mg_flags ;;
    engine_settings_path) modal=settings; engine_setting=screenshot_path ;;
    library_en) language=en ;;
    modal_settings_en) modal=settings; language=en ;;
    modal_import|modal_create|modal_settings) modal="${view#modal_}" ;;
    *) echo "Unknown view: $view" >&2; exit 2 ;;
esac
run_dir="$(mktemp -d -t packermod-screenshot.XXXXXX)"
engine_pid=""
cleanup() {
    if [[ -n "$engine_pid" ]]; then
        kill "$engine_pid" 2>/dev/null || true
        wait "$engine_pid" 2>/dev/null || true
    fi
    rm -rf -- "$run_dir"
}
trap cleanup EXIT
user_dir="$run_dir/user"
mkdir -p "$user_dir/PackerMOD/packs" "$user_dir/games/packerbase_0_91/mods" "$(dirname "$out")"
# Portable builds ignore LUANTI_USER_PATH. Give their executable a disposable
# physical location (a symlink would resolve back to the original user folder).
runner="$(command -v "$runner")"
runner_root="$(cd "$(dirname "$runner")/.." && pwd)"
if [[ -d "$runner_root/builtin" ]]; then
    mkdir -p "$user_dir/bin"
    cp "$runner" "$user_dir/bin/luanti"
    for asset in builtin client textures fonts locale settingtypes.txt; do
        [[ ! -e "$runner_root/$asset" ]] || ln -s "$runner_root/$asset" "$user_dir/$asset"
    done
    runner="$user_dir/bin/luanti"
fi

printf 'title = Screenshot Base\n' > "$user_dir/games/packerbase_0_91/game.conf"
for ((i=1; i<=count; i++)); do
    pack="$user_dir/PackerMOD/packs/sample_$i"
    mkdir -p "$pack/worlds/demo"
    cat > "$pack/manifest.yaml" <<YAML
schema_version: 1
id: sample_$i
name: Sample Pack $i
version: "1.0.0"
base_game:
  id: packerbase
  version: "0.91"
YAML
    printf 'gameid = packerbase_0_91\nworld_name = Demo world\n' > "$pack/worlds/demo/world.mt"
done
if [[ "$view" == worlds_empty || "$view" == detail_resize ]]; then
    rm -f "$user_dir/PackerMOD/packs/sample_1/worlds/demo/world.mt"
fi
cat > "$run_dir/minetest.conf" <<CONF
main_menu_script = $main_script
packermod_source_path = $repo_root
packermod_smoke_config = $run_dir/minetest.conf
packermod_gui_probe = $run_dir/probe.tsv
packermod_initial_engine_setting = $engine_setting
packermod_initial_settings_tab = $settings_tab
packermod_initial_settings_group = $settings_group
screen_w = $width
screen_h = $height
fullscreen = false
enable_sound = false
menu_clouds = false
show_debug = false
font_size = $font_size
packermod_gui_size = $gui_size
gui_scaling = $gui_scale
packermod_button_scale = $button_scale
packermod_initial_show_expert = $show_expert
packermod_initial_show_developer = $show_developer
packermod_language = $language
language = $language
packermod_initial_native_settings = $native_settings
packermod_expected_pack_count = $count
packermod_initial_subtab = $subtab
packermod_initial_modal = $modal
packermod_initial_page = $page
packermod_initial_create_step = $step
CONF
if [[ "$view" == operations_test ]]; then
    python3 - "$user_dir" <<'PY'
import sys, zipfile
from pathlib import Path
root = Path(sys.argv[1])
for name, prefix in [("nested.zip", "matrixmod-main/"), ("flat.zip", "")]:
    with zipfile.ZipFile(root / name, "w") as z:
        if prefix:
            z.writestr(prefix, "")
        z.writestr(prefix + "mod.conf", "name = matrixmod\n")
        z.writestr(prefix + "init.lua", "core.matrix_mod_loaded = true\n")
with zipfile.ZipFile(root / "import.zip", "w") as z:
    z.writestr("manifest.yaml", "schema_version: 1\nid: zip_import\nname: ZIP import\nversion: '1'\nbase_game:\n  id: matrix\n  installed_id: matrix\n  version: installed\n")
    z.writestr("thumbnail.png", "fixture")
PY
fi
LUANTI_USER_PATH="$user_dir" LIBGL_ALWAYS_SOFTWARE=1 "$runner" \
    --config "$run_dir/minetest.conf" --logfile "$run_dir/engine.log" \
    > "$run_dir/console.log" 2>&1 &
engine_pid=$!
window=""
max_wait=600
[[ "$view" != operations_test ]] || max_wait=6000
for ((i=0; i<max_wait; i++)); do
    kill -0 "$engine_pid" 2>/dev/null || { cat "$run_dir/console.log" >&2; exit 1; }
    window="$(xdotool search --onlyvisible --pid "$engine_pid" 2>/dev/null | head -1 || true)"
    if grep -q 'ERROR\[' "$run_dir/console.log"; then cat "$run_dir/console.log" >&2; exit 1; fi
    if [[ -n "$window" ]] && grep -q "$ready_marker" "$run_dir/engine.log"; then break; fi
    sleep 0.1
done
[[ -n "$window" ]] && grep -q "$ready_marker" "$run_dir/engine.log" || { echo "Luanti menu did not become ready" >&2; cat "$run_dir/console.log" >&2; exit 1; }
sleep 0.5
point() { awk -F '\t' -v name="$1" '$1==name {print $2,$3,$4,$5;exit}' "$run_dir/probe.tsv"; }
click_control() { read -r px py pw ph < <(point "$1"); xdotool mousemove --window "$window" "$px" "$py" click 1; sleep 0.3; }
if [[ "$view" == detail_resize ]]; then
    xdotool windowsize --sync "$window" 800 600
    sleep 0.5
fi
if [[ "$view" == gui_controls_test ]]; then
    read -r px py pw ph < <(point settings_row_1)
    xdotool mousemove --window "$window" "$((px-pw/4))" "$py" mousedown 1
    for delta in 0 4 8 12 16; do xdotool mousemove --sync --window "$window" "$((px+pw/4+delta))" "$py"; sleep 0.02; done
    xdotool mouseup 1
    sleep 0.7
    awk -F ' = ' '$1=="sound_volume" {found=1; if ($2 < 0.6) exit 1} END {if(!found)exit 1}' "$run_dir/minetest.conf"
    click_control settings_row_3
    grep -q '^mute_sound = true' "$run_dir/minetest.conf"
    click_control settings_tab_keymap
    click_control settings_row_1
    xdotool key Up
    sleep 0.3
    if ! grep -Eq '^keymap_forward = (KEY_UP|SYSTEM_SCANCODE_82)$' "$run_dir/minetest.conf"; then
        import -window "$window" "$out.key.png"
        cp "$run_dir/minetest.conf" "$out.key.conf"
        cp "$run_dir/probe.tsv" "$out.key.tsv"
        cp "$run_dir/engine.log" "$out.log"
        echo 'Native key capture failed' >&2;exit 1
    fi
    click_control settings_reset_1
    if grep -q '^keymap_forward =' "$run_dir/minetest.conf"; then echo 'Key reset failed' >&2;exit 1;fi
    click_control settings_tab_general
    click_control settings_row_1
    xdotool key Down Return
    sleep 0.3
    grep -q '^packermod_language = en' "$run_dir/minetest.conf"
    if [[ -z "$(point dlg_close)" && -n "$(point pm_flow_scroll)" ]]; then
        read -r px py pw ph < <(point pm_flow_scroll)
        xdotool mousemove --window "$window" "$px" "$py" mousedown 1
        xdotool mousemove --sync --window "$window" "$px" "$((py+ph/2-20))"
        xdotool mouseup 1;sleep 0.3
    fi
    click_control dlg_close
    [[ -n "$(point btn_settings)" ]] || { echo 'Done did not return to the library' >&2;exit 1; }
    echo 'Verified automatic-layout drag, toggle, navigation, key capture, reset, language dropdown and Done.'
fi
if grep -E 'ERROR\[|Mod security' "$run_dir/console.log" "$run_dir/engine.log"; then
    cp "$run_dir/console.log" "$out.log"
    exit 1
fi
if [[ "$view" == settings_resize ]]; then
    xdotool windowsize --sync "$window" 800 600
    sleep 0.5
    gui="$(sed -n 's/^gui_scaling = //p' "$run_dir/minetest.conf")"
    font="$(sed -n 's/^font_size = //p' "$run_dir/minetest.conf")"
    awk -v gui="$gui" -v font="$font" 'BEGIN { exit !(gui <= 1 && font <= 20) }' || { echo "Resize safety failed: GUI=$gui font=$font" >&2; exit 1; }
    echo "Verified automatic safe scaling after a live window resize to 800x600."
fi
if [[ "$view" == settings_size_dropdown || "$view" == settings_scale_dropdown ]]; then
    if [[ "$view" == settings_size_dropdown ]]; then click_control settings_row_2
    else click_control settings_row_1; fi
fi
if [[ "$view" == info_scroll_end ]]; then
    xdotool mousemove --window "$window" "$((width / 2))" "$((height / 2))" click --repeat 90 --delay 10 5
    sleep 0.4
fi
if [[ "$view" == settings_keymap_end ]]; then
    xdotool mousemove --window "$window" "$((width * 3 / 4))" "$((height / 2))" click --repeat 220 --delay 5 5
    sleep 0.3
fi
if [[ "$view" == engine_settings_noise_end ]]; then
    xdotool mousemove --window "$window" "$((width * 3 / 4))" "$((height / 2))" click --repeat 20 --delay 20 5
    sleep 0.3
fi
if [[ "$view" == pack_delete_test ]]; then
    [[ "$width" == 1280 && "$height" == 800 ]] || { echo "Pack deletion fixture requires 1280x800" >&2; exit 1; }
    # Cancel first, then reopen through the real detail button and confirm.
    click_control dlg_close
    [[ -f "$user_dir/PackerMOD/packs/sample_1/worlds/demo/world.mt" ]] || { echo "Cancel deleted data" >&2; exit 1; }
    if [[ -n "$(point pm_flow_scroll)" ]]; then
        read -r px py pw ph < <(point pm_flow_scroll)
        xdotool mousemove --window "$window" "$px" "$py" mousedown 1
        xdotool mousemove --sync --window "$window" "$px" "$((py+ph/2-20))"
        xdotool mouseup 1;sleep 0.3
    fi
    click_control delete_pack
    click_control confirm_delete
    [[ ! -e "$user_dir/PackerMOD/packs/sample_1" ]] || { echo "Pack deletion failed" >&2; exit 1; }
    [[ -f "$user_dir/PackerMOD/packs/sample_2/worlds/demo/world.mt" && -f "$user_dir/PackerMOD/packs/sample_3/manifest.yaml" ]] || { echo "Other pack data changed" >&2; exit 1; }
    echo "Verified cancellation, confirmed pack/world deletion and preservation of other packs."
fi
# Capture only the engine window. No foreground focus, desktop input or F12 needed.
if [[ "$view" == library_esc_test ]]; then
    xdotool windowfocus "$window" key Escape
    for _ in {1..30}; do
        grep -q 'PackerMOD: ESC returned to Library' "$run_dir/engine.log" && break
        sleep 0.1
    done
    grep -q 'PackerMOD: ESC returned to Library' "$run_dir/engine.log"
    import -window "$window" "$out"
    xdotool key Escape
    for _ in {1..30}; do
        kill -0 "$engine_pid" 2>/dev/null || break
        sleep 0.1
    done
    if kill -0 "$engine_pid" 2>/dev/null; then echo 'ESC did not close Luanti' >&2; exit 1; fi
    wait "$engine_pid"
    engine_pid=""
    cp "$run_dir/engine.log" "$out.log"
    grep -q 'PackerMOD: ESC closed Library' "$out.log"
    if grep -E 'ERROR\[|no toplevel ui element' "$out.log"; then exit 1; fi
    printf '%s\n' "$out"
    exit 0
fi
if grep -E 'ERROR\[|Could not open file of image|Invalid use|invalid use' "$run_dir/engine.log"; then cp "$run_dir/engine.log" "$out.log";exit 1;fi
import -window "$window" "$out"
cp "$run_dir/engine.log" "$out.log"
printf '%s\n' "$out"
