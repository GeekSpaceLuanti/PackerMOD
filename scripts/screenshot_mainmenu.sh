#!/usr/bin/env bash
# Capture the PackerMOD main menu under Xvfb and save a PNG.
#
# Usage:
#   scripts/screenshot_mainmenu.sh [tab] [out_path]
#     tab: packs | import | create | settings   (default: create)
#     out: PNG path                              (default: /tmp/mainmenu_<tab>.png)
#
# Requires: Xvfb, xdotool, luanti (>= 5.16 for in-menu F12).
# PackerMOD must already be installed via install/install.sh.

set -euo pipefail

TAB="${1:-create}"
OUT="${2:-/tmp/mainmenu_${TAB}.png}"

DISPLAY_NUM="${DISPLAY_NUM:-99}"
# Match the user's saved Luanti window so click coordinates line up.
WIN_W="${WIN_W:-796}"
WIN_H="${WIN_H:-845}"
SHOT_DIR="${HOME}/.minetest/screenshots"
LOG="${LOG:-/tmp/luanti_${TAB}.log}"

mkdir -p "$SHOT_DIR"

# Tab x pixel centres observed at WIN_W=796: each tab is auto-sized by text width.
case "$TAB" in
    packs)    TAB_X=94  ;;
    import)   TAB_X=147 ;;
    create)   TAB_X=213 ;;
    settings) TAB_X=288 ;;
    *) echo "unknown tab: $TAB" >&2; exit 2 ;;
esac
TAB_Y=240

XVFB_PID=""
LUANTI_PID=""
cleanup() {
    [[ -n "$LUANTI_PID" ]] && kill "$LUANTI_PID" 2>/dev/null || true
    [[ -n "$LUANTI_PID" ]] && wait "$LUANTI_PID" 2>/dev/null || true
    [[ -n "$XVFB_PID"  ]] && kill "$XVFB_PID"   2>/dev/null || true
    [[ -n "$XVFB_PID"  ]] && wait "$XVFB_PID"   2>/dev/null || true
}
trap cleanup EXIT

# Start Xvfb with auth disabled so xdotool can attach freely.
Xvfb ":$DISPLAY_NUM" -screen 0 "${WIN_W}x${WIN_H}x24" -ac -nolisten tcp \
    >/tmp/xvfb_${DISPLAY_NUM}.log 2>&1 &
XVFB_PID=$!

# Wait for Xvfb to be ready.
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

# Launch Luanti against the virtual display with software GL.
DISPLAY=":$DISPLAY_NUM" LIBGL_ALWAYS_SOFTWARE=1 luanti >"$LOG" 2>&1 &
LUANTI_PID=$!

# Wait for the GUI to come up.
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

# Switch tab (click is a no-op for packs/default, but harmless).
DISPLAY=":$DISPLAY_NUM" xdotool mousemove "$TAB_X" "$TAB_Y" click 1 || true
sleep 0.5

# Take screenshot via Luanti F12 (PR #16749, Luanti >= 5.16).
DISPLAY=":$DISPLAY_NUM" xdotool key F12
sleep 1

# Find the most recently produced screenshot.
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
