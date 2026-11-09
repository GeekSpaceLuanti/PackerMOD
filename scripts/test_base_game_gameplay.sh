#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-2.1-or-later
# Exercise falling, crouched ledges and item pickup in a disposable client.
set -euo pipefail
if [[ "${PACKERBASE_GAMEPLAY_XVFB:-}" != 1 ]]; then
    exec xvfb-run -a -s '-screen 0 1024x768x24 -nolisten tcp' env PACKERBASE_GAMEPLAY_XVFB=1 bash "$0" "$@"
fi
repo="$(cd "$(dirname "$0")/.." && pwd)"
runner="${LUANTI_BIN:-${XDG_CACHE_HOME:-$HOME/.cache}/packermod-tools/luanti-5.16.1/bin/luanti}"
run_dir="$(mktemp -d -t packerbase-gameplay.XXXXXX)"
pid=""
stop_client() {
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; pid=""; fi
}
cleanup() { stop_client; rm -rf -- "$run_dir"; }
trap cleanup EXIT
root="$(cd "$(dirname "$runner")/.." && pwd)"
mkdir -p "$run_dir/user/bin" "$run_dir/user/games"
if [[ -d "$root/builtin" ]]; then
    cp "$runner" "$run_dir/user/bin/luanti"
    for asset in builtin client textures fonts locale settingtypes.txt; do
        [[ ! -e "$root/$asset" ]] || ln -s "$root/$asset" "$run_dir/user/$asset"
    done
    runner="$run_dir/user/bin/luanti"
fi
ln -s "$repo/games/packerbase" "$run_dir/user/games/packerbase"

wait_for() {
    local pattern="$1"
    for attempt in $(seq 1 150); do
        if grep -q "$pattern" "$log"; then return; fi
        kill -0 "$pid" 2>/dev/null || break
        if grep -q 'ERROR\[' "$log"; then break; fi
        sleep 0.15
    done
    cat "$log" >&2
    echo "Missing gameplay marker: $pattern" >&2
    exit 1
}

for phase in baseline tuned; do
    world="$run_dir/world-$phase"
    config="$run_dir/config-$phase"
    log="$run_dir/$phase.log"
    mkdir -p "$world/worldmods/packer_gameplay"
    cp "$repo/games/packerbase/tests/gameplay/init.lua" "$world/worldmods/packer_gameplay/init.lua"
    printf 'name = packer_gameplay\ndepends = packer_core\n' > "$world/worldmods/packer_gameplay/mod.conf"
    printf 'gameid = packerbase\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\nload_mod_packer_gameplay = true\n' > "$world/world.mt"
    printf 'screen_w = 1024\nscreen_h = 768\nenable_sound = false\nenable_damage = false\nmg_name = singlenode\nstatic_spawnpoint = (0,1,0)\nkeymap_sneak = KEY_LSHIFT\nkeymap_forward = KEY_KEY_W\nkeymap_aux1 = SYSTEM_SCANCODE_224\n' > "$config"
    # Avoid colliding with other local Luanti smoke tests on the default port.
    printf 'port = %s\n' "$((31000 + RANDOM % 28000))" >> "$config"
    if [[ "$phase" == baseline ]]; then
        printf 'movement_gravity = 9.81\nmovement_speed_jump = 6.5\npacker_rigid_step_up = false\npacker_test_baseline = true\n' >> "$config"
    fi
    touch "$log"
    LUANTI_USER_PATH="$run_dir/user" LUANTI_GAME_PATH="$run_dir/user/games" \
        "$runner" --go --world "$world" --name PackerGameplay --port "$((31000 + RANDOM % 28000))" \
        --config "$config" --logfile "$log" \
        > "$run_dir/$phase-console.log" 2>&1 &
    pid=$!
    wait_for 'PackerMOD gameplay fall passed'
    printf '%s:\n' "$phase"
    grep -E 'PackerMOD gameplay (fall:|gravity:)' "$log"
    if [[ "$phase" == tuned ]]; then
        wait_for 'PackerMOD gameplay edge ready'
        window="$(xdotool search --pid "$pid" --onlyvisible | head -1)"
        xdotool windowfocus --sync "$window" keydown Shift_L keydown w
        wait_for 'PackerMOD gameplay crouched edge'
        xdotool keyup Shift_L
        wait_for 'PackerMOD gameplay edge passed'
        xdotool keyup w
        wait_for 'PackerMOD gameplay sprint ready'
        xdotool keydown Control_L keydown w
        wait_for 'PackerMOD gameplay sprint active'
        xdotool keyup Control_L keyup w
        wait_for 'PackerMOD gameplay sprint passed'
        grep -E 'PackerMOD gameplay (pickup passed|crouched edge|edge passed|sprint active|sprint passed)' "$log"
    fi
    stop_client
done
