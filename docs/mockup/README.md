# PackerMOD UI mockup — 4 方向性

PackerMOD の Pack Library 画面のスタイル方向を決めるための HTML プロト。
判断後、選んだ案を `mainmenu/lib/theme.lua` と `mainmenu/ui/library.yml` に落とす。

## 見方

```sh
xdg-open docs/mockup/index.html   # 4 案を 2x2 で並べた比較ビュー
xdg-open docs/mockup/neon.html    # 単独で開く(細部確認用)
```

## 4 案サマリー

| 案 | bg | fg | accent | accent2 | フォント |
|---|---|---|---|---|---|
| **A. Neon Cyberpunk** | `#0a0a18` | `#e0e0ff` | `#00ffe5` シアン | `#ff1b8d` マゼンタ | Share Tech Mono + Orbitron |
| **B. CRT Amber Terminal** | `#1a0e00` | `#ffb000` | `#ffb000` アンバー | `#ff8800` 橙 | VT323 |
| **C. Synthwave Sunset** | `#1a0a3a` → `#ffd400` グラデ | `#f0e6ff` | `#A06EFF` 紫 | `#FF52A4` ピンク + `#FFD400` 黄 | Major Mono Display + Space Grotesk |
| **D. Hacker Green (Matrix)** | `#000` | `#00ff41` | `#00ff41` 緑 | `#b9ffce` 薄緑 | Fira Code |

## 各案の特徴と判定軸

### A. Neon Cyberpunk
- **強み**: PackerMOD のコンテンツ(Mod / Pack / 多人数)が並ぶ情報量と相性◎。**シアン+マゼンタの 2 色だけ**でメリハリが付くので、formspec で色塗りの制御がしやすい
- **弱み**: ネオングロー(`text-shadow`)を formspec で出せない。実機ではフラットになる
- **想定**: GitS / Mirror's Edge Catalyst / Cyberpunk 2077 UI

### B. CRT Amber Terminal
- **強み**: **単色なので theme.lua のトークンが最小で済む**。Pack/World/Mod の見栄えが単色で全部統一できる。実装が一番ラク
- **弱み**: 単色ゆえに「PackerMOD らしさ」を作るのは accent 色だけでなく**文字構成(プロンプト / `[ OK ]` / コマンド行)に寄りかかる**。情報密度が低い画面だと地味
- **想定**: Alien Nostromo / Fallout Pip-Boy / 80s 業務端末

### C. Synthwave Sunset
- **強み**: **派手で印象的**。サムネが無くてもグラデーション枠で見映えがする。Pinterest の "Super Terrain 86" に一番近い
- **弱み**: **formspec で出ない要素が多い**(グラデーション枠、`backdrop-filter` blur、グラデテキスト)。実機では「色だけ採用してフラットで再現」になるため、HTML と実装の乖離が大きい。**実機で見ると別物になりやすい**
- **想定**: Outrun / Miami Vice / Hotline Miami

### D. Hacker Green (Matrix)
- **強み**: 単色で実装ラク + マトリクス雨の背景演出が画面の空きを潰す。"hacker" ぽい強い世界観
- **弱み**: **色覚負荷が高い**(緑文字に長時間さらされるとつらい)。長時間使うランチャーには向かないかも。マトリクス雨は formspec では出せず、bgimg PNG で静止画化が必要
- **想定**: The Matrix / Mr. Robot / hacker movie

## formspec v6 再現可能性メモ(共通)

| HTML 要素 | formspec で出る? | 実装方針 |
|---|---|---|
| 単色背景 (`background`) | ✅ | `bgcolor[#0a0a18]` |
| 角丸 (`border-radius`) | ❌ | 全案で角丸ゼロ。直角で統一 |
| 直線枠 (`border`) | ✅ | `style[*;border=true;bordercolor=#00ffe5]` |
| monospace (`font-family: mono`) | ✅ | `style[*;font=mono]` |
| カスタムフォント (VT323/Orbitron) | ❌ | `font=mono` で代用。フォントの個性は諦める |
| グロー (`text-shadow`) | ❌ | accent 色を**明るく純色**にすることでカバー |
| グラデ背景 (`linear-gradient`) | ❌ | bgimg PNG で代用(画質固定) |
| グラデ枠 (`border-image`) | ❌ | 案 C の最大の弱点。単色枠に落とす必要 |
| スキャンライン | ✅ (bgimg) | 1px 横線テクスチャ PNG を `bgimg` に |
| 点滅カーソル (`animation`) | ❌ | 静止画で表現 or 諦める |
| canvas 描画(雨) | ❌ | 静止画 PNG に焼き込む(案 D) |
| `backdrop-filter: blur` | ❌ | 案 C で使用、実装不可。半透明 bgcolor で妥協 |
| hover transition | ❌ | 諦める。ボタンの押下時状態は formspec の組み込み挙動に任せる |

## 判断のヒント

| 重視するもの | おすすめ案 |
|---|---|
| 実装コスト最小 | **B** > D > A > C |
| HTML と実機の見た目一致 | **B** > A > D > C |
| 視覚的インパクト | **C** > D > A > B |
| 長時間使用の快適さ | **A** > C > B > D |
| PackerMOD らしさ(Pack/Mod の情報を見せる) | **A** > C > B > D |
| Pinterest "Super Terrain 86" との近さ | **C** > B > D > A |

**個人推し**: A (Neon Cyberpunk) と B (CRT Amber) のハイブリッド。A の 2 色配色 (シアン+マゼンタ) + B の単純な構造 + プロンプト風ヘッダ。実機で再現可能な要素だけで戦える。

ただしユーザーの好みは見て決めるべきなので、まず 4 案を実物で確認してから。

## 次のフェーズ

判定後:
- `mainmenu/lib/theme.lua` の colors/spacing/font トークン置き換え
- 背景 bgimg PNG(スキャンライン/グリッド/雨)を `textures/` 配下に生成
- `mainmenu/ui/library.yml` の button width/height をプリセット (sm/md/lg) に統一
- ヘッダ文字列を選んだ案に合わせて変更(`> PACKERMOD :: PACK_LIBRARY_` 等)
- icon-button の padding 調整 + label 下の accent underline
- 実機 screenshot で確認
