#!/usr/bin/env bash
set -euo pipefail

mode="${1:-symlink}"

if [[ "$mode" != "symlink" && "$mode" != "copy" ]]; then
    echo "Usage: $0 [symlink|copy]" >&2
    exit 2
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

case "$(uname -s)" in
    Linux)   user_data="$HOME/.minetest" ;;
    Darwin)  user_data="$HOME/Library/Application Support/luanti" ;;
    *)       echo "Unsupported OS. Use install.ps1 on Windows." >&2; exit 2 ;;
esac

if [[ ! -d "$user_data" ]]; then
    echo "Luanti user data directory not found: $user_data" >&2
    echo "Run Luanti once to create it, or override LUANTI_USER_DATA." >&2
    exit 1
fi

target_root="$user_data/PackerMOD"
target_mainmenu="$target_root/mainmenu"
mkdir -p "$target_root/packs" "$target_root/cache"

if [[ -e "$target_mainmenu" || -L "$target_mainmenu" ]]; then
    rm -rf "$target_mainmenu"
fi

if [[ "$mode" == "symlink" ]]; then
    ln -s "$repo_root/mainmenu" "$target_mainmenu"
    echo "Linked $target_mainmenu -> $repo_root/mainmenu"
else
    cp -r "$repo_root/mainmenu" "$target_mainmenu"
    echo "Copied $repo_root/mainmenu -> $target_mainmenu"
fi

conf="$user_data/minetest.conf"
abs_init="$target_mainmenu/init.lua"

if [[ ! -f "$conf" ]]; then
    : > "$conf"
fi

if grep -q "^main_menu_script" "$conf"; then
    if ! grep -q "^# packermod-backup main_menu_script" "$conf"; then
        sed -i "s|^main_menu_script|# packermod-backup main_menu_script|" "$conf"
    fi
    sed -i "/^main_menu_script /d" "$conf"
fi

echo "main_menu_script = $abs_init" >> "$conf"
echo "Wrote main_menu_script = $abs_init to $conf"
echo
echo "Done. Start Luanti to load the PackerMOD main menu."
