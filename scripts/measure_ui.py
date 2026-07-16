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
  python3 scripts/measure_ui.py shot.png --assert spec/design/library.json

--assert モード: 期待値 spec (JSON) の各 check を測定値と突き合わせ、
1 つでも fail すれば exit 1。#24 のような幾何バグの再現テスト (red→green) に使う。
check は「性質」(中心一致・gap・divider 太さ等) を表明し、閾値は px か
--unit-px 倍で書く。構造 (ラベルが枠内/外) が変わっても性質の表明は不変。

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


def detect_dividers(r, g, b, W, H, min_span_frac=0.4):
    """水平方向に広く伸びる cyan 罫線 (header border-bottom / action-bar border-top)
    を検出し、各 divider の {y, thickness, x_span, brightness} を返す。

    dim な罫線 (#6: 1px #059189 で輝度 57%) も拾えるよう、mask は「cyan 寄り」
    (g,b が r より十分高い) の広めの条件を使う。brightness は band 内の g チャンネル
    最大値 (目標 #00ffe5 の g=255 に対する近さ)。thickness は縦連続 px。
    これで「太さ ≥ 2px」と「十分に明るい cyan」を分けて表明できる。
    """
    # dim cyan を含む広い mask (divider は彩度は低くても hue は cyan)
    cyanish = (g > r + 20) & (b > r + 20) & (g > 60)
    min_span = int(W * min_span_frac)
    row_span = np.zeros(H, dtype=int)
    row_x0 = np.zeros(H, dtype=int)
    row_x1 = np.zeros(H, dtype=int)
    for y in range(H):
        xs = np.where(cyanish[y])[0]
        if len(xs) == 0:
            continue
        # 最長の連続水平 run
        best_len, best_s = 0, xs[0]
        s = prev = xs[0]
        for x in xs[1:]:
            if x == prev + 1:
                prev = x
            else:
                if prev - s + 1 > best_len:
                    best_len, best_s = prev - s + 1, s
                s = prev = x
        if prev - s + 1 > best_len:
            best_len, best_s = prev - s + 1, s
        if best_len >= min_span:
            row_span[y] = best_len
            row_x0[y] = best_s
            row_x1[y] = best_s + best_len - 1
    dividers = []
    y = 0
    while y < H:
        if row_span[y] > 0:
            y0 = y
            while y < H and row_span[y] > 0:
                y += 1
            y1 = y - 1
            band = range(y0, y1 + 1)
            x0 = int(min(row_x0[k] for k in band))
            x1 = int(max(row_x1[k] for k in band))
            dividers.append({
                "y": y0,
                "thickness": y1 - y0 + 1,
                "x_span": [x0, x1],
                "brightness": int(g[y0:y1 + 1, x0:x1 + 1].max()),
            })
        else:
            y += 1
    return dividers


# --- assertion mode ---

def _measure_scalar(name, result):
    """assert spec の measure 名から結果 dict へスカラーを引く。
    未知 name や測定不能は None を返す (呼び出し側で fail 扱い)。"""
    if name == "bg_margin_max":
        m = result.get("margins")
        return max(m["left"], m["right"], m["top"], m["bottom"]) if m else None
    if name == "bg_margin_min":
        m = result.get("margins")
        return min(m["left"], m["right"], m["top"], m["bottom"]) if m else None
    if name == "label_offset_abs_max":
        labels = [f["label"] for f in result.get("buttons", []) if f.get("label")]
        return max((abs(l["center_offset"]) for l in labels), default=None)
    if name == "label_gap_min":
        labels = [f["label"] for f in result.get("buttons", []) if f.get("label")]
        return min((l["gap"] for l in labels), default=None)
    if name == "button_count":
        return len(result.get("buttons", []))
    if name == "divider_count":
        return len(result.get("dividers", []))
    if name == "divider_thickness_min":
        d = result.get("dividers", [])
        return min((x["thickness"] for x in d), default=None)
    if name == "divider_brightness_min":
        d = result.get("dividers", [])
        return min((x["brightness"] for x in d), default=None)
    return None


def _eval_check(chk, result, unit_px):
    measured = _measure_scalar(chk["measure"], result)
    threshold = chk["value"]
    if isinstance(threshold, str) and threshold.endswith("u"):
        # "0.05u" 形式: unit_px 倍の px 閾値 (解像度非依存の性質表明用)
        if unit_px is None:
            return None, measured, "unit_px 未指定 (--unit-px が必要)"
        threshold = float(threshold[:-1]) * unit_px
    if measured is None:
        return False, None, "測定不能"
    op = chk["op"]
    ok = {
        "<=": measured <= threshold, ">=": measured >= threshold,
        "<": measured < threshold, ">": measured > threshold,
        "==": measured == threshold,
    }.get(op)
    if ok is None:
        return None, measured, f"未知 op {op}"
    return bool(ok), measured, f"{measured} {op} {threshold}"


def run_assertions(spec_path, result, unit_px):
    with open(spec_path, encoding="utf-8") as fh:
        spec = json.load(fh)
    only = spec.get("only")  # issue 番号のリスト (指定時はそれだけ実行)
    checks = spec.get("checks", [])
    passed = failed = 0
    print(f"=== design assertions: {spec_path} ===")
    for chk in checks:
        if only and chk.get("issue") not in only:
            continue
        ok, measured, detail = _eval_check(chk, result, unit_px)
        tag = "PASS" if ok else ("FAIL" if ok is False else "ERR ")
        if ok:
            passed += 1
        else:
            failed += 1
        issue = chk.get("issue", "")
        print(f"  [{tag}] {issue:>3} {chk['id']}: {detail}")
    print(f"--- {passed} passed, {failed} failed ---")
    return failed == 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("image")
    ap.add_argument("--bg", default="0a0a18", help="テーマの背景単色 (hex)")
    ap.add_argument("--json", action="store_true", help="機械可読 JSON で出力")
    ap.add_argument("--assert", dest="assert_spec", default=None,
                    help="期待値 spec (JSON) と突き合わせ、fail で exit 1")
    ap.add_argument("--unit-px", type=float, default=None,
                    help="'Nu' 閾値の px 換算に使う 1 formspec unit の px")
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

    # --- divider (header/action-bar の cyan 罫線) ---
    result["dividers"] = detect_dividers(r, g, b, W, H)
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

    if args.assert_spec:
        ok = run_assertions(args.assert_spec, result, args.unit_px)
        sys.exit(0 if ok else 1)

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
    dividers = result.get("dividers", [])
    print(f"\ndividers detected: {len(dividers)}")
    for i, d in enumerate(dividers):
        print(f"  div{i}: y={d['y']} thickness={d['thickness']}px "
              f"x[{d['x_span'][0]}..{d['x_span'][1]}] brightness(g)={d['brightness']}")

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
