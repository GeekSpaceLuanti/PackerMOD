#!/usr/bin/env bash
set -euo pipefail

case "$(uname -s)" in
    Linux)   user_data="$HOME/.minetest" ;;
    Darwin)  user_data="$HOME/Library/Application Support/luanti" ;;
    *)       echo "Unsupported OS." >&2; exit 2 ;;
esac

conf="$user_data/minetest.conf"
target_mainmenu="$user_data/PackerMOD/mainmenu"

if [[ -e "$target_mainmenu" || -L "$target_mainmenu" ]]; then
    rm -rf "$target_mainmenu"
    echo "Removed $target_mainmenu"
fi

if [[ -f "$conf" ]]; then
    sed -i "/^main_menu_script /d" "$conf"
    sed -i "s|^# packermod-backup main_menu_script|main_menu_script|" "$conf"
    echo "Restored $conf"
fi

echo "Uninstalled. packs/ and cache/ left in place under $user_data/PackerMOD."
