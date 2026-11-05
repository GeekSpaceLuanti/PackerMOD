#!/usr/bin/env bash
set -euo pipefail
mode="${1:-symlink}"
[[ "$mode" == symlink || "$mode" == copy ]] || { echo "Usage: $0 [symlink|copy]" >&2; exit 2; }
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -n "${LUANTI_USER_DATA:-}" ]]; then
    user_data="$LUANTI_USER_DATA"
else
    case "$(uname -s)" in
        Linux) user_data="$HOME/.minetest" ;;
        Darwin) user_data="$HOME/Library/Application Support/luanti" ;;
        *) echo 'Unsupported OS. Use install.ps1 on Windows.' >&2; exit 2 ;;
    esac
fi
[[ -d "$user_data" ]] || { echo "Run Luanti first, or set LUANTI_USER_DATA: $user_data" >&2; exit 1; }
user_data="$(cd "$user_data" && pwd -P)"
target_root="$user_data/PackerMOD"
game_source="$repo_root/games/packerbase"
game_target="$user_data/games/packerbase"
[[ -f "$game_source/game.conf" ]] || { echo 'Bundled games/packerbase/game.conf is missing' >&2; exit 1; }
for parent in "$target_root" "$user_data/games"; do
    [[ ! -L "$parent" ]] || { echo "Installation parent is a link: $parent" >&2; exit 1; }
done
for target in "$target_root/mainmenu" "$target_root/textures" "$game_target"; do
    if [[ -L "$target" ]]; then
        expected="$repo_root/$(basename "$target")"
        [[ "$target" != "$game_target" && "$(readlink "$target")" == "$expected" ]] || { echo "Inspect unrecognized link before replacing: $target" >&2; exit 1; }
        continue
    fi
    if [[ -e "$target" ]] && [[ -n "$(find "$target" -type l -print -quit)" ]]; then
        echo "Installation contains links: $target" >&2; exit 1
    fi
done
if [[ -e "$game_target" ]]; then
    [[ -f "$game_target/.packermod-managed" ]] || { echo 'Existing packerbase is unmanaged; refusing to overwrite it' >&2; exit 1; }
    if [[ -n "$(find "$game_target" -type f \( -name world.mt -o -name map.sqlite -o -name map_meta.txt -o -name players.sqlite -o -name auth.sqlite \) -print -quit)" ]]; then
        echo 'World data found inside game directory; refusing to replace it' >&2; exit 1
    fi
fi
stamp="$(date +%Y%m%d-%H%M%S)-$$"
backup="$target_root/install-backups/$stamp"
mkdir -p "$backup" "$target_root/packs" "$target_root/cache" "$user_data/games"
conf="$user_data/minetest.conf"
[[ ! -f "$conf" ]] || cp -p "$conf" "$backup/minetest.conf"
for component in mainmenu textures packerbase; do
    if [[ "$component" == packerbase ]]; then source="$game_source"; target="$game_target"; else source="$repo_root/$component"; target="$target_root/$component"; fi
    if [[ -e "$target" ]]; then
        if [[ -L "$target" ]]; then cp -Rp "$source" "$backup/$component"; else cp -Rp "$target" "$backup/$component"; fi
    fi
    stage="$target.installing-$stamp"
    [[ ! -e "$stage" && ! -L "$stage" ]] || { echo "Stage already exists: $stage" >&2; exit 1; }
    cp -R "$source" "$stage"
    # diff compares every copied byte, including media and license files.
    diff -qr "$source" "$stage" >/dev/null
    [[ "$target" == "$target_root/mainmenu" || "$target" == "$target_root/textures" || "$target" == "$game_target" ]] || exit 1
    if [[ -L "$target" ]]; then rm -- "$target"; elif [[ -e "$target" ]]; then rm -rf -- "$target"; fi
    if [[ "$mode" == symlink && "$component" != packerbase ]]; then
        ln -s "$source" "$target"
        rm -rf -- "$stage"
    else mv "$stage" "$target"; fi
    echo "Installed $component: $target"
done
printf '%s\n' 'Installed by PackerMOD; previous versions are in PackerMOD/install-backups.' > "$game_target/.packermod-managed"
mkdir -p "$target_root/licenses"
for file in "$repo_root"/LICENSE* "$repo_root"/COPYING* "$repo_root"/NOTICE* "$repo_root"/THIRD_PARTY*; do
    [[ ! -f "$file" ]] || cp "$file" "$target_root/licenses/"
done
cp "$repo_root/vendor/pixelarticons/LICENSE" "$target_root/licenses/pixelarticons-MIT.txt"
# Portable to Linux and macOS: do not rely on incompatible sed -i forms.
[[ -f "$conf" ]] || : > "$conf"
awk '
    BEGIN { saved=0 }
    /^# packermod-backup main_menu_script/ { saved=1 }
    { lines[NR]=$0 }
    END {
        for (i=1; i<=NR; i++) {
            if (lines[i] ~ /^main_menu_script[[:space:]]*=/) {
                if (!saved) print "# packermod-backup " lines[i]
            } else print lines[i]
        }
    }
' "$conf" > "$conf.packermod-new"
printf 'main_menu_script = %s/mainmenu/init.lua\n' "$target_root" >> "$conf.packermod-new"
mv "$conf.packermod-new" "$conf"
echo "Using Luanti user data: $user_data"
echo "Backup: $backup"
echo 'Done. Start Luanti and select PackerMOD Base when creating a Pack.'
