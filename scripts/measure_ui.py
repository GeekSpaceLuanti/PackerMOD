#!/usr/bin/env python3
"""スクショから UI の幾何を数値化するデザイン検証ツール。

目視レビューは数 px のズレ・gap=0 の密着を見逃す (実績あり) ため、
デザインチェックでは必ずこれで数値を取る。

測定項目:
- 背景テクスチャのカバレッジ: bg 単色 (--bg) と異なるピクセルの bbox と余白。
  背景画像がウィンドウ全面を覆っているかの検証に使う。
- composite icon-button 枠 (Phase 4): 画面下部の cyan 矩形リング (連結成分)。
  枠がアイコン+ラベル全体を包む。枠内は「アイコン (上) / divider / ラベル (下、
  cyan text)」の縦積み。ラベルは divider 下の cyan クラスタとして拾い、枠中心からの
  水平 offset (#1)・divider からの gap (#2)・枠内包 (#5)・枠右端一致 (#8) を測る。

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


def detect_dividers(r, g, b, W, H, min_span_frac=0.55, max_thickness=6):
    """UI の cyan 罫線 (header border-bottom / action-bar border-top) を検出し、
    各 divider の {y, thickness, x_span, brightness} を返す。

    エンジン制約: box[] は #00ffe5 を ~57% 輝度 (7,147,137) でしか描けないので、
    mask は彩度 cyan (g,b が r より十分高い) の広めの条件を使う。次を除外する:
      - サムネの cyan グリフ (T 字の横棒など、縦に厚い) → max_thickness
      - カードの 9-slice 上辺 (bright だが列 gap で分断され連続幅が足りない)
        → min_span_frac を content 全幅に近い 0.55 にして弾く
    divider は content 全幅を連続で走る 2-3px の水平線。#6 の「1px サブピクセルで
    潰れた」状態では厚み 1px で検出され thickness アサーションが red、3px 指定 (見かけ
    2px) に直すと thickness>=2 で green になる。
    """
    cyanish = (g > r + 40) & (b > r + 40) & (g > 100)
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
            thickness = y1 - y0 + 1
            if thickness <= max_thickness:  # 厚い cyan 塊 (サムネのグリフ等) は divider でない
                x0 = int(min(row_x0[k] for k in band))
                x1 = int(max(row_x1[k] for k in band))
                dividers.append({
                    "y": y0,
                    "thickness": thickness,
                    "x_span": [x0, x1],
                    "brightness": int(g[y0:y1 + 1, x0:x1 + 1].max()),
                })
        else:
            y += 1
    return dividers


def detect_action_buttons(cyan, W, H):
    """composite icon-button (Phase 4) の枠とラベルを検出する。

    枠 = 画面下部 (action-bar) にある中サイズの cyan 矩形リング (連結成分)。
    枠内は「アイコン (上) / divider (interior 幅の大半を占める横線) / ラベル (下、
    cyan text)」の縦積み。ラベルは divider より下の cyan クラスタとして拾い、枠中心
    からの水平 offset (#1) と divider からの gap (#2) を測る。枠内で拾うので #5 の
    「ラベルが枠内」は構造的に保証され、label を見つけられたか (labels_inside) で表明。
    """
    frames = []
    for (minx, miny, maxx, maxy) in connected_boxes(cyan):
        w, h = maxx - minx + 1, maxy - miny + 1
        # action button 枠: 下部 (miny > 0.6H) の中サイズ矩形。card (296x320↑) や
        # thumbnail、divider 罫線、ラベル文字 (小) はサイズ/位置で除外される。
        # 上限は解像度追従で育つボタン (2560 で ~175x130px) を含みつつ card
        # (2560 で ~534x577px) を外す幅に取る。
        if 50 <= w <= 280 and 40 <= h <= 240 and miny > H * 0.6:
            frames.append([minx, miny, maxx, maxy])
    frames.sort(key=lambda f: f[0])

    out = []
    for (minx, miny, maxx, maxy) in frames:
        b = {"color": "cyan", "bbox": [minx, miny, maxx, maxy], "label": None}
        inx0, inx1 = minx + 5, maxx - 5
        iny0, iny1 = miny + 4, maxy - 4
        if inx1 > inx0 and iny1 > iny0:
            cols_w = inx1 - inx0 + 1
            # ラベルは枠内の cyan text。アイコンは白 (cyan mask 外) なので枠内 cyan は
            # 「枠リング/divider (interior 幅の大半を占める横 1 本)」と「ラベル (部分幅の
            # 文字列)」。前者を「全幅行」として除外し、部分幅 cyan の連続行を text バンド
            # にまとめて最下バンド=ラベルとする (divider の明暗に依存しない)。
            text_rows = []
            for yy in range(iny0, iny1 + 1):
                xs = np.where(cyan[yy, inx0:inx1 + 1])[0]
                if len(xs) and (xs.max() - xs.min() + 1) < 0.9 * cols_w:
                    text_rows.append(yy)
            bands = []
            for yy in text_rows:
                if bands and yy - bands[-1][1] <= 2:
                    bands[-1][1] = yy
                else:
                    bands.append([yy, yy])
            if bands:
                lb_y0, lb_y1 = bands[-1]
                xs_all = []
                for yy in range(lb_y0, lb_y1 + 1):
                    xs = np.where(cyan[yy, inx0:inx1 + 1])[0]
                    xs_all.extend((xs + inx0).tolist())
                if xs_all:
                    lminx, lmaxx = min(xs_all), max(xs_all)
                    bcx = (minx + maxx) / 2
                    b["label"] = {
                        "bbox_x": [lminx, lmaxx],
                        "bbox_y": [lb_y0, lb_y1],
                        "center_offset": round((lminx + lmaxx) / 2 - bcx, 1),
                        # #2: ラベル下端と枠底辺の余白 (密着=0 の再発検知)。
                        "gap": int(maxy - lb_y1),
                    }
        out.append(b)
    return out


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
    if name == "labels_inside_count":
        # #5: ラベルが枠内 (composite) で検出できたボタン数。detect_action_buttons は
        # 枠 interior 内でしかラベルを拾わないので、label ありは即ち枠内包の証拠。
        return sum(1 for f in result.get("buttons", []) if f.get("label"))
    if name == "right_edge_spread":
        # #8: 揃うべき 3 要素の右端 x の最大差 (px) — divider 右端 / subtitle 右端 /
        # 最右ボタン枠右端。枠=box 境界 + action-bar 左右 padding=0 で一致するはず。
        rights = []
        d = result.get("dividers", [])
        if d:
            rights.append(max(x["x_span"][1] for x in d))
        if result.get("subtitle_right") is not None:
            rights.append(result["subtitle_right"])
        btns = result.get("buttons", [])
        if btns:
            rights.append(max(f["bbox"][2] for f in btns))
        return (max(rights) - min(rights)) if len(rights) >= 2 else None
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

    # --- アイコンボタン枠 (cyan) ---
    cyan = (g > 150) & (b > 140) & (r < 120)

    # --- divider (header/action-bar の cyan 罫線) ---
    result["dividers"] = detect_dividers(r, g, b, W, H)

    # --- subtitle (magenta "// PACK_LIBRARY") の右端 (#8 の右端一致に使う) ---
    magenta = (r > 150) & (b > 100) & (g < 120)
    # 最初の divider より上 (header 帯) の magenta を subtitle とみなす。
    top_y = result["dividers"][0]["y"] if result["dividers"] else int(H * 0.2)
    mys, mxs = np.where(magenta[:top_y, :])
    if len(mxs):
        result["subtitle_right"] = int(mxs.max())

    # --- composite icon-button (Phase 4): 枠がアイコン+ラベル全体を包む。
    # 枠 = 下部 (action-bar) の cyan 矩形リング。枠内はアイコン (上) / divider /
    # ラベル (下、cyan text) の縦積み。ラベルは枠内下帯の cyan クラスタで、divider
    # (interior 幅の大半を占める横線) の下にある。旧「ラベルは枠外・下の白文字」前提を
    # 更新したもの。#1 中心 offset / #2 divider-ラベル gap / #5 枠内包 / #8 右端一致。
    result["buttons"] = detect_action_buttons(cyan, W, H)

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

    buttons = result.get("buttons", [])
    print(f"\nbutton frames detected: {len(buttons)}")
    for i, f in enumerate(buttons):
        minx, miny, maxx, maxy = f["bbox"]
        line = (f"  btn{i} ({f['color']}): frame x[{minx}..{maxx}] "
                f"center={(minx+maxx)/2:.1f} right={maxx}")
        if f.get("label"):
            lb = f["label"]
            line += (f" | label x[{lb['bbox_x'][0]}..{lb['bbox_x'][1]}]"
                     f" | offset={lb['center_offset']:+.1f}px | gap(div→lbl)={lb['gap']}px")
        else:
            line += " | label: NOT FOUND"
        print(line)


if __name__ == "__main__":
    main()
