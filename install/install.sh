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

# Place a sibling `textures/` directory next to mainmenu so init.lua can
# resolve PackerMOD textures by an absolute path. Luanti's mainmenu only
# name-resolves textures under <share>/textures/base/pack/, which is
# write-protected; using an absolute path bypasses that limitation.
target_pm_textures="$target_root/textures"
if [[ -e "$target_pm_textures" || -L "$target_pm_textures" ]]; then
    rm -rf "$target_pm_textures"
fi
if [[ "$mode" == "symlink" ]]; then
    ln -s "$repo_root/textures" "$target_pm_textures"
    echo "Linked $target_pm_textures -> $repo_root/textures"
else
    cp -r "$repo_root/textures" "$target_pm_textures"
    echo "Copied $repo_root/textures -> $target_pm_textures"
fi

# (Textures are placed in $target_root/textures above and accessed by
# absolute path from init.lua. We no longer copy them into <user>/textures
# because Luanti's mainmenu won't resolve them by name there anyway.)

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
