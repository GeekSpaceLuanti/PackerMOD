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

# Phase 11+: modal_<name> 引数で Library 起動と同時に該当モーダルを開く。
case "$SUBTAB" in
    library|worlds|multi|mods|info) MODAL="" ;;
    modal_import|modal_create|modal_settings) MODAL="${SUBTAB#modal_}"; SUBTAB="library" ;;
    *) echo "unknown subtab: $SUBTAB (expected library|worlds|multi|mods|info|modal_import|modal_create|modal_settings)" >&2; exit 2 ;;
esac

DISPLAY_NUM="${DISPLAY_NUM:-99}"
# Xvfb canvas must be at least as large as Luanti's screen_w/screen_h from
# the user's minetest.conf; oversize is harmless.
# Luanti のウィンドウ (formspec) サイズ。responsive レイアウトの検証で解像度を
# 振るためにここで制御する。Luanti は screen_w/h を conf から読み autosave するので、
# conf へ明示注入 + autosave 無効化しないと前回値へドリフトする (Phase 0 実測)。
SCREEN_W="${SCREEN_W:-1024}"
SCREEN_H="${SCREEN_H:-600}"
GUI_SCALING="${GUI_SCALING:-}"   # 空なら注入しない (ユーザー設定を尊重)
# Xvfb キャンバスは window 以上であればよい。明示 WIN_* が無ければ画面に追従。
WIN_W="${WIN_W:-$SCREEN_W}"
WIN_H="${WIN_H:-$SCREEN_H}"
SHOT_DIR="${HOME}/.minetest/screenshots"
CONF="${HOME}/.minetest/minetest.conf"
LOG="${LOG:-/tmp/luanti_${SUBTAB}.log}"

mkdir -p "$SHOT_DIR"

# pack fixture (empty / three 等) を差し込むと決定論的な pack 集合で撮れる。
# FIXTURE=<name> で spec/design/fixtures/<name> を指す (絶対パスも可)。
FIXTURE="${FIXTURE:-}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 注入する dev / display 設定キー (cleanup で一括除去する対象)。
DEV_KEYS='^packermod_initial_subtab\|^packermod_initial_modal\|^packermod_dev_\|^packermod_fixture_root\|^screen_w \|^screen_h \|^gui_scaling \|^autosave_screensize '

XVFB_PID=""
LUANTI_PID=""
cleanup() {
    [[ -n "$LUANTI_PID" ]] && kill "$LUANTI_PID" 2>/dev/null || true
    [[ -n "$LUANTI_PID" ]] && wait "$LUANTI_PID" 2>/dev/null || true
    [[ -n "$XVFB_PID"  ]] && kill "$XVFB_PID"   2>/dev/null || true
    [[ -n "$XVFB_PID"  ]] && wait "$XVFB_PID"   2>/dev/null || true
    # Always strip injected keys so they don't leak into normal runs.
    if [[ -f "$CONF" ]]; then
        sed -i "/$DEV_KEYS/d" "$CONF"
    fi
    [[ -n "${STAGE_DIR:-}" ]] && rm -rf "$STAGE_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Strip previous values, then inject subtab/modal + display settings.
if [[ -f "$CONF" ]]; then
    sed -i "/$DEV_KEYS/d" "$CONF"
fi
if [[ "$SUBTAB" != "library" ]]; then
    echo "packermod_initial_subtab = $SUBTAB" >> "$CONF"
fi
if [[ -n "${MODAL:-}" ]]; then
    echo "packermod_initial_modal = $MODAL" >> "$CONF"
fi
{
    echo "screen_w = $SCREEN_W"
    echo "screen_h = $SCREEN_H"
    echo "autosave_screensize = false"
    [[ -n "$GUI_SCALING" ]] && echo "gui_scaling = $GUI_SCALING"
} >> "$CONF"
STAGE_DIR=""
if [[ -n "$FIXTURE" ]]; then
    fx_dir="$FIXTURE"
    [[ "$fx_dir" != /* ]] && fx_dir="$REPO_ROOT/spec/design/fixtures/$FIXTURE"
    if [[ ! -d "$fx_dir/PackerMOD/packs" ]]; then
        echo "fixture not found: $fx_dir/PackerMOD/packs" >&2; exit 2
    fi
    # Luanti の Mod security は user path 外への書き込みを拒否する。
    # repo 内 fixture は read-only なので、ensure_dirs が create_dir で落ちる。
    # 書き込み可能な ~/.minetest 下へステージングしてから指す。
    STAGE_DIR="${HOME}/.minetest/.pm_fixture_stage"
    rm -rf "$STAGE_DIR"
    mkdir -p "$STAGE_DIR"
    cp -r "$fx_dir/PackerMOD" "$STAGE_DIR/"
    echo "packermod_fixture_root = $STAGE_DIR" >> "$CONF"
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
