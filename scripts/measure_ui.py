#!/usr/bin/env python3
"""スクショから UI の幾何を数値化するデザイン検証ツール。

目視レビューは数 px のズレ・gap=0 の密着を見逃す (実績あり) ため、
デザインチェックでは必ずこれで数値を取る。

測定項目:
- 背景テクスチャのカバレッジ: bg 単色 (--bg) と異なるピクセルの bbox と余白。
  背景画像がウィンドウ全面を覆っているかの検証に使う。
- アイコンボタン枠: neon accent 色 (cyan / hover magenta) の連結成分のうち
  正方形に近い 35-90px のもの。
- ボタンラベル: 枠列の下の帯にある白文字を単語クラスタリングし、最寄りの枠に
  割り当てて中心 offset と枠底辺からの gap を出す。
  前提: ラベルは枠の外・下に白文字で置かれるレイアウト。ラベルを枠内に移す
  変更をしたらこのスクリプトも追従させること。

使い方:
  python3 scripts/measure_ui.py /tmp/mainmenu_library.png
  python3 scripts/measure_ui.py shot.png --bg 0a0a18 --json

依存: python3 + Pillow + numpy (サーバーに導入済み)。
"""
import argparse
import json
import sys
from collections import deque

import numpy as np
from PIL import Image


def parse_hex(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)])


def connected_boxes(mask):
    """mask の 8 近傍連結成分の bbox 一覧を返す。"""
    H, W = mask.shape
    visited = np.zeros((H, W), dtype=bool)
    boxes = []
    for sy, sx in zip(*np.where(mask)):
        if visited[sy, sx]:
            continue
        q = deque([(sy, sx)])
        visited[sy, sx] = True
        minx = maxx = sx
        miny = maxy = sy
        while q:
            y, x = q.popleft()
            minx, maxx = min(minx, x), max(maxx, x)
            miny, maxy = min(miny, y), max(maxy, y)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < H and 0 <= nx < W and not visited[ny, nx] and mask[ny, nx]:
                        visited[ny, nx] = True
                        q.append((ny, nx))
        boxes.append((int(minx), int(miny), int(maxx), int(maxy)))
    return boxes


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("image")
    ap.add_argument("--bg", default="0a0a18", help="テーマの背景単色 (hex)")
    ap.add_argument("--json", action="store_true", help="機械可読 JSON で出力")
    args = ap.parse_args()

    img = np.array(Image.open(args.image).convert("RGB")).astype(int)
    H, W, _ = img.shape
    r, g, b = img[:, :, 0], img[:, :, 1], img[:, :, 2]
    result = {"window": [W, H]}

    # --- 背景テクスチャのカバレッジ ---
    diff = np.abs(img - parse_hex(args.bg)).sum(axis=2)
    ys, xs = np.where(diff > 30)
    if len(xs):
        bbox = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
        result["content_bbox"] = bbox
        result["margins"] = {
            "left": bbox[0], "top": bbox[1],
            "right": W - 1 - bbox[2], "bottom": H - 1 - bbox[3],
        }

    # --- アイコンボタン枠 (cyan / hover magenta) ---
    cyan = (g > 150) & (b > 140) & (r < 120)
    magenta = (r > 150) & (b > 100) & (g < 120)
    frames = []
    for color, mask in (("cyan", cyan), ("magenta", magenta)):
        for (minx, miny, maxx, maxy) in connected_boxes(mask):
            w, h = maxx - minx + 1, maxy - miny + 1
            if 35 <= w <= 90 and 35 <= h <= 90 and abs(w - h) <= 12:
                frames.append({"color": color, "bbox": [minx, miny, maxx, maxy]})
    frames.sort(key=lambda f: f["bbox"][0])
    result["buttons"] = frames

    # --- ラベル割り当て (枠列の下の白文字帯を単語分割) ---
    if frames:
        white = (r >= 200) & (g >= 200) & (b >= 200)
        frame_bottom = max(f["bbox"][3] for f in frames)
        band_y0, band_y1 = frame_bottom + 1, min(H, frame_bottom + 40)
        col_has = white[band_y0:band_y1, :].any(axis=0)
        words, start, gap_run = [], None, 0
        for x in range(W):
            if col_has[x]:
                if start is None:
                    start = x
                gap_run = 0
            elif start is not None:
                gap_run += 1
                if gap_run > 10:
                    words.append((start, x - gap_run))
                    start = None
        if start is not None:
            words.append((start, W - 1))

        for f in frames:
            minx, miny, maxx, maxy = f["bbox"]
            bcx = (minx + maxx) / 2
            if not words:
                f["label"] = None
                continue
            lminx, lmaxx = min(words, key=lambda w: abs((w[0] + w[1]) / 2 - bcx))
            seg_ys, _ = np.where(white[band_y0:band_y1, lminx:lmaxx + 1])
            f["label"] = {
                "bbox_x": [lminx, lmaxx],
                "center_offset": round((lminx + lmaxx) / 2 - bcx, 1),
                "gap": int(seg_ys.min() + band_y0 - maxy - 1),
            }

    if args.json:
        json.dump(result, sys.stdout, ensure_ascii=False, indent=1)
        print()
        return

    print(f"window: {W}x{H}")
    if "content_bbox" in result:
        x0, y0, x1, y1 = result["content_bbox"]
        m = result["margins"]
        print(f"content bbox (non-bg): x[{x0}..{x1}] y[{y0}..{y1}] => {x1-x0+1}x{y1-y0+1}")
        print(f"  margins: left={m['left']} right={m['right']} top={m['top']} bottom={m['bottom']}")
    print(f"\nbutton frames detected: {len(frames)}")
    for i, f in enumerate(frames):
        minx, miny, maxx, maxy = f["bbox"]
        line = f"  btn{i} ({f['color']}): frame x[{minx}..{maxx}] center={(minx+maxx)/2:.1f}"
        if f.get("label"):
            lb = f["label"]
            line += (f" | label x[{lb['bbox_x'][0]}..{lb['bbox_x'][1]}]"
                     f" | offset={lb['center_offset']:+.1f}px | gap={lb['gap']}px")
        else:
            line += " | label: NOT FOUND"
        print(line)


if __name__ == "__main__":
    main()
