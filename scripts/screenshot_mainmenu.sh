#!/usr/bin/env bash
# Capture the PackerMOD main menu under Xvfb and save a PNG.
#
# Phase 8+: メニューは単一の Library 画面に統合された。引数は subtab を指す:
#
# Usage:
#   scripts/screenshot_mainmenu.sh [subtab] [out_path]
#     subtab: library | worlds | multi | mods | info   (default: library)
#     out:    PNG path                                 (default: /tmp/mainmenu_<subtab>.png)
#
# Subtab switching is settings-driven via `packermod_initial_subtab` so we
# don't need pixel-perfect xdotool clicks. The setting is written to
# minetest.conf before launching Luanti and removed afterwards.
#
# Requires: Xvfb, xdotool, luanti (>= 5.16 for in-menu F12).
# PackerMOD must already be installed via install/install.sh.

set -euo pipefail

SUBTAB="${1:-library}"
OUT="${2:-/tmp/mainmenu_${SUBTAB}.png}"

case "$SUBTAB" in
    library|worlds|multi|mods|info) ;;
    *) echo "unknown subtab: $SUBTAB (expected library|worlds|multi|mods|info)" >&2; exit 2 ;;
esac

DISPLAY_NUM="${DISPLAY_NUM:-99}"
# Xvfb canvas must be at least as large as Luanti's screen_w/screen_h from
# the user's minetest.conf; oversize is harmless.
WIN_W="${WIN_W:-1280}"
WIN_H="${WIN_H:-960}"
SHOT_DIR="${HOME}/.minetest/screenshots"
CONF="${HOME}/.minetest/minetest.conf"
LOG="${LOG:-/tmp/luanti_${SUBTAB}.log}"

mkdir -p "$SHOT_DIR"

XVFB_PID=""
LUANTI_PID=""
cleanup() {
    [[ -n "$LUANTI_PID" ]] && kill "$LUANTI_PID" 2>/dev/null || true
    [[ -n "$LUANTI_PID" ]] && wait "$LUANTI_PID" 2>/dev/null || true
    [[ -n "$XVFB_PID"  ]] && kill "$XVFB_PID"   2>/dev/null || true
    [[ -n "$XVFB_PID"  ]] && wait "$XVFB_PID"   2>/dev/null || true
    # Always strip the dev hook so it doesn't leak into normal runs.
    if [[ -f "$CONF" ]]; then
        sed -i '/^packermod_initial_subtab/d;/^packermod_initial_tab/d' "$CONF"
    fi
}
trap cleanup EXIT

# Inject the initial-subtab setting and strip any previous value.
if [[ -f "$CONF" ]]; then
    sed -i '/^packermod_initial_subtab/d;/^packermod_initial_tab/d' "$CONF"
fi
if [[ "$SUBTAB" != "library" ]]; then
    echo "packermod_initial_subtab = $SUBTAB" >> "$CONF"
fi

# Start Xvfb (auth disabled so xdotool can attach without juggling Xauthority).
Xvfb ":$DISPLAY_NUM" -screen 0 "${WIN_W}x${WIN_H}x24" -ac -nolisten tcp \
    >/tmp/xvfb_${DISPLAY_NUM}.log 2>&1 &
XVFB_PID=$!

for _ in $(seq 1 20); do
    if DISPLAY=":$DISPLAY_NUM" xdpyinfo >/dev/null 2>&1; then
        break
    fi
    if ! kill -0 "$XVFB_PID" 2>/dev/null; then
        echo "Xvfb failed to start. log:" >&2
        cat /tmp/xvfb_${DISPLAY_NUM}.log >&2
        exit 1
    fi
    sleep 0.2
done

TS_BEFORE=$(date +%s)

DISPLAY=":$DISPLAY_NUM" LIBGL_ALWAYS_SOFTWARE=1 luanti >"$LOG" 2>&1 &
LUANTI_PID=$!

for _ in $(seq 1 40); do
    if grep -q "GUIEngine\|game_t" "$LOG" 2>/dev/null; then
        break
    fi
    if ! kill -0 "$LUANTI_PID" 2>/dev/null; then
        echo "Luanti exited early. log tail:" >&2
        tail -20 "$LOG" >&2
        exit 1
    fi
    sleep 0.25
done
sleep 1.5

DISPLAY=":$DISPLAY_NUM" xdotool key F12
sleep 1

LATEST=$(find "$SHOT_DIR" -name '*.png' -newermt "@$TS_BEFORE" 2>/dev/null | sort | tail -1)

if [[ -z "$LATEST" ]]; then
    if command -v import >/dev/null; then
        DISPLAY=":$DISPLAY_NUM" import -window root "$OUT"
        echo "saved (root-capture fallback): $OUT" >&2
    else
        echo "screenshot_mainmenu: F12 produced no PNG and ImageMagick not installed" >&2
        echo "Luanti log tail:" >&2
        tail -20 "$LOG" >&2
        exit 1
    fi
else
    cp "$LATEST" "$OUT"
    echo "saved: $OUT (from $LATEST)" >&2
fi

echo "$OUT"
