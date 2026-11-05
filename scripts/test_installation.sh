#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
profile="$(mktemp -d /tmp/packermod-install-test.XXXXXX)"
mkdir -p "$profile/PackerMOD/packs/existing/worlds/world" "$profile/PackerMOD/cache" "$profile/worlds/other"
printf 'map sentinel\n' > "$profile/PackerMOD/packs/existing/worlds/world/map.sqlite"
printf 'cache sentinel\n' > "$profile/PackerMOD/cache/keep.bin"
printf 'other map sentinel\n' > "$profile/worlds/other/map.sqlite"
printf 'main_menu_script = original-menu.lua\ncustom_setting = keep\n' > "$profile/minetest.conf"
protected_hashes() { find "$profile/PackerMOD/packs" "$profile/PackerMOD/cache" "$profile/worlds" -type f -exec sha256sum {} + | sort; }
before="$(protected_hashes)"
LUANTI_USER_DATA="$profile" bash "$repo_root/install/install.sh" copy
printf 'backup sentinel\n' > "$profile/games/packerbase/old-version.txt"
LUANTI_USER_DATA="$profile" bash "$repo_root/install/install.sh" copy
[[ ! -e "$profile/games/packerbase/old-version.txt" ]]
find "$profile/PackerMOD/install-backups" -name old-version.txt | grep -q .
[[ "$(protected_hashes)" == "$before" ]]
grep -q '^# packermod-backup main_menu_script = original-menu.lua$' "$profile/minetest.conf"
grep -q '^custom_setting = keep$' "$profile/minetest.conf"
[[ "$(grep -c '^main_menu_script =' "$profile/minetest.conf")" == 1 ]]
# Exercise copy -> symlink -> repeated symlink -> copy transitions.
LUANTI_USER_DATA="$profile" bash "$repo_root/install/install.sh" symlink
LUANTI_USER_DATA="$profile" bash "$repo_root/install/install.sh" symlink
[[ -L "$profile/PackerMOD/mainmenu" && -L "$profile/PackerMOD/textures" ]]
LUANTI_USER_DATA="$profile" bash "$repo_root/install/install.sh" copy
[[ ! -L "$profile/PackerMOD/mainmenu" ]]
rm -- "$profile/games/packerbase/.packermod-managed"
config_before="$(sha256sum "$profile/minetest.conf")"
if LUANTI_USER_DATA="$profile" bash "$repo_root/install/install.sh" copy > "$profile/rejection.log" 2>&1; then echo 'Unmanaged game guard failed' >&2; exit 1; fi
grep -q 'unmanaged' "$profile/rejection.log"
[[ "$(sha256sum "$profile/minetest.conf")" == "$config_before" ]]
printf 'managed\n' > "$profile/games/packerbase/.packermod-managed"
printf 'gameid = packerbase\n' > "$profile/games/packerbase/world.mt"
if LUANTI_USER_DATA="$profile" bash "$repo_root/install/install.sh" copy > "$profile/rejection.log" 2>&1; then echo 'World data guard failed' >&2; exit 1; fi
grep -q 'World data found' "$profile/rejection.log"
[[ -f "$profile/games/packerbase/world.mt" && "$(protected_hashes)" == "$before" ]]
echo 'PASS: Linux install/update, backups, preserved data/config, repeated symlinks, unmanaged-game and world-data guards.'
echo "Disposable test profile retained: $profile"
