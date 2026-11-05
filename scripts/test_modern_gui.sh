#!/usr/bin/env bash
# Test the standalone pmui + example in a completely disposable client/server.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
width="${WIN_W:-1280}"
height="${WIN_H:-800}"
if [[ "${PMUI_XVFB:-}" != 1 ]]; then
  exec xvfb-run -a -s "-screen 0 ${width}x${height}x24 -nolisten tcp" env PMUI_XVFB=1 bash "$0"
fi
runner="${LUANTI_BIN:-${XDG_CACHE_HOME:-$HOME/.cache}/packermod-tools/luanti-5.16.1/bin/luanti}"
runner="$(command -v "$runner")"
engine_root="$(cd "$(dirname "$runner")/.." && pwd)"
run="$(mktemp -d -t pmui-standalone.XXXXXX)"
pid=""
cleanup() { if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi; rm -rf -- "$run"; }
trap cleanup EXIT
user="$run/user"
mkdir -p "$user/bin" "$user/games/pmui_test/mods" "$user/worlds/demo" "$repo/.screenshots"
cp "$runner" "$user/bin/luanti"
for asset in builtin client textures fonts locale settingtypes.txt; do
  [[ ! -e "$engine_root/$asset" ]] || ln -s "$engine_root/$asset" "$user/$asset"
done
cp -r "$repo/mainmenu/lib/pmui/modern" "$user/games/pmui_test/mods/pmui"
cp -r "$repo/examples/pmui_demo" "$user/games/pmui_test/mods/pmui_demo"
mkdir -p "$user/games/pmui_test/mods/pmui_smoke"
printf 'title = PMUI standalone test\n' > "$user/games/pmui_test/game.conf"
printf 'name = pmui_smoke\ndepends = pmui_demo\n' > "$user/games/pmui_test/mods/pmui_smoke/mod.conf"
cat > "$user/games/pmui_test/mods/pmui_smoke/init.lua" <<'LUA'
assert(not rawget(_G,"packermod"), "PackerMOD leaked into the standalone test")
local original_show=core.show_formspec
core.show_formspec=function(name,form,fs)
  if fs:find("Saved: GUI smoke",1,true) then core.log("action","PMUI: real save interaction verified") end
  return original_show(name,form,fs)
end
core.register_on_joinplayer(function(player)
  player:set_physics_override({gravity=0})
  local function open()
    if not player:is_valid() then return end
    if pmui_demo.show(player) then core.log("action","PMUI: standalone in-game GUI ready")
    else core.after(0.1,open) end
  end
  core.after(0.5,open)
end)
LUA
printf 'gameid = pmui_test\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\n' > "$user/worlds/demo/world.mt"
cat > "$run/minetest.conf" <<CONF
screen_w = $width
screen_h = $height
fullscreen = false
enable_sound = false
mg_name = singlenode
port = $((43000 + $$ % 1000))
bind_address = 127.0.0.1
enable_ipv6 = false
CONF
LIBGL_ALWAYS_SOFTWARE=1 "$user/bin/luanti" --config "$run/minetest.conf" --logfile "$run/engine.log" --go --world "$user/worlds/demo" --gameid pmui_test > "$run/console.log" 2>&1 &
pid=$!
for ((i=0;i<400;i++)); do
  if grep -q 'PMUI: standalone in-game GUI ready' "$run/engine.log" 2>/dev/null; then break; fi
  kill -0 "$pid" 2>/dev/null || { cat "$run/console.log";exit 1; }
  sleep 0.1
done
grep -q 'PMUI: standalone in-game GUI ready' "$run/engine.log" || { cat "$run/console.log";exit 1; }
sleep 0.5
window="$(xdotool search --onlyvisible --pid "$pid" | head -1)"
if [[ "$width" == 1280 && "$height" == 800 ]]; then
  xdotool mousemove --window "$window" 500 450 click 1
  xdotool key --clearmodifiers ctrl+a
  xdotool type --clearmodifiers 'GUI smoke'
  xdotool mousemove --window "$window" 850 550 click 1
  sleep 0.5
  grep -q 'PMUI: real save interaction verified' "$run/engine.log" || { cat "$run/engine.log";exit 1; }
fi
import -window "$window" "$repo/.screenshots/pmui_standalone_${width}x${height}.png"
cp "$run/engine.log" "$repo/.screenshots/pmui_standalone_${width}x${height}.log"
if grep -E 'ERROR\[|Could not open file of image|Invalid use|invalid use' "$run/engine.log"; then exit 1; fi
echo 'PASS: standalone PMUI mod and example rendered in-game without PackerMOD.'
