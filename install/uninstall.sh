#!/usr/bin/env bash
set -euo pipefail

case "$(uname -s)" in
    Linux)   user_data="$HOME/.minetest" ;;
    Darwin)  user_data="$HOME/Library/Application Support/luanti" ;;
    *)       echo "Unsupported OS." >&2; exit 2 ;;
esac

conf="$user_data/minetest.conf"
target_mainmenu="$user_data/PackerMOD/mainmenu"
target_pm_textures="$user_data/PackerMOD/textures"

if [[ -e "$target_mainmenu" || -L "$target_mainmenu" ]]; then
    rm -rf "$target_mainmenu"
    echo "Removed $target_mainmenu"
fi

if [[ -e "$target_pm_textures" || -L "$target_pm_textures" ]]; then
    rm -rf "$target_pm_textures"
    echo "Removed $target_pm_textures"
fi

# 過去の install スクリプトが <user>/textures/packermod_*.png に置いていたものを掃除
if [[ -d "$user_data/textures" ]]; then
    find "$user_data/textures" -maxdepth 1 -name 'packermod_*.png' -exec rm -f {} +
fi

if [[ -f "$conf" ]]; then
    sed -i "/^main_menu_script /d" "$conf"
    sed -i "s|^# packermod-backup main_menu_script|main_menu_script|" "$conf"
    echo "Restored $conf"
fi

echo "Uninstalled. packs/ and cache/ left in place under $user_data/PackerMOD."
echo "(They contain your Packs and downloaded ContentDB cache. Delete manually if unwanted.)"
